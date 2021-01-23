#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h>

// must be a power of two
#define FIFO_SIZE 8

typedef struct {
    uint8_t head;
    uint8_t tail;
    uint16_t data[FIFO_SIZE];
} fifo_t;

static bool fifo_push(fifo_t *fifo, uint16_t val) {
    uint8_t head_next = (fifo->head + 1) & (FIFO_SIZE - 1);
    if(head_next == fifo->tail) {return false;}
    fifo->data[fifo->head] = val;
    fifo->head = head_next;
    return true;
}

static bool fifo_pop(fifo_t *fifo, uint16_t *val) {
    if(fifo->tail == fifo->head) {return false;}
    *val = fifo->data[fifo->tail];
    fifo->tail = (fifo->tail + 1) & (FIFO_SIZE - 1);
    return true;
}

int main(void) {
    fifo_t *fifo = (fifo_t *) malloc(sizeof(fifo_t));
    memset(fifo, 0, sizeof(fifo_t));

    for(uint16_t i = 0; fifo_push(fifo, i); i++) {}

    uint16_t tmp;
    uint16_t acc = 0;
    while(fifo_pop(fifo, &tmp)) {acc += tmp;}

    free(fifo);
    return 0;
}
