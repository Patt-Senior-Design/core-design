#include "dramsim_verilator.h"
#include <cstdio>

DRAM::DRAM(VerilatedContext* context, int timeunit) {
  // get plusarg for dram cfgfile
  std::string dramcfg = context->commandArgsPlusMatch("dramcfg=");
  if(dramcfg.length() < 10) {
    fprintf(stderr, "ERROR: no dramcfg specified\n");
    return;
  }
  dramcfg = dramcfg.substr(9);

  // initialize dramsim and memory
  auto read_cb = std::bind(&DRAM::read_cb, this,
                           std::placeholders::_1, std::placeholders::_2);
  auto write_cb = std::bind(&DRAM::write_cb, this,
                            std::placeholders::_1, std::placeholders::_2);
  dramsim = dramsim3::GetMemorySystem(dramcfg, "output", read_cb, write_cb);
  memory = new uint64_t[128*1024*1024/4];

  // calculate clock parameters (1ps resolution)
  clk_unit = 1;
  for(int i = -12; i < timeunit; i++) {clk_unit *= 10;}
  clk_period = (uint32_t) (dramsim->GetTCK() * 1000);
}

DRAM::~DRAM() {
  delete dramsim;
  delete[] memory;
}

bool DRAM::initialized() {
  return dramsim != nullptr && memory != nullptr;
}

void DRAM::tick() {
  clk_elapsed += clk_unit;
  while(clk_elapsed >= clk_period) {
    dramsim->ClockTick();
    clk_elapsed -= clk_period;
  }
}

void DRAM::read_cb(tag_t tag, uint64_t addr) {
  resp_t resp;
  resp.tag = tag;
  resp.addr = addr;
  for(int i = 0; i < 8; i++) {
    resp.line.data[i] = memory[(addr >> 3) + i];
  }
  read_queue.push(resp);
}

void DRAM::write_cb(tag_t tag, uint64_t addr) {
  auto itr = write_queue.find(tag);
  if(itr == write_queue.end()) {
    fprintf(stderr, "WARN: dramsim invoked write_cb with unknown tag\n");
    return;
  }

  for(int i = 0; i < 8; i++) {
    memory[(addr >> 3) + i] = itr->second.data[i];
  }
  write_queue.erase(itr);
}

bool DRAM::cmdready(bool write, uint64_t addr) {
  return dramsim->WillAcceptTransaction(addr & ~63, write);
}

void DRAM::cmddata(bool write, tag_t tag, uint64_t addr, const uint32_t* data) {
  if(write) {
    line_t line;
    for(int i = 0; i < 8; i++) {
      line.data[i] = ((uint64_t) data[(i*2)]) | (((uint64_t) data[(i*2)+1]) << 32);
    }
    write_queue[tag] = line;
  }

  dramsim->AddTransaction(tag, addr & ~63, write);
}

bool DRAM::respready() {
  return !read_queue.empty();
}

void DRAM::respdata(resp_t* resp) {
  *resp = read_queue.front();
  read_queue.pop();
}
