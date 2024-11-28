// `define ROB_BIT 1
// `define ROB_SIZE 2

// `define REG_BIT 5
// `define REG_SIZE 32

// `define LUI 7'b0110111
// `define AUIPC 7'b0010111
// `define JAL 7'b1101111
// `define JALR 7'b1100111
// `define B_TYPE 7'b1100011
// `define LD_TYPE 7'b0000011
// `define S_TYPE 7'b0100011
// `define ALGI_TYPE 7'b0010011
// `define R_TYPE 7'b0110011

// `define RS_BIT 1 
// `define RS_SIZE 2

// `define LSB_BIT 1
// `define LSB_SIZE 2

//todo:一级流水兼容

`define ROB_BIT 5
`define ROB_SIZE (1 << `ROB_BIT)

`define REG_BIT 5
`define REG_SIZE (1 << `REG_BIT)

`define LUI 7'b0110111
`define AUIPC 7'b0010111
`define JAL 7'b1101111
`define JALR 7'b1100111
`define B_TYPE 7'b1100011
`define LD_TYPE 7'b0000011
`define S_TYPE 7'b0100011
`define ALGI_TYPE 7'b0010011
`define R_TYPE 7'b0110011

`define RS_BIT 4
`define RS_SIZE (1 << `RS_BIT)

`define LSB_BIT 3
`define LSB_SIZE (1 << `LSB_BIT)

`define CACHE_BIT 4
`define CACHE_SIZE (1 << `CACHE_BIT)
`define TAG_BIT 32-1-`CACHE_BIT

//todo:数据丢失？

//done:store 可以直接提交 不用等完成，但clear可能会有问题

//todo:io_buffer_is_full

//todo:cache优化

//todo:about is_c_in is_c_out