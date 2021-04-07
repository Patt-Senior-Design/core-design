// pma checker
module pmacheck(
  input [31:6] addr,
  input        write,
  output       valid);

  localparam
    ROM_BASE = 32'h10000000/64,
    ROM_SIZE = (256*1024)/64,
    RAM_BASE = 32'h20000000/64,
    RAM_SIZE = (128*1024*1024)/64;

  /*verilator lint_off WIDTH*/
  wire rom_valid, ram_valid;
  assign rom_valid = ~write & (addr >= ROM_BASE) & (addr < ROM_BASE+ROM_SIZE);
  assign ram_valid = (addr >= RAM_BASE) & (addr < RAM_BASE+RAM_SIZE);
  /*verilator lint_on WIDTH*/

  assign valid = rom_valid | ram_valid;

endmodule
