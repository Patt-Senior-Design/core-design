#include <stdio.h>
#include <time.h>
#include <stdlib.h>
#include <inttypes.h>

#define G_SIZE 10
#define EDGE_CT 40

typedef struct Node_t {
  uint8_t marked;
  uint32_t parent;
  uint32_t neigh_max_ct;
  uint32_t neigh_ct;
  uint32_t* neighbors;
} Node;

struct Graph {
  uint32_t size;
  uint32_t max_size;
  Node* nodes;
};

void initNode(Node* node) {
  node->marked = 0;
  node->neigh_ct = 0;
  node->neigh_max_ct = 4;
  node->neighbors = NULL;
}

/*uint32_t addNode (struct Graph* graph, uint32_t* neighbors) {
  // If space is full
  if (graph->size == graph->max_size) {
    uint32_t new_max_size = 2 * graph->max_size;
    graph->max_size = new_max_size;
    // Increase size of node array
    graph->nodes = (Node*) realloc (graph->nodes, new_max_size * sizeof(Node));
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
  Node* nodes = (Node*) malloc (2 * size * sizeof(Node));
  // Init node neighbors/sizes
  for (int i = 0; i < size; i++) {
    initNode(nodes + i);
  }

  graph->nodes = nodes;
}



void add_edge (struct Graph* graph, uint32_t from, uint32_t to) {
  Node* from_node = graph->nodes + from;
  // Check error
  if (to >= graph->size) {
    printf("Out of Bounds edge\n");
    return;
  }

  uint32_t from_max_ct = from_node->neigh_max_ct;
  uint32_t from_ct = from_node->neigh_ct;
  // First edge or if space full
  if (from_node->neighbors == NULL || from_ct == from_max_ct) {
    from_node->neighbors = (uint32_t*) realloc (from_node->neighbors, from_max_ct * sizeof(Node));
    from_node->neigh_max_ct = 2 * from_max_ct;
  }
  // Assign the edge
  from_node->neighbors[(from_node->neigh_ct)++] = to;
}


void print_graph(struct Graph* graph) {
  printf("=== GRAPH STRUCTURE ===\n");
  for (int i = 0; i < graph->size; i++) {
    Node* cur_node = graph->nodes + i;
    printf("%d(%d) : ", i, cur_node->neigh_ct);
    for (int j = 0; j < cur_node->neigh_ct; j++) {
      printf("%d, ", cur_node->neighbors[j]);
    }
    printf("\n");
  }
  printf("=======================\n");
}

void free_graph(struct Graph* graph) {
  for (int i = 0; i < graph->size; i++) {
    free(graph->nodes[i].neighbors);
  }
  free(graph->nodes);
}

int is_neighbor(Node* node, uint32_t val) {
  for (int i = 0; i < node->neigh_ct; i++)
    if (node->neighbors[i] == val)
      return 1;
  return 0;
}



typedef struct Queue_t {
  uint32_t head, tail;
  uint32_t val[G_SIZE];
} Queue;

void create_queue(Queue* q) {
  //q->val = (uint32_t*) malloc (G_SIZE * sizeof(uint32_t));
  q->head = q->tail = 0;
}

void enqueue(Queue* q, uint32_t val) {
  q->val[q->tail++] = val;
  if (q->tail == G_SIZE)
    q->tail = 0;
}

uint32_t dequeue(Queue* q, uint32_t* val) {
  if (q->head == q->tail)
    return 0;

  *val = q->val[q->head++];
  if (q->head == G_SIZE)
    q->head = 0;

  return 1;
}


void init_bfs(struct Graph* graph, Queue* q, uint32_t from) {
  create_queue(q);
  enqueue(q, from);
  // Mark all nodes as unvisited
  for (int i = 0; i < graph->size; i++) {
    Node* cur_node = graph->nodes + i;
    cur_node->marked = 0;
    cur_node->parent = i;
  }
  (graph->nodes + from)->marked = 1;
}



/* BFS Graph Traversal */
uint32_t bfs_reachable(struct Graph* graph, uint32_t from, uint32_t to) {
  Queue bfs_q;
  init_bfs(graph, &bfs_q, from);
  Node* nodes = graph->nodes;

  uint32_t cur_node_id;
  int found = 0;
  // Remove front of queue
  while (dequeue(&bfs_q, &cur_node_id)) {
    Node* cur_node = (nodes + cur_node_id);
    // Found destination
    if (cur_node_id == to) {
      found = 1;
      break;
    }
    uint32_t count = cur_node->neigh_ct;
    //printf("Cur Node: %d, Neigh_Ct: %d\n", cur_node_id, count);
    uint32_t* neighbors = cur_node->neighbors;
    for (int i = 0; i < count; i++) {
      uint32_t cur_neigh = neighbors[i];
      // If not visited, add neighbors to queue
      if (!(nodes[cur_neigh].marked)) {
        enqueue(&bfs_q, cur_neigh);
        nodes[cur_neigh].parent = cur_node_id;
      }
      // Mark node as visited
      graph->nodes[cur_neigh].marked = 1;
    }
  }

  if (found) {
    uint32_t path[G_SIZE];
    uint32_t ct = 0;
    uint32_t n_id = to;
    while (n_id != from) {
      path[ct++] = n_id;
      n_id = nodes[n_id].parent;
    }
    printf("Solution Path: %d", from);
    for (int i = ct-1; i >= 0; i--) {
      printf(" --> %d", path[i]);
    }
    printf("\n");
    return 1;
  }
  else {
    printf("No solution");
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
    if (!is_neighbor(graph.nodes + from, to)) {
      add_edge(&graph, from, to);
      edge_ct++;
    }
  }

  print_graph(&graph);

  printf("Edge Count: %d\n", edge_ct);
  bfs_reachable(&graph, 3, 5);

  free_graph(&graph);
  return 0;
}
