#include <inttypes.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <time.h>

#define TABLE_BASE_SIZE (1 << 10)
#define TABLE_CT 9
#define VAL_RANGE 100000000
#define SAMPLES 10000
#define PHASH_SHF 20
#define SEED 1

/* LINKED LIST */
typedef struct node {
  int data;
  struct node * next;
} Node;

typedef struct {
  Node * head; 
} List;

Node * createnode(int data){
  Node * newNode = malloc(sizeof(Node));
  if (!newNode) {
    return NULL;
  }
  newNode->data = data;
  newNode->next = NULL;
  return newNode;
}

void initlist(List* list){
  list->head = NULL;
}

void display(List * list) {
  for (Node* current = list->head; current != NULL; current = current->next) {
    printf("%d, ", current->data);
  }
  printf("\n");
}

void add(int data, List * list){
  Node * current = NULL;
  if(list->head == NULL){
    list->head = createnode(data);
  }
  else {
    current = list->head; 
    while (current->next!=NULL){
      current = current->next;
    }
    current->next = createnode(data);
  }
}

void delete(int data, List * list){
  Node * current = list->head;            
  Node * previous = current;           
  while(current != NULL){           
    if(current->data == data){      
      previous->next = current->next;
      if(current == list->head)
        list->head = current->next;
      free(current);
      return;
    }                               
    previous = current;             
    current = current->next;        
  }                                 
}                                   

void destroy(List * list){
  Node * current = list->head;
  Node * next = current;
  while(current != NULL){
    next = current->next;
    free(current);
    current = next;
  }
}
/* END OF LL */


/* HASHSET */
typedef struct {
  int32_t *arr;
  uint8_t *mdata;
  uint32_t capacity;
  uint32_t size;
  uint8_t *mdata_base;
  //List *buckets;
} HashSet;

HashSet* create_hashset(uint32_t cap) {
  HashSet* set = (HashSet*) malloc(sizeof(HashSet));

  set->capacity = cap;
  set->size = 0;
  set->arr = (int32_t*) malloc(cap * sizeof(int32_t));
  set->mdata_base = (uint8_t*) malloc((cap+31) * sizeof(uint8_t));
  set->mdata = set->mdata_base + (32 - ((uint32_t)set->mdata_base % 32)) % 32 ; // Align
  //set->buckets = (List*) malloc(cap * sizeof(List));
  for (int i = 0; i < cap; i++) {
    set->mdata[i] = 0;
    //initlist(set->buckets + i);
  }
  return set;
}

#define HASH 2
// Hash 1
#if HASH == 1
uint64_t __attribute__((optimize("O1"))) hash_fn (int32_t val) {
  return (val * 2654435761);
}
#endif
#if HASH == 2
// Hash 2
uint64_t __attribute__((optimize("O1"))) hash_fn (int32_t val) {
  val = ((val >> 16) ^ val) * 0x7feb352d;
  val = ((val >> 15) ^ val) * 0x846ca68b;
  return (val >> 16) ^ val;
}
#endif

bool findNode (HashSet* set, int32_t val) {
  uint64_t hash = hash_fn(val);
  uint32_t hashIdx = hash % set->capacity;
  /*uint32_t lbcmp_e = 0, lbcmp_v = 0;
  for (int i = 0; i < 32; i++) {
    int idx = (hashIdx & (~31)) + i;
    lbcmp_e >>= 1;
    lbcmp_v >>= 1;
    if (set->mdata[idx] ==  (0x80 | ((hash >> PHASH_SHF) & 0x7f)))
      lbcmp_v |= (1 << 31);
    if (set->mdata[idx] ==  0)
      lbcmp_e |= (1 << 31);
  }
  uint32_t init_idx = hashIdx;
  printf("idx: %ld, ", init_idx);*/
  while (set->mdata[hashIdx] >> 7) {
    // Partial hashes match
    if ((set->mdata[hashIdx] & 0x7f) == ((hash >> PHASH_SHF) & 0x7f)) {
      // Actual values match
      if (set->arr[hashIdx] == val) {
        //printf("final: %ld, ", hashIdx);
        return 1;
      }
    } 
    hashIdx = (hashIdx + 1) % set->capacity;
  }
  //printf("final: %ld, ", hashIdx);
  return 0;
}

bool insertNode (HashSet* set, int32_t val) {
  uint64_t hash = hash_fn(val);
  uint32_t hashIdx = hash % set->capacity;
  // Debugging
  //add(val, set->buckets + hashIdx);

  // Same as findNode without tombstone
  while (set->mdata[hashIdx] >> 7) {
    if ((set->mdata[hashIdx] & 0x7f) == ((hash >> PHASH_SHF) & 0x7f)) {
      if (set->arr[hashIdx] == val)
        return false;
    }
    hashIdx = (hashIdx + 1) % set->capacity;
  }
  // Insert in spot
  set->mdata[hashIdx] = (1 << 7) | ((hash >> PHASH_SHF) & 0x7f);
  set->arr[hashIdx] = val;
  set->size++;
  return true;
}


void print_buckets (HashSet* set) {
  printf("=== HASHSET BUCKETS ===\n");
  for (int i = 0; i < set->capacity; i++) {
    printf("%d: ", i);
    //display(set->buckets + i);
  }
  printf("======================\n");
}

void print_contents (HashSet* set) {
  printf("=== HASHSET CONTENTS ===\n");
  for (int i = 0; i < set->capacity; i++) {
    printf("%d: ", i);
    if (set->mdata[i] >> 7) {
      printf("%ld", set->arr[i]);
    }
    printf("\n");
  }
  printf("==========================\n\n");
}

void free_hashset (HashSet* set) {
  free(set->arr);
  free(set->mdata_base);
  //for (int i = 0; i < set->capacity; i++) 
  //  destroy (set->buckets + i);
  //free(set->buckets);
  free(set);
}
/* END OF HASHSET */


void measure_perf (HashSet* set, int32_t* elems, int32_t elem_ct, uint32_t samples) {
  uint64_t total_exec_time = 0;
  uint32_t max_exec_time = 0;
  uint32_t min_exec_time = 0xFFFFFFFF;
  uint32_t found_ct = 0;
  int32_t search_val = 0;
  bool found = 0;
  uint32_t exec_time = 0;

  for (int i = 0; i < samples; i++) {
    if (i & 1)  search_val = (rand() % VAL_RANGE) + VAL_RANGE;  // value+1: Most probably not found
    else        search_val = elems[rand() % elem_ct];

    asm volatile("csrrw x0, mcycle, x0");
    found = findNode(set, search_val);
    asm volatile("csrrs %0, mcycle, x0" : "=r" (exec_time));
    //uint32_t exec_time = find_in_set(set, search_val, &found);

    total_exec_time += exec_time;
    if (exec_time < min_exec_time) min_exec_time = exec_time;
    if (exec_time > max_exec_time) max_exec_time = exec_time;
    found_ct += found;
  }

  // Average time for find stats
  uint32_t net_time = ((float)total_exec_time)/((float)samples); 
  printf("{ Found: %ld / %ld,  Avg Exec Time: %ld, Min: %ld, Max: %ld }\n", 
      found_ct, samples, net_time, min_exec_time, max_exec_time);
}

int main () {
  srand (SEED);

  uint32_t MAX_ELEM_CT = 0;
  int LF_CT = 6;
  float TARGET_LF[] = {0.5, 0.6, 0.7, 0.8, 0.9, 0.95};

  for (int j = 0; j < TABLE_CT; j++) {
    int table_size = TABLE_BASE_SIZE << j;
    HashSet* set = create_hashset(table_size);
    // Note: target_lf[0] has to be greater than largest increment
    int32_t* elems = (int32_t*) malloc ((uint32_t)(table_size * sizeof(int32_t)));
    int32_t elem_ct = 0;
    printf("Table Size: %d\n", table_size);
    for (int i = 0; i < LF_CT; i++) {
      // Init params
      float lf = TARGET_LF[i];
      MAX_ELEM_CT = ((uint32_t) (table_size * lf)) - set->size;
      printf("LF: %d ", (int)(lf * 100));

      // Init hashset
      for (int32_t j = 0; j < MAX_ELEM_CT; j++) {
        int32_t elem = rand() % VAL_RANGE;
        bool success = insertNode(set, elem);
        if (success) {
          elems[elem_ct++] = elem;
        }
      }
      printf("(Size: %ld) --> ", set->size); 
      // Perf stat
      measure_perf (set, elems, elem_ct, SAMPLES);
    }
    printf("\n");
    // Free memory
    free(elems);
    free_hashset(set);
  }
  return 0;
}
