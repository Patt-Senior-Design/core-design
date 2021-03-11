#ifndef CSR_H
#define CSR_H

#define CSR_MCYCLE    "0xb00"
#define CSR_MINSTRET  "0xb02"
#define CSR_MCYCLEH   "0xb80"
#define CSR_MINSTRETH "0xb82"
#define CSR_MUARTSTAT "0xfc0"
#define CSR_MUARTRX   "0xfc1"
#define CSR_MUARTTX   "0x7c0"
#define CSR_MBFSSTAT  "0x7d0"
#define CSR_MBFSROOT  "0x7d1"
#define CSR_MBFSTARG  "0x7d2"
#define CSR_MBFSQBASE "0x7d3"
#define CSR_MBFSQSIZE "0x7d4"

#define MUARTSTAT_RXEMPTY (0x00000001)
#define MUARTSTAT_RXFULL  (0x00000002)
#define MUARTSTAT_TXEMPTY (0x00000004)
#define MUARTSTAT_TXFULL  (0x00000008)

#define MBFSSTAT_FOUND (0x00000001)
#define MBFSSTAT_DONE  (0x00000002)

#define read_csr(reg) ({ unsigned long __tmp;     \
    asm volatile ("csrr %0, " reg : "=r"(__tmp)); \
    __tmp; })

#define write_csr(reg, val) ({ unsigned long __tmp;    \
    __tmp = val;                                       \
    asm volatile ("csrw " reg ", %0" : : "r"(__tmp)); })

#endif
