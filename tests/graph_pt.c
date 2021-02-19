#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <inttypes.h>

#define G_SIZE 10
#define EDGE_CT 40

typedef struct Node_t {
  struct Node_t** neighbors;
  uint32_t neigh_ct;
  uint8_t marked;
  struct Node_t* parent;
  uint32_t neigh_max_ct;
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

void* realloc_chk(void* ptr, size_t size) {
  ptr = realloc(ptr, size);
  if(!ptr) {
    puts("Failed to realloc, exiting...");
    exit(1);
  }
  return ptr;
}

void initNode(Node* node) {
  node->marked = 0;
  node->neigh_ct = 0;
  node->neigh_max_ct = 4;
  node->neighbors = (Node**) malloc_chk(4 * sizeof(Node*));
}

uint32_t getNodeId(struct Graph* graph, Node* n) {
  return (n - graph->nodes);
}
/*uint32_t addNode (struct Graph* graph, uint32_t* neighbors) {
  // If space is full
  if (graph->size == graph->max_size) {
    uint32_t new_max_size = 2 * graph->max_size;
    graph->max_size = new_max_size;
    // Increase size of node array
    graph->nodes = (Node*) realloc_chk(graph->nodes, new_max_size * sizeof(Node));
  }
  uint32_t index = graph->size;
  // Allocate new node
  initNode(graph->nodes + (graph->size++));
  return index;
}*/


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



void add_edge (struct Graph* graph, uint32_t from, uint32_t to) {
  Node* from_node = graph->nodes + from;
  Node* to_node = graph->nodes + to;
  // Check error
  if (to >= graph->size) {
    puts("Out of Bounds edge");
    return;
  }

  uint32_t from_max_ct = from_node->neigh_max_ct;
  uint32_t from_ct = from_node->neigh_ct;
  // First edge or if space full
  if (from_ct == from_max_ct) {
    from_node->neigh_max_ct = 2 * from_max_ct;
    from_node->neighbors = (Node**) realloc_chk(from_node->neighbors, from_node->neigh_max_ct * sizeof(Node*));
  }
  // Assign the edge
  from_node->neighbors[(from_node->neigh_ct)++] = to_node;
}


void print_graph(struct Graph* graph) {
  puts("=== GRAPH STRUCTURE ===");
  for (int i = 0; i < graph->size; i++) {
    Node* cur_node = graph->nodes + i;
    printf("%d(%u) : ", i, cur_node->neigh_ct);
    for (int j = 0; j < cur_node->neigh_ct; j++) {
      printf("%u, ", getNodeId(graph, cur_node->neighbors[j]));
      //printf("%u, ", graph->nodes + j);//getNodeId(graph, cur_node));
    }
    puts("");
  }
  puts("=======================");
}

void free_graph(struct Graph* graph) {
  for (int i = 0; i < graph->size; i++) {
    free(graph->nodes[i].neighbors);
  }
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
  //q->val = (uint32_t*) malloc_chk(G_SIZE * sizeof(uint32_t));
  q->head = q->tail = 0;
}

void enqueue(Queue* q, Node* val) {
  q->val[q->tail++] = val;
  if (q->tail == G_SIZE)
    q->tail = 0;
}

uint32_t dequeue(Queue* q, Node** val) {
  if (q->head == q->tail)
    return 0;

  *val = q->val[q->head++];
  if (q->head == G_SIZE)
    q->head = 0;

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



int main (void) {
  struct Graph graph;
  //srand(time(NULL));
  
  uint32_t edge_ct = 0;

  create_graph(&graph, G_SIZE);
  
  /* Add edges: Prevent duplicates */
  for (int i = 0; i < EDGE_CT; i++) {
    uint32_t from = rand() % G_SIZE;
    uint32_t to = rand() % G_SIZE;
    if (!is_neighbor(graph.nodes + from, graph.nodes + to)) {
      add_edge(&graph, from, to);
      edge_ct++;
    }
  }
  print_graph(&graph);

  printf("Edge Count: %u\n", edge_ct);

  Node* from = graph.nodes + 3;
  Node* to = graph.nodes + 5;
  bfs_reachable(&graph, from, to);

  free_graph(&graph);
  return 0;
}
