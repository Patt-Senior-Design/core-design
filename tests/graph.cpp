#include "csr.h"
#include <cstdint>
#include <cstdio>
#include <cstdlib>

#define G_SIZE 1024
#define EDGE_CT (G_SIZE*2)
#define N_MAX 14
#define SEARCHES 8

// BFS memory region
#define BFSQBASE (0x20000000 + (96ul*1024*1024)) // RAM_BASE + HEAP_MAX
#define BFSQSIZE (8ul*1024*1024)

void putint(uint32_t val) {
  char buf[10];

  int len = 0;
  do {
    buf[len++] = '0' + (val % 10);
    val /= 10;
  } while(val);

  do {
    putchar(buf[--len]);
  } while(len);
}

void puthex32(uint32_t val) {
  for(int i=28;i>=0;i-=4) {
    char c = '0' + ((val >> i) & 0xf);
    if(c > '9') {c += ('a' - '9') - 1;}
    putchar(c);
  }
}

struct Node {
  Node(uint32_t value) : value(value) {}
  Node() {}

  bool isNeighbor(Node* dest) const {
    for(uint32_t i = 0; i < numEdges; i++) {
      if(edges[i] == dest) {return true;}
    }
    return false;
  }

  bool addEdge(Node* dest) {
    if(numEdges == N_MAX) {return false;}
    if(isNeighbor(dest)) {return false;}

    edges[numEdges++] = dest;
    return true;
  }

  uint32_t value;
  struct {
    uint16_t numEdges;
    uint8_t _unused;
    uint8_t marked;
  };
  Node* edges[N_MAX];
};

class Graph {
public:
  Graph(uint32_t size) : size(size) {
    // Alloc space for all nodes
    mem = new char[(size*sizeof(Node)) + 63];
    // Align to 64-byte boundary
    nodes = (Node*) ((((uintptr_t) mem) + 63) & ~63);
    // Initialize nodes
    for(uint32_t i = 0; i < size; i++) {
      nodes[i] = Node(i);
    }
  }
  ~Graph() {
    for(uint32_t i = 0; i < size; i++) {
      nodes[i].~Node();
    }
    delete[] mem;
  }

  uint32_t getSize() const {return size;}
  Node* getNode(uint32_t index) const {return &nodes[index];}

  Node* getRandomNode() const {
    return getNode(rand() % size);
  }

  void unmark() {
    for(uint32_t i = 0; i < size; i++) {
      nodes[i].marked = 0;
    }
  }

  void print() const {
    puts("digraph {");
    for (uint32_t i = 0; i < size; i++) {
      if (nodes[i].numEdges == 0) {continue;}

      fputs("  \"", stdout);
      putint(nodes[i].value);
      fputs("\" ->", stdout);
      for (uint32_t j = 0; j < nodes[i].numEdges; j++) {
        if (j != 0) {putchar(',');}
        fputs(" \"", stdout);
        putint(nodes[i].edges[j]->value);
        putchar('"');
      }
      putchar('\n');
    }
    puts("}");
  }

private:
  uint32_t size;
  // aligned to 64-byte boundary
  Node* nodes;
  // original unaligned ptr, used during free
  char* mem;

  Graph(const Graph& other) = delete;
  Graph& operator=(const Graph& other) = delete;
};

class Queue {
public:
  Queue(uint32_t size) : size(size) {
    buf = new Node*[size];
  }
  ~Queue() {delete[] buf;}

  bool enqueue(Node* node) {
    uint32_t tail_next = tail + 1;
    if(tail_next == size) {tail_next = 0;}
    if(tail_next == head) {return false;}
    buf[tail] = node;
    tail = tail_next;
    return true;
  }

  Node* dequeue() {
    if(head == tail) {return nullptr;}
    Node* node = buf[head++];
    if(head == size) {head = 0;}
    return node;
  }

  void flush() {
    head = 0;
    tail = 0;
  }

private:
  uint32_t size;
  uint32_t head, tail;
  Node** buf;

  Queue(const Queue& other) = delete;
  Queue& operator=(const Queue& other) = delete;
};

Node* bfs(Graph* graph, Queue* queue, Node* root, uint32_t target, uint32_t *time) {
  uint32_t time_begin = read_csr(CSR_MCYCLE);

  queue->flush();
  queue->enqueue(root);
  graph->unmark();
  root->marked = 1;

  Node* cur_node;
  // Remove front of queue
  while ((cur_node = queue->dequeue())) {
    if (cur_node->value == target) {break;}

    for (uint32_t i = 0; i < cur_node->numEdges; i++) {
      Node* neighbor = cur_node->edges[i];
      if (neighbor->marked) {continue;}

      // Mark node as visited
      neighbor->marked = 1;
      queue->enqueue(neighbor);
    }
  }

  uint32_t time_diff = read_csr(CSR_MCYCLE) - time_begin;
  *time = time_diff;
  if (cur_node) {
    printf("Found target in %ld cycles\n", time_diff);
  } else {
    printf("Target not found in %ld cycles\n", time_diff);
  }

  return cur_node;
}

bool bfs_wait_acc(uint32_t timeout) {
  uint32_t time_begin = read_csr(CSR_MCYCLE);
  while ((read_csr(CSR_MCYCLE) - time_begin) < timeout) {
    if (read_csr(CSR_MBFSSTAT) & MBFSSTAT_DONE) {return true;}
  }
  return false;
}

Node* bfs_acc(Graph* graph, Node* root, uint32_t target, uint32_t timeout) {
  // Print entry time
  printf("Enter bfs_acc at %ldns\n", read_csr(CSR_MCYCLE));

  // Wait for any previous search to complete
  if (!bfs_wait_acc(10000)) {return (Node*) -1;}

  uint32_t time_begin = read_csr(CSR_MCYCLE);
  graph->unmark();

  // Ensure that writes have propagated to L2
  write_csr(CSR_ML2STAT, 1);

  // Set BFS parameters
  write_csr(CSR_MBFSROOT, (uint32_t) root);
  write_csr(CSR_MBFSTARG, target);
  write_csr(CSR_MBFSQBASE, (uint32_t) BFSQBASE);
  write_csr(CSR_MBFSQSIZE, BFSQSIZE);

  // Start BFS
  write_csr(CSR_MBFSSTAT, 1);

  // Wait for search to complete
  if (!bfs_wait_acc(timeout)) {return (Node*) -1;}

  uint32_t time_diff = read_csr(CSR_MCYCLE) - time_begin;
  printf("Accelerator ran in %ld cycles\n", time_diff);

  if(read_csr(CSR_MBFSSTAT) & MBFSSTAT_FOUND) {
    return (Node*) read_csr(CSR_MBFSRESULT);
  }
  return nullptr;
}

int main (void) {
  puts("Creating structures...");
  Graph graph(G_SIZE);
  Queue queue(G_SIZE);

  /* Add edges: Prevent duplicates */
  puts("Adding edges...");
  uint32_t numEdges = 0;
  while (numEdges < EDGE_CT) {
    Node* from = graph.getRandomNode();
    Node* to = graph.getRandomNode();
    if (!from->addEdge(to)) {continue;}
    numEdges++;
  }
  //graph.print();

  puts("Running BFS...");
  for (int i = 0; i < SEARCHES; i++) {
    Node* root = graph.getRandomNode();
    Node* target = graph.getRandomNode();
    printf("%lu (%p) to %lu (%p): ",
           root->value, root,
           target->value, target);

    uint32_t time;
    uint32_t targetVal = target->value;
    Node* result = bfs(&graph, &queue, root, targetVal, &time);
    Node* result_acc = bfs_acc(&graph, root, targetVal, time*2);
    if (result_acc == (Node*) -1) {
      puts("ERROR: accelerator timed out.");
      return 1;
    } else if (result_acc != result) {
      puts("ERROR: accelerator returned incorrect result.");
      return 1;
    }
  }

  return 0;
}
