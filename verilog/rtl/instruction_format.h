//
// Constants used in various fields in instructions
//

`define OP_NOP			32'd0

`define REG_PC			5'd31
`define REG_LINK		5'd30

// Instruction format A operation types
`define FMTA_S			3'b000
`define FMTA_V_S		3'b001
`define FMTA_V_S_M		3'b010
`define FMTA_V_S_IM		3'b011
`define FMTA_V_V		3'b100
`define FMTA_V_V_M		3'b101
`define FMTA_V_V_IM		3'b110

// Instruction format B operation types (first param is dest type, second is first src)
`define FMTB_S_S		3'b000
`define FMTB_V_V		3'b001
`define FMTB_V_V_M		3'b010
`define FMTB_V_V_IM		3'b011
`define FMTB_V_S		3'b100
`define FMTB_V_S_M		3'b101
`define FMTB_V_S_IM		3'b110

// Instruction format C operation types
`define MEM_B 			4'b0000		// Byte (8 bit)
`define MEM_BX 			4'b0001		// Byte, sign extended
`define MEM_S 			4'b0010		// Short (16 bit)
`define MEM_SX			4'b0011		// Short, sign extended
`define MEM_L			4'b0100		// Long (32 bit)
`define MEM_SYNC		4'b0101		// Synchronized
`define MEM_CONTROL_REG	4'b0110		// Control register
`define MEM_BLOCK		4'b0111		// Vector block
`define MEM_BLOCK_M		4'b1000
`define MEM_BLOCK_IM	4'b1001
`define MEM_STRIDED		4'b1010		// Vector strided
`define MEM_STRIDED_M	4'b1011
`define MEM_STRIDED_IM	4'b1100
`define MEM_SCGATH		4'b1101		// Vector scatter/gather
`define MEM_SCGATH_M	4'b1110
`define MEM_SCGATH_IM	4'b1111

// Branch type field
`define BRANCH_ALL		3'b000
`define BRANCH_ZERO		3'b001
`define BRANCH_NOT_ZERO	3'b010
`define BRANCH_ALWAYS	3'b011
`define BRANCH_CALL		3'b100
`define BRANCH_NOT_ALL	3'b101

