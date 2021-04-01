#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <stdbool.h>
#include <inttypes.h>
#include "csr.h"

#define G_SIZE 256
#define EDGE_CT 1024
#define N_MAX 14
#define SEARCHES 32

// BFS memory region
#define BFSQBASE (0x20000000 + (96ul*1024*1024)) // RAM_BASE + HEAP_MAX
#define BFSQSIZE (8ul*1024*1024)

typedef struct Node_t {
  uint32_t marked;
  uint32_t neigh_ct;
  struct Node_t* neighbors[N_MAX];
} Node;

struct Graph {
  uint32_t size;
  // aligned to 64-byte boundary
  Node* nodes;
  // original unaligned ptr, used during free
  void* mem;
};

void* malloc_chk(size_t size) {
  void* data = malloc(size);
  if(!data) {
    puts("Failed to malloc, exiting...");
    exit(1);
  }
  return data;
}

void initNode(Node* node) {
  node->marked = 0;
  node->neigh_ct = 0;
}

uint32_t getNodeId(struct Graph* graph, Node* n) {
  return (n - graph->nodes);
}

void create_graph(struct Graph* graph, int size) {
  graph->size = size;

  // Alloc space for all nodes
  graph->mem = malloc_chk((size * sizeof(Node)) + 63);
  // Align to 64-byte boundary
  graph->nodes = (Node*) ((((uintptr_t) graph->mem) + 63) & ~63);
  // Init node neighbors/sizes
  for (int i = 0; i < size; i++) {
    initNode(graph->nodes + i);
  }
}


bool add_edge (struct Graph* graph, uint32_t from, uint32_t to) {
  Node* from_node = graph->nodes + from;
  Node* to_node = graph->nodes + to;
  // Check error
  if (to >= graph->size || (from_node->neigh_ct == N_MAX)) {
    puts("Out of Bounds edge OR Edge Overflow");
    return 1;
  }

  // Assign the edge: Cannot exceed 13
  from_node->neighbors[(from_node->neigh_ct)++] = to_node;
  return 0;
}

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

void print_graph(struct Graph* graph) {
  puts("=== GRAPH STRUCTURE ===");
  for (int i = 0; i < graph->size; i++) {
    Node* cur_node = graph->nodes + i;
    puthex32((uint32_t) cur_node);
    fputs(": ", stdout);
    for (int j = 0; j < cur_node->neigh_ct; j++) {
      puthex32((uint32_t) cur_node->neighbors[j]);
      putchar(' ');
    }
    putchar('\n');
  }
  puts("=======================");
}

void free_graph(struct Graph* graph) {
  free(graph->mem);
}


int is_neighbor(Node* from, Node* to) {
  for (int i = 0; i < from->neigh_ct; i++)
    if (from->neighbors[i] == to)
      return 1;
  return 0;
}


typedef struct Queue_t {
  uint32_t head, tail;
  Node* val[G_SIZE];
} Queue;

void create_queue(Queue* q) {
  q->head = q->tail = 0;
}

void enqueue(Queue* q, Node* val) {
  q->val[q->tail++] = val;
  if (q->tail == G_SIZE)
    q->tail = 0;
}

int dequeue(Queue* q, Node** val) {
  if (q->head == q->tail) return 0;
  
  *val = q->val[q->head++];
  if (q->head == G_SIZE)  q->head = 0;
  return 1;
}

void unmark_graph(struct Graph* graph) {
  for (int i = 0; i < graph->size; i++) {
    Node* cur_node = graph->nodes + i;
    cur_node->marked = 0;
  }
}

void init_bfs(struct Graph* graph, Queue* q, Node* from) {
  create_queue(q);
  enqueue(q, from);
  unmark_graph(graph);
  from->marked = 1;
}


/* BFS Graph Traversal */
uint32_t bfs_reachable(struct Graph* graph, Node* from, Node* to, uint32_t *time) {
  uint32_t time_begin = read_csr(CSR_MCYCLE);

  Queue bfs_q;
  init_bfs(graph, &bfs_q, from);

  Node* cur_node;
  int found = 0;
  // Remove front of queue
  while (dequeue(&bfs_q, &cur_node)) {
    uint32_t count = cur_node->neigh_ct;
    Node** neighbors = cur_node->neighbors;
    for (int i = 0; i < count; i++) {
      Node* cur_neigh = neighbors[i];
      if (cur_neigh->marked) {continue;}

      // Found destination
      if (cur_neigh == to) {
        found = 1;
        break;
      }

      // Mark node as visited
      cur_neigh->marked = 1;
      enqueue(&bfs_q, cur_neigh);
    }
  }

  uint32_t time_diff = read_csr(CSR_MCYCLE) - time_begin;
  *time = time_diff;
  if (found) {
    printf("Path found in %ld cycles\n", time_diff);
    return 1;
  }
  else {
    printf("No path found in %ld cycles\n", time_diff);
    return 0;
  }
}

bool bfs_wait_acc(uint32_t timeout) {
  uint32_t time_begin = read_csr(CSR_MCYCLE);
  while ((read_csr(CSR_MCYCLE) - time_begin) < timeout) {
    if (read_csr(CSR_MBFSSTAT) & MBFSSTAT_DONE) {return true;}
  }
  return false;
}

int32_t bfs_reachable_acc(struct Graph* graph, Node* from, Node* to, uint32_t timeout) {
  // Print entry time
  printf("Enter bfs_reachable_acc at %ldns\n", read_csr(CSR_MCYCLE));

  // Wait for any previous search to complete
  if (!bfs_wait_acc(10000)) {return -1;}

  uint32_t time_begin = read_csr(CSR_MCYCLE);
  unmark_graph(graph);

  // Ensure that writes have propagated to L2
  write_csr(CSR_ML2STAT, 1);

  // Set BFS parameters
  write_csr(CSR_MBFSROOT, (uint32_t) from);
  write_csr(CSR_MBFSTARG, (uint32_t) to);
  write_csr(CSR_MBFSQBASE, (uint32_t) BFSQBASE);
  write_csr(CSR_MBFSQSIZE, (uint32_t) BFSQSIZE);

  // Start BFS
  write_csr(CSR_MBFSSTAT, 1);

  // Wait for search to complete
  if (!bfs_wait_acc(timeout)) {return -1;}

  uint32_t time_diff = read_csr(CSR_MCYCLE) - time_begin;
  printf("Accelerator ran in %ld cycles\n", time_diff);

  return (read_csr(CSR_MBFSSTAT) & MBFSSTAT_FOUND) ? 1 : 0;
}



uint32_t getRandNodeId (void) {
  return rand() % G_SIZE;
}

int main (void) {
  struct Graph graph;
  //srand(time(NULL));

  puts("Creating nodes...");
  create_graph(&graph, G_SIZE);
  printf("Node base: %p\n", graph.nodes);

  /* Add edges: Prevent duplicates */
  puts("Adding edges...");
  uint32_t edge_ct = 0;
  while (edge_ct < EDGE_CT) {
    uint32_t from = getRandNodeId();
    uint32_t to = getRandNodeId();
    if (!is_neighbor(graph.nodes + from, graph.nodes + to)) {
      if (add_edge(&graph, from, to)) {
        puts("Aborting..");
        return 1;
      }
      edge_ct++;
    }
  }
  print_graph(&graph);

  puts("Running BFS...");
  for (int i = 0; i < SEARCHES; i++) {
    Node* from = graph.nodes + getRandNodeId();
    Node* to = graph.nodes + getRandNodeId();
    printf("%d to %d: ", getNodeId(&graph, from), getNodeId(&graph, to));

    uint32_t time;
    uint32_t found = bfs_reachable(&graph, from, to, &time);
    int32_t found_acc = bfs_reachable_acc(&graph, from, to, time*2);
    if (found_acc < 0) {
      puts("ERROR: accelerator timed out.");
      return 1;
    }
    else if (found_acc != found) {
      puts("ERROR: accelerator returned incorrect result.");
      return 1;
    }
  }

  free_graph(&graph);
  return 0;
}
