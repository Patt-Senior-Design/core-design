#include "dramsim3.h"
#include "vpi_user.h"
#include <cstdint>
#include <cstring>
#include <queue>
#include <unordered_map>

typedef unsigned tag_t;

// variables
static dramsim3::MemorySystem* dramsim;

static vpiHandle h_dramclk;
static s_vpi_time dramclk_period;
static bool dramclk_val = true;

static uint64_t* memory;

typedef struct {
  uint64_t data[8];
} line_t;
typedef struct {
  tag_t tag;
  uint64_t addr;
  line_t line;
} resp_t;
static std::queue<resp_t> read_queue;
static std::unordered_map<tag_t,line_t> write_queue;

// dramsim callbacks
static void read_cb(tag_t tag, uint64_t addr);
static void write_cb(tag_t tag, uint64_t addr);

// vpi utility funcs
static PLI_INT32 get_scalar(vpiHandle handle);
static uint64_t get_vector(vpiHandle handle, bool is64bits);
static void set_scalar(vpiHandle handle, PLI_UINT32 value);
static void set_vector(vpiHandle handle, uint64_t value);
static void register_scalar_cb(vpiHandle handle, PLI_INT32(*cb)(p_cb_data));
static void register_vector_cb(vpiHandle handle, PLI_INT32(*cb)(p_cb_data));

// vpi callbacks
static PLI_INT32 startsim_cb(p_cb_data cb_data);
static PLI_INT32 endsim_cb(p_cb_data cb_data);
static PLI_INT32 dramclk_cb(p_cb_data cb_data);
static PLI_INT32 error_cb(p_cb_data cb_data);

// vpi tasks/functions
static PLI_INT32 init_calltf(PLI_BYTE8* user_data);
static PLI_INT32 cmdready_calltf(PLI_BYTE8* user_data);
static PLI_INT32 cmddata_calltf(PLI_BYTE8* user_data);
static PLI_INT32 respready_calltf(PLI_BYTE8* user_data);
static PLI_INT32 respdata_calltf(PLI_BYTE8* user_data);

static void read_cb(tag_t tag, uint64_t addr) {
  resp_t resp;
  resp.tag = tag;
  resp.addr = addr;
  for(int i = 0; i < 8; i++) {
    resp.line.data[i] = memory[(addr >> 3) + i];
  }
  read_queue.push(resp);
}

static void write_cb(tag_t tag, uint64_t addr) {
  auto itr = write_queue.find(tag);
  if(itr == write_queue.end()) {
    vpi_printf("WARN: dramsim invoked write_cb with unknown tag\n");
    return;
  }

  for(int i = 0; i < 8; i++) {
    memory[(addr >> 3) + i] = itr->second.data[i];
  }
  write_queue.erase(itr);
}

static PLI_INT32 get_scalar(vpiHandle handle) {
  s_vpi_value vpi_value = {vpiScalar};
  vpi_get_value(handle, &vpi_value);
  return vpi_value.value.scalar;
}

static uint64_t get_vector(vpiHandle handle, bool is64bits) {
  s_vpi_value vpi_value = {vpiVectorVal};
  vpi_get_value(handle, &vpi_value);
  if(vpi_value.value.vector[0].bval || (is64bits && vpi_value.value.vector[1].bval)) {
    vpi_printf("WARN: dramsim: found x/z in input signals\n");
  }

  uint64_t value = vpi_value.value.vector[0].aval;
  if(is64bits) {value |= ((uint64_t) vpi_value.value.vector[1].aval) << 32;}
  return value;
}

static void set_scalar(vpiHandle handle, PLI_UINT32 value) {
  s_vpi_value vpi_value = {vpiScalarVal};
  vpi_value.value.scalar = value;
  vpi_put_value(handle, &vpi_value, nullptr, vpiNoDelay);
}

static void set_vector(vpiHandle handle, uint64_t value) {
  s_vpi_vecval vpi_vecval[2];
  vpi_vecval[0] = {(PLI_UINT32) value, 0};
  vpi_vecval[1] = {(PLI_UINT32) (value >> 32), 0};
  s_vpi_value vpi_value = {vpiVectorVal};
  vpi_value.value.vector = vpi_vecval;
  vpi_put_value(handle, &vpi_value, nullptr, vpiNoDelay);
}

static void register_scalar_cb(vpiHandle handle, PLI_INT32(*cb)(p_cb_data)) {
  s_vpi_time cb_time = {vpiSuppressTime};
  s_vpi_value cb_value = {vpiSuppressVal};
  s_cb_data cb_data = {cbValueChange, cb, handle, &cb_time, &cb_value};
  vpi_register_cb(&cb_data);
}

static void register_vector_cb(vpiHandle handle, PLI_INT32(*cb)(p_cb_data)) {
  s_vpi_time cb_time = {vpiSuppressTime};
  s_vpi_value cb_value = {vpiSuppressVal};
  s_cb_data cb_data = {cbValueChange, cb, handle, &cb_time, &cb_value};
  vpi_register_cb(&cb_data);
}

static PLI_INT32 startsim_cb(p_cb_data cb_data) {
  // get plusarg for dram cfgfile
  const char* dramcfg = nullptr;
  s_vpi_vlog_info vlog_info;
  vpi_get_vlog_info(&vlog_info);
  for(int i = 0; i < vlog_info.argc; i++) {
    if(strncmp(vlog_info.argv[i], "+dramcfg=", 9)) {continue;}
    dramcfg = &vlog_info.argv[i][9];
  }
  if(!dramcfg) {
    vpi_printf("ERROR: no dramcfg specified\n");
    vpi_control(vpiFinish, 0);
    return 0;
  }

  // initialize dramsim and memory
  dramsim = dramsim3::GetMemorySystem(dramcfg, "output", read_cb, write_cb);
  memory = new uint64_t[128*1024*1024/4];

  // fetch dramsim and vpi timing parameters
  double period_ns = dramsim->GetTCK() / 2;
  PLI_INT32 precision = vpi_get(vpiTimePrecision, nullptr);

  // convert dramsim clock period to vpi time units
  for(; precision < -9; precision++) {period_ns *= 10;}
  PLI_UINT64 period_sim = (PLI_UINT64) period_ns;

  // check conversion error
  double error = (period_sim - period_ns) / period_ns;
  if(error > 0.05) {
    vpi_printf("ERROR: rounding error for dram clock period is too high, try increasing time precision\n");
    vpi_control(vpiFinish, 0);
    return 0;
  }

  // set dramclk period
  dramclk_period.type = vpiSimTime;
  dramclk_period.high = (PLI_UINT32) (period_sim >> 32);
  dramclk_period.low = (PLI_UINT32) period_sim;

  return 0;
}

static PLI_INT32 endsim_cb(p_cb_data cb_data) {
  delete dramsim;
  delete[] memory;
  return 0;
}

static PLI_INT32 dramclk_cb(p_cb_data cb_data) {
  dramclk_val = !dramclk_val;

  // positive clock edge?
  if(dramclk_val) {
    // clock dramsim (read_cb/write_cb invoked here)
    dramsim->ClockTick();
  }

  // schedule next clock edge
  s_vpi_value clk_val_next = {vpiScalarVal};
  clk_val_next.value.scalar = dramclk_val ? vpi0 : vpi1;
  vpi_put_value(h_dramclk, &clk_val_next, &dramclk_period, vpiInertialDelay);

  return 0;
}

static PLI_INT32 error_cb(p_cb_data cb_data) {
  s_vpi_error_info error;
  if(vpi_chk_error(&error)) {
    vpi_printf("%s\n", error.message);
  }
  return 0;
}

static PLI_INT32 init_calltf(PLI_BYTE8* user_data) {
  // VCS doesn't support cbStartOfSimulation so we invoke the callback here
  startsim_cb(nullptr);

  // register endsim_cb
  s_cb_data cb_data = {cbEndOfSimulation, endsim_cb};
  vpi_register_cb(&cb_data);
  cb_data = {cbPLIError, error_cb};
  vpi_register_cb(&cb_data);

  // initialize dramclk
  vpiHandle args;
  args = vpi_iterate(vpiArgument, vpi_handle(vpiSysTfCall, nullptr));
  h_dramclk = vpi_scan(args);
  vpi_free_object(args);

  // register dramclk_cb
  register_scalar_cb(h_dramclk, dramclk_cb);

  // set initial values
  set_scalar(h_dramclk, vpi0);

  return 0;
}

static PLI_INT32 cmdready_calltf(PLI_BYTE8* user_data) {
  vpiHandle func, args, h_write, h_addr;
  func = vpi_handle(vpiSysTfCall, nullptr);
  args = vpi_iterate(vpiArgument, func);
  h_write = vpi_scan(args);
  h_addr = vpi_scan(args);
  vpi_free_object(args);

  bool write = get_scalar(h_write) == vpi1;
  uint64_t addr = (get_vector(h_addr, false) << 2) & ~63;
  bool cmdready = dramsim->WillAcceptTransaction(addr, write);

  set_scalar(func, cmdready ? vpi1 : vpi0);
  return 0;
}

static PLI_INT32 cmddata_calltf(PLI_BYTE8* user_data) {
  vpiHandle args, h_write, h_tag, h_addr, h_data;
  args = vpi_iterate(vpiArgument, vpi_handle(vpiSysTfCall, nullptr));
  h_write = vpi_scan(args);
  h_tag = vpi_scan(args);
  h_addr = vpi_scan(args);
  h_data = vpi_scan(args);
  vpi_free_object(args);

  bool write = get_scalar(h_write) == vpi1;
  tag_t tag = get_vector(h_tag, false);
  uint64_t addr = (get_vector(h_addr, false) << 2) & ~63;

  if(write) {
    // too wide for our usual get_vector function (512 bits)
    s_vpi_value vpi_value = {vpiVectorVal};
    vpi_get_value(h_data, &vpi_value);

    line_t line;
    for(int i = 0; i < 8; i++) {
      line.data[i] = ((uint64_t) vpi_value.value.vector[i*2].aval) | (((uint64_t) vpi_value.value.vector[(i*2)+1].aval) << 32);
    }

    write_queue[tag] = line;
  }

  dramsim->AddTransaction(tag, addr, write);
  return 0;
}

static PLI_INT32 respready_calltf(PLI_BYTE8* user_data) {
  set_scalar(vpi_handle(vpiSysTfCall, nullptr), read_queue.empty() ? vpi0 : vpi1);
  return 0;
}

static PLI_INT32 respdata_calltf(PLI_BYTE8* user_data) {
  vpiHandle args, h_tag, h_addr, h_data;
  args = vpi_iterate(vpiArgument, vpi_handle(vpiSysTfCall, nullptr));
  h_tag = vpi_scan(args);
  h_addr = vpi_scan(args);
  h_data = vpi_scan(args);
  vpi_free_object(args);

  resp_t& resp = read_queue.front();
  set_vector(h_tag, resp.tag);
  set_vector(h_addr, resp.addr >> 2);

  // too wide for our usual set_vector function (512 bits)
  s_vpi_vecval vpi_vecval[16];
  for(int i = 0; i < 8; i++) {
    uint64_t dword = resp.line.data[i];
    vpi_vecval[i*2] = {(PLI_UINT32) dword, 0};
    vpi_vecval[(i*2)+1] = {(PLI_UINT32) (dword >> 32), 0};
  }
  s_vpi_value vpi_value = {vpiVectorVal};
  vpi_value.value.vector = vpi_vecval;
  vpi_put_value(h_data, &vpi_value, nullptr, vpiNoDelay);

  read_queue.pop();
  return 0;
}

// VCS needs unmangled symbols
#define SHIM(func) PLI_INT32 func##_shim(PLI_BYTE8* user_data) {return func(user_data);}
extern "C" {
SHIM(init_calltf)
SHIM(cmdready_calltf)
SHIM(cmddata_calltf)
SHIM(respready_calltf)
SHIM(respdata_calltf)

uint64_t get_simtime(void) {
  s_vpi_time vpi_time = {vpiSimTime};
  vpi_get_time(nullptr, &vpi_time);
  return ((uint64_t) vpi_time.low) | (((uint64_t) vpi_time.high) << 32);
}

}
#undef SHIM
