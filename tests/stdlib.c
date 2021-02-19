#include <stdint.h>
#include <sys/types.h>
#include <sys/stat.h>

#define CSR_MUARTSTAT "0xfc0"
#define CSR_MUARTRX   "0xfc1"
#define CSR_MUARTTX   "0x7c0"

#define MUARTSTAT_RXEMPTY (0x00000001)
#define MUARTSTAT_RXFULL  (0x00000002)
#define MUARTSTAT_TXEMPTY (0x00000004)
#define MUARTSTAT_TXFULL  (0x00000008)

// 96MB (need room for stack)
#define HEAP_MAX (96ul*1024*1024)

#define read_csr(reg) ({ unsigned long __tmp;     \
    asm volatile ("csrr %0, " reg : "=r"(__tmp)); \
    __tmp; })

#define write_csr(reg, val) ({ unsigned long __tmp;    \
    __tmp = val;                                       \
    asm volatile ("csrw " reg ", %0" : : "r"(__tmp)); })

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
        while (read_csr(CSR_MUARTSTAT) & MUARTSTAT_RXEMPTY) {}
        _buf[i] = read_csr(CSR_MUARTRX);
    }

    return count;
}

ssize_t _write(int fd, void *buf, size_t count) {
    if (fd != 1 && fd != 2) { return -1; }

    uint8_t *_buf = (uint8_t *) buf;
    for (size_t i = 0; i < count; i++) {
        while (read_csr(CSR_MUARTSTAT) & MUARTSTAT_TXFULL) {}
        write_csr(CSR_MUARTTX, _buf[i]);
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
