#include "dramsim_verilator.h"

#include <verilated.h>
#include "Vtop.h"
#include "Vtop_top.h"

#include <svdpi.h>
#include "Vtop__Dpi.h"

#include <cstdint>
#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <unordered_map>

#define ROB_SIZE 128
#define LQ_SIZE 16
#define SQ_SIZE 16
#define LSQ_SIZE (LQ_SIZE+SQ_SIZE)

#define CMD_BUSRD   0
#define CMD_BUSRDX  1
#define CMD_BUSUPGR 2
#define CMD_FILL    4
#define CMD_FLUSH   5

#define ROM_BASE (0x10000000/4)
#define ROM_SIZE ((16*1024*1024)/4)
#define DBG_TOHOST (0x30000000/4)

static std::unordered_map<uint16_t,std::string> csr_names = {
  {0x300, "mstatus"},
  {0x301, "misa"},
  {0x302, "medeleg"},
  {0x303, "mideleg"},
  {0x304, "mie"},
  {0x305, "mtvec"},
  {0x306, "mcounteren"},
  {0x310, "mstatush"},
  {0x340, "mscratch"},
  {0x341, "mepc"},
  {0x342, "mcause"},
  {0x343, "mtval"},
  {0x344, "mip"},
  {0x34a, "mtinst"},
  {0x34b, "mtval2"},
  {0x7c0, "muarttx"},
  {0x7d0, "mbfsstat"},
  {0x7d1, "mbfsroot"},
  {0x7d2, "mbfstarg"},
  {0x7d3, "mbfsqbase"},
  {0x7d4, "mbfsqsize"},
  {0x7e0, "ml2stat"},
  {0xb00, "mcycle"},
  {0xb02, "minstret"},
  {0xb80, "mcycleh"},
  {0xb82, "minstreth"},
  {0xf11, "mvendorid"},
  {0xf12, "marchid"},
  {0xf13, "mimpid"},
  {0xf14, "mhartid"},
  {0xfc0, "muartstat"},
  {0xfc1, "muartrx"},
};

static uint64_t simtime;
static VerilatedContext* context;
static Vtop* top;
static DRAM* dram;

static uint32_t mem_rom[ROM_SIZE];

static FILE* uartfile;
static FILE* tracefile;
static FILE* logfile;

typedef struct {
  uint32_t insn;
  uint32_t imm;
  bool uses_mem;
  uint8_t memop;
  uint32_t membase;
  uint32_t memdata;
  bool writes_csr;
} rob_trace_t;

typedef struct {
  uint8_t robid;
} lsq_trace_t;

static rob_trace_t rob_trace[ROB_SIZE];
static lsq_trace_t lsq_trace[LSQ_SIZE];

static struct {
  unsigned instret;
  unsigned branches;
  unsigned mispreds;
  unsigned rob_inflight;
  unsigned rob_inflight_hist[ROB_SIZE+1];
  unsigned lq_inflight_hist[LQ_SIZE+1];
  unsigned sq_inflight_hist[SQ_SIZE+1];
} stats;

static uint64_t bus_data[8];

// Returns the value of a plusarg of the form +name=value
static const char* get_plusarg(const char* name) {
  // Append '=' to end of name
  size_t len = strlen(name);
  char buf[len+2];
  memcpy(buf, name, len);
  buf[len] = '=';
  buf[len+1] = '\0';

  // Check for plusarg
  const char* arg = context->commandArgsPlusMatch(buf);
  if(arg[0] == '\0') {return arg;}

  // Return plusarg value
  return arg + (len+2);
}

static FILE* open_argfile(const char* argname, const char* mode,
                          FILE* defaultval) {
  const char* filename = get_plusarg(argname);
  if(filename[0] == '\0') {return defaultval;}

  FILE* result = fopen(filename, mode);
  if(!result) {
    fprintf(stderr, "Cannot open file %s\n", filename);
    exit(1);
  }

  return result;
}

static void print_stats() {
  puts("*** SUMMARY STATISTICS ***");
  printf("Cycles elapsed: %ld\n", simtime);
  printf("Instructions retired: %d\n", stats.instret);
  printf("Average CPI: %.3f\n", ((double) simtime) / stats.instret);
  printf("Branch prediction accuracy: %.2f\n",
         1.0 - (((double) stats.mispreds) / stats.branches));

  fputs("ROB occupancy histogram: ", stdout);
  for(int i = 0; i < ROB_SIZE+1; i++)
    printf("%d,", stats.rob_inflight_hist[i]);
  putchar('\n');

  fputs("LQ occupancy histogram: ", stdout);
  for(int i = 0; i < LQ_SIZE+1; i++)
    printf("%d,", stats.lq_inflight_hist[i]);
  putchar('\n');

  fputs("SQ occupancy histogram: ", stdout);
  for(int i = 0; i < SQ_SIZE+1; i++)
    printf("%d,", stats.sq_inflight_hist[i]);
  putchar('\n');
}

static const char* get_csr_name(uint16_t addr) {
  try {
    return csr_names.at(addr).c_str();
  } catch(...) {
    return "<unknown>";
  }
}

static void tick() {
  top->top->clk = 1;
  top->eval();
  top->top->clk = 0;
  top->eval();

  dram->tick();

  if(!top->top->rst)
    stats.rob_inflight_hist[stats.rob_inflight]++;

  simtime++;
}

int main(int argc, char** argv) {
  // Parse cmdline args
  context = new VerilatedContext;
  context->commandArgs(argc, argv);

  // initialize ROM
  FILE* romfile = open_argfile("memfile", "r", nullptr);
  if(romfile) {
    for(size_t i = 0; i < ROM_SIZE; i++) {
      if(fscanf(romfile, "%x\n", &mem_rom[i]) != 1) {break;}
    }
    fclose(romfile);
  }

  // Open files
  uartfile = open_argfile("uartfile", "w", stdout);
  tracefile = open_argfile("tracefile", "w", nullptr);
  logfile = open_argfile("logfile", "w", nullptr);

    // Initialize models
  top = new Vtop(context);
  dram = new DRAM(context, -9);
  if(!dram->initialized()) {
    fprintf(stderr, "ERROR: dramsim failed to initialize\n");
    delete dram;
    delete top;
    delete context;
    return 1;
  }

  // Reset models
  simtime = 0;
  top->top->clk = 0;
  top->top->rst = 1;
  do {tick();} while(simtime < 10);
  top->top->rst = 0;

  // Main sim loop
  while(!context->gotFinish()) {tick();}

  print_stats();

  // Free models
  delete dram;
  delete top;
  delete context;
}

// DPI functions
extern "C" {

// dramctl <-> dramsim interface
svBit dramsim_cmdready(const svBit write, const svBitVecVal* addr) {
  return dram->cmdready(write, *addr << 2);
}

void dramsim_cmddata(const svBit write, const svBitVecVal* tag,
                     const svBitVecVal* addr, const svBitVecVal* data) {
  dram->cmddata(write, *tag, *addr << 2, data);
}

svBit dramsim_respready() {
  return dram->respready();
}

void dramsim_respdata(svBitVecVal* tag, svBitVecVal* addr, svBitVecVal* data) {
  resp_t resp;
  dram->respdata(&resp);

  *tag = resp.tag;
  *addr = resp.addr >> 2;
  for(int i = 0; i < 8; i++) {
    data[(i*2)] = resp.line.data[i];
    data[(i*2)+1] = resp.line.data[i] >> 32;
  }
}

// testbench functions
int tb_log_bus_cycle(svBit nack, svBit hit, const svBitVecVal* cmd,
                     const svBitVecVal* tag, const svBitVecVal* addr) {
  if(!logfile) {return 0;}

  const char* cmd_name;
  switch(*cmd) {
  case CMD_BUSRD:
    cmd_name = "BusRd";
    break;
  case CMD_BUSRDX:
    cmd_name = "BusRdX";
    break;
  case CMD_BUSUPGR:
    cmd_name = "BusUpgr";
    break;
  case CMD_FILL:
    cmd_name = "Fill";
    break;
  case CMD_FLUSH:
    cmd_name = "Flush";
    break;
  default:
    cmd_name = "???";
    break;
  }

  fprintf(logfile, "%ld bus %d:%d %0s %08x", simtime,
          (*tag >> 3) & 0b11, *tag & 0b111, cmd_name, *addr << 6);
  if(*cmd == CMD_FILL || *cmd == CMD_FLUSH)
    for(int i = 0; i < 8; i++)
      fprintf(logfile, " %08x", bus_data[i]);
  if(nack)
    fputs(" NACK", logfile);
  if(hit)
    fputs(" Hit", logfile);
  fputc('\n', logfile);

  return 0;
}

int tb_log_bus_data(const svBitVecVal* index, const svBitVecVal* data) {
  if(!logfile) {return 0;}

  bus_data[*index] = ((uint64_t) data[0]) | (((uint64_t) data[1]) << 32);

  return 0;
}

int tb_log_dcache_req(const svBitVecVal* lsqid, const svBitVecVal* op,
                      const svBitVecVal* addr, const svBitVecVal* wdata) {
  if(!logfile) {return 0;}

  const char* mnemonic;
  switch(*op) {
  case 0b0000:
    mnemonic = "lb";
    break;
  case 0b0010:
    mnemonic = "lh";
    break;
  case 0b0100:
    mnemonic = "lw";
    break;
  case 0b1000:
    mnemonic = "lbu";
    break;
  case 0b1010:
    mnemonic = "lhu";
    break;
  case 0b0001:
    mnemonic = "sb";
    break;
  case 0b0011:
    mnemonic = "sh";
    break;
  case 0b0101:
    mnemonic = "sw";
    break;
  case 0b0110:
  case 0b1110:
    mnemonic = "lbcmp";
    break;
  default:
    mnemonic = "???";
    break;
  }

  fprintf(logfile, "%ld %0s %08x", simtime, mnemonic, *addr);
  if(*op & 1)
    fprintf(logfile, " %08x", *wdata);
  else {
    if(*op == 0b0110 || *op == 0b1110) // lbcmp
      fprintf(logfile, " %2x", *wdata & 0xff);
    fprintf(logfile, " %d", *lsqid);
  }
  fputc('\n', logfile);

  return 0;
}

int tb_log_dcache_resp(const svBitVecVal* lsqid, svBit error,
                       const svBitVecVal* rdata) {
  if(!logfile) {return 0;}

  fprintf(logfile, "%ld resp %d", simtime, *lsqid);
  if(error)
    fputs(" error", logfile);
  else
    fprintf(logfile, " %08x", *rdata);
  fputc('\n', logfile);

  return 0;
}

int tb_log_lsq_inflight(const svBitVecVal* lq_valid,
                        const svBitVecVal* sq_valid) {
  int cnt = 0;
  for(int i = 0; i < LQ_SIZE; i++) {
    if((*lq_valid >> i) & 1)
      cnt++;
  }
  stats.lq_inflight_hist[cnt]++;

  cnt = 0;
  for(int i = 0; i < SQ_SIZE; i++) {
    if((*sq_valid >> i) & 1)
      cnt++;
  }
  stats.sq_inflight_hist[cnt]++;

  return 0;
}

int tb_log_rob_flush() {
  if(logfile)
    fprintf(logfile, "%ld flush\n", simtime);

  stats.rob_inflight = 0;

  return 0;
}

int tb_mem_read(const svBitVecVal* addr, svBitVecVal* rdata) {
  if(*addr >= ROM_BASE && *addr < (ROM_BASE+ROM_SIZE))
    *rdata = mem_rom[*addr-ROM_BASE];
  else
    *rdata = 0;

  return 0;
}

int tb_trace_csr_write(const svBitVecVal* robid, const svBitVecVal* addr,
                       const svBitVecVal* data) {
  rob_trace_t& rob_entry = rob_trace[*robid];
  rob_entry.writes_csr = true;
  rob_entry.membase = *addr;
  rob_entry.memdata = *data;

  return 0;
}

int tb_trace_decode(const svBitVecVal* robid, const svBitVecVal* insn,
                    const svBitVecVal* imm) {
  rob_trace_t& rob_entry = rob_trace[*robid];
  rob_entry.insn = *insn;
  rob_entry.imm = *imm;
  rob_entry.uses_mem = false;
  rob_entry.writes_csr = false;

  stats.rob_inflight++;

  return 0;
}

int tb_trace_lsq_base(const svBitVecVal* lsqid, const svBitVecVal* base) {
  lsq_trace_t& lsq_entry = lsq_trace[*lsqid];
  rob_trace_t& rob_entry = rob_trace[lsq_entry.robid];
  rob_entry.membase = *base;

  return 0;
}

int tb_trace_lsq_dispatch(const svBitVecVal* robid, const svBitVecVal* lsqid,
                          const svBitVecVal* op, const svBitVecVal* base,
                          const svBitVecVal* wdata) {
  lsq_trace_t& lsq_entry = lsq_trace[*lsqid];
  lsq_entry.robid = *robid;

  rob_trace_t& rob_entry = rob_trace[*robid];
  rob_entry.uses_mem = true;
  rob_entry.memop = *op;
  rob_entry.membase = *base;
  rob_entry.memdata = *wdata;

  return 0;
}

int tb_trace_lsq_wdata(const svBitVecVal* lsqid, const svBitVecVal* wdata) {
  lsq_trace_t& lsq_entry = lsq_trace[*lsqid];
  rob_trace_t& rob_entry = rob_trace[lsq_entry.robid];
  rob_entry.memdata = *wdata;

  return 0;
}

int tb_trace_rob_retire(const svBitVecVal* robid, const svBitVecVal* retop,
                        const svBitVecVal* addr, svBit error, svBit mispred,
                        const svBitVecVal* ecause, const svBitVecVal* rd,
                        const svBitVecVal* result) {
  // Update stats
  stats.instret++;
  if((*retop >> 6) & 1) {
    stats.branches++;
    if(mispred)
      stats.mispreds++;
  }
  stats.rob_inflight--;

  // Generate trace output
  rob_trace_t& rob_entry = rob_trace[*robid];
  uint32_t memaddr = rob_entry.membase + rob_entry.imm;
  if(tracefile) {
    fprintf(tracefile, "core   0: 3 0x%08x (0x%08x)", *addr << 2, rob_entry.insn);
    if(error)
      fprintf(tracefile, " error %d", *ecause);
    else {
      if(!((*rd >> 5) & 1))
        fprintf(tracefile, " x%2d 0x%08x", *rd & 0b11111, *result);
      if(rob_entry.uses_mem) {
        fprintf(tracefile, " mem 0x%08x", memaddr);
        if((rob_entry.memop >> 3) & 1)
          switch(rob_entry.memop & 0b11) {
          case 0b00: // byte write
            // needs to be %01x to match spike
            fprintf(tracefile, " 0x%01x", rob_entry.memdata & 0xff);
            break;
          case 0b01: // halfword write
            fprintf(tracefile, " 0x%04x", rob_entry.memdata & 0xffff);
            break;
          default: // word write
            fprintf(tracefile, " 0x%08x", rob_entry.memdata);
            break;
          }
        else if((rob_entry.memop & 0b11) == 0b11) {
          // lbcmp makes multiple sequential accesses
          fprintf(tracefile, " mem 0x%08x", memaddr+8);
          fprintf(tracefile, " mem 0x%08x", memaddr+16);
          fprintf(tracefile, " mem 0x%08x", memaddr+24);
        }
      }
      if(rob_entry.writes_csr) {
        const char* csr_name = get_csr_name(rob_entry.membase);
        fprintf(tracefile, " c%d_%0s 0x%08x", rob_entry.membase,
                csr_name, rob_entry.memdata);
      }
    }
    fputc('\n', tracefile);
  }

  // Generate log output
  if(logfile) {
    fprintf(logfile, "%ld ret %08x", simtime, *addr << 2);
    if(!((*rd >> 5) & 1))
      fprintf(logfile, " x%d=%08x", *rd & 0b11111, *result);
    fputc('\n', logfile);
  }

  // HTIF tohost write termination
  if(!error && rob_entry.uses_mem && ((rob_entry.memop >> 3) & 1) &&
     ((memaddr >> 2) == DBG_TOHOST)) {
    context->gotFinish(true);
  }

  return 0;
}

int tb_uart_tx(const svBitVecVal* c) {
  fputc(*c, uartfile);
  return 0;
}

}
