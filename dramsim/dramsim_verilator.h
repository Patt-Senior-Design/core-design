#ifndef DRAMSIM_VERILATOR_H
#define DRAMSIM_VERILATOR_H

#include <verilated.h>
#include "dramsim3.h"
#include <cstdint>
#include <string>
#include <queue>
#include <unordered_map>

typedef unsigned tag_t;

typedef struct {
  uint64_t data[8];
} line_t;

typedef struct {
  tag_t tag;
  uint64_t addr;
  line_t line;
} resp_t;

class DRAM {
public:
  DRAM(VerilatedContext* context, int timeunit);
  ~DRAM();

  bool initialized();
  void tick();

  bool cmdready(bool write, uint64_t addr);
  void cmddata(bool write, tag_t tag, uint64_t addr, const uint32_t* data);

  bool respready();
  void respdata(resp_t* resp);

private:
  dramsim3::MemorySystem* dramsim;
  uint64_t *memory;
  uint32_t clk_unit, clk_period, clk_elapsed;

  std::queue<resp_t> read_queue;
  std::unordered_map<tag_t,line_t> write_queue;

  DRAM(const DRAM&) = delete;
  DRAM& operator=(const DRAM&) = delete;

  // invoked by dramsim3 upon request completion
  void read_cb(tag_t tag, uint64_t addr);
  void write_cb(tag_t tag, uint64_t addr);
};

#endif
