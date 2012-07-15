//
// Constants used in various fields in instructions
//

`define NOP				32'd0

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

// A/B instruction opcodes
`define OP_OR			6'b000000
`define OP_AND			6'b000001
`define OP_UMINUS		6'b000010
`define OP_XOR			6'b000011
`define OP_NOT			6'b000100
`define OP_IADD			6'b000101
`define OP_ISUB			6'b000110
`define OP_ASR			6'b001001	// Arithmetic shift right (sign extend)
`define OP_LSR			6'b001010	// Logical shift right (no sign extend)
`define OP_LSL			6'b001011	// Logical shift left
`define OP_CLZ			6'b001100	// Count leading zeroes
`define OP_CTZ			6'b001110	// Count trailing zeroes
`define OP_COPY			6'b001111
`define OP_EQUAL		6'b010000
`define OP_NEQUAL		6'b010001
`define OP_SIGTR		6'b010010	// Integer greater (signed)
`define OP_SIGTE		6'b010011	// Integer greater or equal (signed)
`define OP_SILT			6'b010100	// Integer less than (signed)
`define OP_SILTE		6'b010101	// Integer less than or equal (signed)
`define OP_UIGTR		6'b010110	// Integer greater than (unsigned)
`define OP_UIGTE		6'b010111	// Integer greater or equal (unsigned)
`define OP_UILT			6'b011000	// Integer less than (unsigned)
`define OP_UILTE		6'b011001	// Integer less than or equal (unsigned)
`define OP_GETLANE		6'b011010	// getlane
`define OP_IMUL			6'b000111	
`define OP_SFTOI		6'b110000
`define OP_FGTR			6'b101100	// Floating point greater than
`define OP_FLT			6'b101110	// Floating point less than
`define OP_FGTE			6'b101101	// Floating point greater or equal
`define OP_FLTE			6'b101111	// Floating point less than or equal
`define OP_RECIP		6'b101000
`define OP_FMUL			6'b100010
`define OP_SITOF		6'b101010
`define OP_SHUFFLE		6'b001101
`define OP_FADD			6'b100000

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

// Instruction format D operation types
`define CACHE_DPRELOAD		3'b000
`define CACHE_DINVALIDATE 	3'b001
`define CACHE_DFLUSH		3'b010
`define CACHE_IINVALIDATE	3'b011
`define CACHE_BARRIER		3'b100

// Instruction format E operation types
`define BRANCH_ALL			3'b000
`define BRANCH_ZERO			3'b001
`define BRANCH_NOT_ZERO		3'b010
`define BRANCH_ALWAYS		3'b011
`define BRANCH_CALL_OFFSET 	3'b100
`define BRANCH_NOT_ALL		3'b101
`define BRANCH_CALL_REGISTER 3'b110

