// command defines
// - without data
`define CMD_BUSRD   3'b000
`define CMD_BUSRDX  3'b001
`define CMD_BUSUPGR 3'b010
// - with data
`define CMD_FILL    3'b100
`define CMD_FLUSH   3'b101

// busid defines (upper bits of tag)
`define BUSID_L2   2'b00
`define BUSID_BFS  2'b01
`define BUSID_DRAM 2'b10

// cache operations
`define OP_RD   2'b01
`define OP_WR4  2'b10
`define OP_WR64 2'b00
`define OP_MARK 2'b11

// cache state defines
`define STATE_M  3'b101 // modified
`define STATE_E  3'b001 // exclusive
`define STATE_S  3'b010 // shared
`define STATE_I  3'b000 // invalid
`define STATE_F  3'b011 // forward
