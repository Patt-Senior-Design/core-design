#include <stdint.h>
#include <sys/types.h>
#include <sys/stat.h>

#define R_UART_STATUS *((volatile uint32_t *) 0x30010000)
#define R_UART_RX     *((volatile uint32_t *) 0x30010004)
#define R_UART_TX     *((volatile uint32_t *) 0x30010008)

#define M_UART_RXEMPTY (0x00000001)
#define M_UART_RXFULL  (0x00000002)
#define M_UART_TXEMPTY (0x00000004)
#define M_UART_TXFULL  (0x00000008)

// 96MB (need room for stack)
#define HEAP_MAX (96ul*1024*1024)

extern uint8_t _sdata;
extern uint8_t _end;
static uint8_t* curbrk = &_end;

// Unimplemented stubs
int _close(int fd) { return -1; }
off_t _lseek(int fd, off_t offset, int whence) { return -1; }
int _fstat(int fd, struct stat *statbuf) { return -1; }

// Input/output
ssize_t _read(int fd, void *buf, size_t count) {
    if (fd != 0) { return -1; }

    uint8_t *_buf = (uint8_t *) buf;
    for (size_t i = 0; i < count; i++) {
        while (R_UART_STATUS & M_UART_RXEMPTY) {}
        _buf[i] = R_UART_RX;
    }

    return count;
}

ssize_t _write(int fd, void *buf, size_t count) {
    if (fd != 1 && fd != 2) { return -1; }

    uint8_t *_buf = (uint8_t *) buf;
    for (size_t i = 0; i < count; i++) {
        while (R_UART_STATUS & M_UART_TXFULL) {}
        R_UART_TX = _buf[i];
    }

    return count;
}

// Memory allocation
void * _sbrk(intptr_t increment) {
    // Add with overflow check
    if (curbrk + increment < curbrk) {
        curbrk = (uint8_t*) -1ll;
    } else {
        curbrk += increment;
    }

    // Clamp to HEAP_MAX
    if (curbrk > &_sdata + HEAP_MAX) {
        curbrk = &_sdata + HEAP_MAX;
    }

    return curbrk;
}
