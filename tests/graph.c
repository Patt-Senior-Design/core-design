#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <stdbool.h>
#include <inttypes.h>

#define G_SIZE 256
#define EDGE_CT 1024
#define N_MAX 13
#define SEARCHES 32

typedef struct Node_t {
  uint32_t marked;
  uint32_t neigh_ct;
  struct Node_t* parent;
  struct Node_t* neighbors[N_MAX];
} Node;

struct Graph {
  uint32_t size;
  uint32_t max_size;
  Node* nodes;
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
  graph->max_size = 2 * size;

  // Alloc space for all nodes
  Node* nodes = (Node*) malloc_chk(2 * size * sizeof(Node));
  // Init node neighbors/sizes
  for (int i = 0; i < size; i++) {
    initNode(nodes + i);
  }
  graph->nodes = nodes;
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


void print_graph(struct Graph* graph) {
  puts("=== GRAPH STRUCTURE ===");
  for (int i = 0; i < graph->size; i++) {
    Node* cur_node = graph->nodes + i;
    printf("%d(%u) : ", i, cur_node->neigh_ct);
    for (int j = 0; j < cur_node->neigh_ct; j++) {
      printf("%u, ", getNodeId(graph, cur_node->neighbors[j]));
    }
    puts("");
  }
  puts("=======================");
}

void free_graph(struct Graph* graph) {
  free(graph->nodes);
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


void init_bfs(struct Graph* graph, Queue* q, Node* from) {
  create_queue(q);
  enqueue(q, from);
  // Mark all nodes as unvisited
  for (int i = 0; i < graph->size; i++) {
    Node* cur_node = graph->nodes + i;
    cur_node->marked = 0;
    cur_node->parent = cur_node;
  }
  from->marked = 1;
}


/* BFS Graph Traversal */
uint32_t bfs_reachable(struct Graph* graph, Node* from, Node* to) {
  Queue bfs_q;
  init_bfs(graph, &bfs_q, from);

  Node* cur_node;
  int found = 0;
  // Remove front of queue
  while (dequeue(&bfs_q, &cur_node)) {
    uint32_t cur_node_id = getNodeId(graph, cur_node);
    // Found destination
    if (cur_node == to) {
      found = 1;
      break;
    }
    uint32_t count = cur_node->neigh_ct;
    //printf("Cur Node: %d, Neigh_Ct: %d\n", cur_node_id, count);
    Node** neighbors = cur_node->neighbors;
    for (int i = 0; i < count; i++) {
      Node* cur_neigh = neighbors[i];
      // If not visited, add neighbors to queue
      if (!cur_neigh->marked) {
        enqueue(&bfs_q, cur_neigh);
        cur_neigh->parent = cur_node;
      }
      // Mark node as visited
      cur_neigh->marked = 1;
    }
  }

  // Get the path
  if (found) {
    uint32_t path[G_SIZE];
    uint32_t ct = 0;
    Node* n = to;
    while (n != from) {
      path[ct++] = getNodeId(graph, n);
      n = n->parent;
    }
    printf("Solution Path: %u", getNodeId(graph, from));
    for (int i = ct-1; i >= 0; i--) {
      printf(" --> %u", path[i]);
    }
    puts("");
    return 1;
  }
  else {
    puts("No solution");
    return 0;
  }
}


uint32_t getRandNodeId (void) {
  return rand() % G_SIZE;
}

int main (void) {
  struct Graph graph;
  //srand(time(NULL));

  puts("Creating nodes...");
  create_graph(&graph, G_SIZE);
  
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
  //print_graph(&graph);

  puts("Running BFS...");
  for (int i = 0; i < SEARCHES; i++) {
    Node* from = graph.nodes + getRandNodeId();
    Node* to = graph.nodes + getRandNodeId();
    printf("%d: ", i);
    bfs_reachable(&graph, from, to);
  }

  free_graph(&graph);
  return 0;
}
