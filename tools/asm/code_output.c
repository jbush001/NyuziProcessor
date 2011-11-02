//
// Endian can be a little confusing in this file.  This assumes the host machine
// is little endian.  The target machine is also little endian.  However,
// $readmemh effectively assumes bigendian byte order.
//

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>
#include <assert.h>
#include "code_output.h"
#include "debug_info.h"

#define ALLOC_SIZE 128
#define PC_REG 31

struct Fixup
{
	struct Fixup *next;
	enum {
		FU_BRANCH,			// branch to label (format E)
		FU_PCREL_MEMACCESS,	// PC relative memory access
		FU_PCREL_LOAD_ADDR,	// PC relative load address into register
		FU_LABEL_ADDRESS	// Data, just the address of a label
	} type;
	int programCounter;
	const struct Symbol *sym;
	const char *sourceFile;
	int lineno;
};

enum ParamConfig
{
	UNARY_INT,
	BINARY_INT,
	UNARY_FP,
	BINARY_FP,
	INVALID_CFG	// Mixing int and fp args
};

extern void printAssembleError(const char *filename, int lineno, const char *fmt, 
	...);

static unsigned int *codes;
static int codeAlloc;
static int nextPc = 0;
static struct Fixup *fixupList = NULL;
static FILE *outputFile;
static char *currentSourceFile;

int openOutputFile(const char *file)
{
	outputFile = fopen(file, "w");
	if (outputFile == NULL)
		return -1;
		
	return 0;
}

unsigned int swap32(unsigned int value)
{
	return ((value & 0x000000ff) << 24)
		| ((value & 0x0000ff00) << 8)
		| ((value & 0x00ff0000) >> 8)
		| ((value & 0xff000000) >> 24);
}

unsigned int swap16(unsigned int value)
{
	return ((value & 0xff00) >> 8)
		| ((value & 0x00ff) << 8);
}

void closeOutputFile()
{
	int i;

	for (i = 0; i < (nextPc + 3) / 4; i++)
		fprintf(outputFile, "%08x\n", codes[i]);

	fclose(outputFile);
}

void codeOutputSetSourceFile(const char *filename)
{
	free(currentSourceFile);
	currentSourceFile = strdup(filename);
}

void align(int alignment)
{
	if (nextPc % alignment != 0)
		nextPc += (alignment - (nextPc % alignment));	// Align
}

void ensure(int count)
{
	if (nextPc + count >= codeAlloc)
	{
		codes = realloc(codes, codeAlloc + ALLOC_SIZE);
		memset((char*) codes + codeAlloc, 0, ALLOC_SIZE);
		codeAlloc += ALLOC_SIZE;
	}
}

void emitShort(unsigned int value)
{
	int wordOffset = (nextPc / 2) % 2;

	align(2);
	ensure(2);
	codes[nextPc / 4] |= swap16(value) << ((1 - wordOffset) * 16);
	nextPc += 2;
}

void emitByte(unsigned int value)
{
	int byteOffset = (nextPc % 4);

	ensure(1);
	codes[nextPc / 4] |= value << ((3 - byteOffset) * 8);
	nextPc += 1;
}

void emitLong(unsigned int value)
{
	align(4);
	ensure(4);	
	codes[nextPc / 4] = swap32(value);
	nextPc += 4;
}

struct Fixup *createFixup(const struct Symbol *sym, int type, int lineno)
{
	struct Fixup *fu;

	fu = (struct Fixup*) malloc(sizeof(struct Fixup));
	fu->next = fixupList;
	fixupList = fu;
	fu->type = type;
	fu->sym = sym;
	fu->programCounter = nextPc;
	fu->lineno = lineno;
	fu->sourceFile = strdup(currentSourceFile);
	
	return fu;
}

// Used for A and B instructions 
// First array index is operation type (enum OpType), second is
// type and count of parameters (enum ParamFormat)
int abOpcodeTable[][4] = {
	{ -1, 0, -1, -1 },	// OP_OR
	{ -1, 1, -1, -1 },	// OP_AND
	{ -1, 2, -1, -1 },	// OP_AND_NOT
	{ -1, 3, -1, -1 }, 	// OP_XOR
	{ 4, -1, -1, -1 }, 	// OP_NOT
	{ -1, 5, -1, 32 }, 	// OP_PLUS
	{ -1, 6, -1, 33 }, 	// OP_MINUS
	{ -1, 7, -1, 34 },	// OP_MULTIPLY
	{ -1, 8, -1, 35 }, 	// OP_DIVIDE
	{ -1, 9, -1, -1 },	// OP_SHR (* if there is an unsigned op, make this 10)
	{ -1, 11, -1, -1 },	// OP_SHL
	{ 12, -1, -1, -1 }, // OP_CLZ
	{ -1, 16, -1, 13 }, // OP_EQUAL
	{ -1, 17, -1, 14 }, // OP_NOT_EQUAL
	{ -1, 18, -1, 44 },	// OP_GREATER
	{ -1, 19, -1, 45 }, // OP_GREATER_EQUAL
	{ -1, 20, -1, 46 }, // OP_LESS
	{ -1, 21, -1, 47 }, // OP_LESS_EQUAL
	{ -1, -1, -1, -1 },	// OP_SFTOI *unused, we have a conditional to handle this*
	{ -1, 14, -1, -1 }, // OP_SITOF
	{ -1, -1, 38, -1 }, // OP_FLOOR
	{ -1, -1, 39, -1 }, // OP_FRAC
	{ -1, -1, 40, -1 },	// OP_RECIP
	{ -1, -1, 41, -1 },	// OP_ABS
	{ -1, -1, 46, -1 },	// OP_SQRT
};

// 
// Index is made up of { op1 type, op2 type, masked, invert mask }
// where type is 1 if it is a vector.  This returns the value of the
// format field for an A intruction.
//
int aFormatTable[] = {
	0,	 	// Scalar Scalar N N
	-1, 	// Scalar Scalar N Y
	-1, 	// Scalar Scalar Y N
	-1, 	// Scalar Scalar Y Y
	-1, 	// Scalar Vector N N
	-1, 	// Scalar Vector N Y
	-1, 	// Scalar Vector Y N
	-1, 	// Scalar Vector Y Y
	1,	 	// Vector Scalar N N
	-1, 	// Vector Scalar N Y
	2, 		// Vector Scalar Y N
	3,	 	// Vector Scalar Y Y
	4,	 	// Vector Vector N N
	-1, 	// Vector Vector N Y
	5,	 	// Vector Vector Y N
	6	 	// Vector Vector Y Y
};

// 
// Index is made up of { op1 type, masked, invert mask }
// where type is 1 if it is a vector.  This returns the value of the
// format field for an B intruction.
//
int bFormatTable[] = {
	0,	 	// Scalar N N
	-1, 	// Scalar N Y
	-1, 	// Scalar Y N
	-1, 	// Scalar Y Y
	1,	 	// Vector N N
	-1, 	// Vector N Y
	2, 		// Vector Y N
	3,	 	// Vector Y Y
};

// True if instruction translates between integer <-> float
int isTypeConversion(enum OpType operation)
{
	return operation == OP_SFTOI || operation == OP_SITOF;
}

int isCompareOperation(enum OpType operation)
{
	return operation >= OP_EQUAL && operation <= OP_LESS_EQUAL;
}

enum ParamConfig getParamConfig(const struct RegisterInfo *src1,
	const struct RegisterInfo *src2)
{
	if (src2->type == TYPE_FLOAT)
	{
		if (src1)
		{
			if (!src1->type == TYPE_FLOAT)
				return INVALID_CFG;
				
			return BINARY_FP;
		}
		else
			return UNARY_FP;
	}
	else if (src1)
	{
		if (src1->type == TYPE_FLOAT)
			return INVALID_CFG;
			
		return BINARY_INT;
	}

	return UNARY_INT;
}

int emitAInstruction(const struct RegisterInfo *dest, 
	const struct MaskInfo *mask, 
	const struct RegisterInfo *src1, 
	enum OpType operation, 
	const struct RegisterInfo *src2,
	int lineno)
{
	unsigned int instruction;
	int opcode;
	enum ParamConfig cfg;
	int fmt;
	
	// Compute the format field for the instruction (which encodes vector/scalar
	// types for the operand and the mask field).  The dest->isVector
	// part may look a little confusing, but it is an optimization that allows
	// scalar expansion for unary ops.  (For example, v7 = ~s9).
	fmt = aFormatTable[(src1 ? src1->isVector << 3 : dest->isVector << 3)
		| (src2->isVector << 2)
		| (mask->hasMask << 1)
		| mask->invertMask];
	if (fmt == -1)
	{
		printAssembleError(currentSourceFile, lineno, "invalid operand types\n");
		return 0;
	}

	if (operation == OP_SFTOI)
	{
		// This form is a bit special, because the first argument is float
		// and the second is an int.
		opcode = 13;
		if (!src1 || src1->type != TYPE_FLOAT || src2->type == TYPE_FLOAT)
		{
			printAssembleError(currentSourceFile, lineno, "invalid operand types\n");
			return 0;
		}
	}
	else
	{
		// Compute the opcode field.  We first determine the types of the operands
		// (float vs. int) and whether this is a unary or binary operation.
		// Then look the opcode in the table.
		cfg = getParamConfig(src1, src2);
		opcode = abOpcodeTable[operation][cfg];
		if (opcode == -1)
		{
			printAssembleError(currentSourceFile, lineno, "bad operand types\n");
			return 0;
		}
	}
	
	// Special case for signed shifts (which shift in ones if the number is 
	// negative).
	if (operation == OP_SHR && src1->type == TYPE_UNSIGNED_INT)
		opcode = 10;
	
	// Check that destination type is correct (vector/scalar and float/int)
	if (isCompareOperation(operation))
	{
		// This is a comparison.  The destination will always be a scalar,
		// even if the operands are vector types
		if (dest->isVector)
		{
			printAssembleError(currentSourceFile, lineno, "bad destination register type (must be scalar)\n");
			return 0;
		}

		if (dest->type == TYPE_FLOAT)
		{
			printAssembleError(currentSourceFile, lineno, "bad destination register type (must be integer)\n");
			return 0;
		}

		// There are signed and unsigned version of vector comparisons.
		// Rather than bake this into the instruction table (which would make
		// it much bigger and more complex for only 4 instructions), we 
		// do a special case check and conversion here.
		if (src1->type == TYPE_UNSIGNED_INT)
		{
			switch (opcode)
			{
				case 0x12:
					opcode = 0x16;
					break;
					
				case 0x13:
					opcode = 0x17;
					break;
					
				case 0x14:
					opcode = 0x18;
					break;
					
				case 0x15:
					opcode = 0x19;
					break;
			}
		}
	}
	else
	{
		// If one of the operands is a vector type, the destination will
		// be a vector type. Note that this only applies to 2-operand instructions.
		// For a single operand instruction, the destination may be either
		// type.
		if (src1 && dest->isVector != (src1->isVector | src2->isVector))
		{
			printAssembleError(currentSourceFile, lineno, "bad destination register type\n");
			return 0;
		}

		if (src1 && (src1->type == TYPE_FLOAT) != ((dest->type == TYPE_FLOAT) 
			^ isTypeConversion(operation)))
		{
			printAssembleError(currentSourceFile, lineno, "bad destination register type (float/int)\n");
			return 0;
		}
	}

	// Put everything together in the instruction and emit it.
	instruction = (mask->maskReg << 10)
		| (src2->index << 15)
		| (dest->index << 5)
		| (src1 ? src1->index : 0)
		| (fmt << 20)
		| (opcode << 23)
		| (6 << 29);
	addLineMapping(nextPc, lineno);
	emitLong(instruction);
	
	return 1;
}

int emitBInstruction(const struct RegisterInfo *dest, 
	const struct MaskInfo *mask, 
	const struct RegisterInfo *src1, 
	enum OpType operation, 
	int immediateOperand,
	int lineno)
{
	int fmt;
	int opcode;
	int instruction;

	fmt = bFormatTable[(src1->isVector << 2)
		| (mask->hasMask << 1)
		| mask->invertMask];
	if (fmt == -1)
	{
		printAssembleError(currentSourceFile, lineno, "invalid operand types\n");
		return 0;
	}

	if (operation == OP_SITOF)
	{
		// This form is a bit special, because the first argument is float
		// and the second is an int.
		opcode = 14;
		if (src1->type == TYPE_FLOAT)
		{
			printAssembleError(currentSourceFile, lineno, "invalid operand types\n");
			return 0;
		}
	}
	else if (operation == OP_SFTOI)
	{
		// Same as above except switched
		opcode = 13;
		if (src1->type != TYPE_FLOAT)
		{
			printAssembleError(currentSourceFile, lineno, "invalid operand types\n");
			return 0;
		}
	}
	else
	{
		if (dest->type == TYPE_FLOAT || src1->type == TYPE_FLOAT)
		{
			printAssembleError(currentSourceFile, lineno, "invalid operand types\n");
			return 0;
		}

		opcode = abOpcodeTable[operation][BINARY_INT];
		if (opcode == -1)
		{
			printAssembleError(currentSourceFile, lineno, "invalid operand types\n");
			return 0;
		}
	}

	// Special case for signed shifts (which shift in ones if the number is 
	// negative).
	if (operation == OP_SHR && src1->type == TYPE_UNSIGNED_INT)
		opcode = 10;

	// Check that destination type is correct (vector/scalar and float/int)
	if (isCompareOperation(operation))
	{
		// This is a comparison.  The destination will always be a scalar,
		// even if the operands are vector types
		if (dest->isVector)
		{
			printAssembleError(currentSourceFile, lineno, "bad destination register type (must be scalar)\n");
			return 0;
		}

		if (dest->type == TYPE_FLOAT)
		{
			printAssembleError(currentSourceFile, lineno, "bad destination register type (must be integer)\n");
			return 0;
		}

		// There are signed and unsigned version of vector comparisons.
		// Rather than bake this into the instruction table (which would make
		// it much bigger and more complex for only 4 instructions), we 
		// do a special case check and conversion here.
		if (src1->type == TYPE_UNSIGNED_INT)
		{
			switch (opcode)
			{
				case 0x12:
					opcode = 0x16;
					break;
					
				case 0x13:
					opcode = 0x17;
					break;
					
				case 0x14:
					opcode = 0x18;
					break;
					
				case 0x15:
					opcode = 0x19;
					break;
			}
		}
	}
	else
	{
		// If one of the operands is a vector type, the destination will
		// be a vector type.
		if (dest->isVector != src1->isVector)
		{
			printAssembleError(currentSourceFile, lineno, "bad destination register type\n");
			return 0;
		}

		if ((src1->type == TYPE_FLOAT) != ((dest->type == TYPE_FLOAT) 
			^ isTypeConversion(operation)))
		{
			printAssembleError(currentSourceFile, lineno, "bad destination register type (float/int)\n");
			return 0;
		}
	}

	if (immediateOperand & ~0x1ff)
	{
		printAssembleError(currentSourceFile, lineno, "immediate operand out of range\n");
		return 0;
	}

	instruction = (mask->maskReg << 10)
		| (immediateOperand << 15)
		| (dest->index << 5)
		| (src1->index)
		| (fmt << 24)
		| (opcode << 26);

	addLineMapping(nextPc, lineno);
	emitLong(instruction);

	return 1;
}

int emitPCRelativeBInstruction(const struct Symbol *sym,
	const struct RegisterInfo *dest,
	int lineno)
{
	const struct MaskInfo mask = {
		hasMask : 0,
		invertMask : 0,
		maskReg : 0
	};

	const struct RegisterInfo op1 = {
		index : PC_REG,	// PC
		isVector : 0,
		type : TYPE_UNSIGNED_INT
	};
	
	if (dest->isVector)
		printAssembleError(currentSourceFile, lineno, "bad destination register type");
	else
	{
		createFixup(sym, FU_PCREL_LOAD_ADDR, lineno);
		emitBInstruction(dest, &mask, &op1, OP_PLUS, 0, lineno);
	}
	
	return 1;
}

int emitCInstruction(const struct RegisterInfo *ptr,
	int offset,
	const struct RegisterInfo *srcDest,
	const struct MaskInfo *mask,
	int isLoad,
	int isStrided,
	enum MemoryAccessWidth width,
	int lineno)
{
	int instruction;
	int op;
	int maskOffset = 0;
	if (mask->hasMask)
	{
		if (mask->invertMask)
			maskOffset = 2;
		else
			maskOffset = 1;
	}

	if (ptr->isVector)
	{
		// Scatter gather access
		op = 0xc + maskOffset;
	}
	else if (srcDest->isVector)
	{
		// Block or strided vector access
		if (isStrided)
			op = 9 + maskOffset;
		else
			op = 6 + maskOffset;
	}
	else
	{
		if (isStrided)
		{
			printAssembleError(currentSourceFile, lineno, "invalid access mode: cannot do strided access with scalar destination\n");
			return 0;		
		}

		// Scalar access.  Need to consider width for this one.
		switch (width)
		{
			case MA_BYTE: 
				if (srcDest->type == TYPE_SIGNED_INT)
					op = 1;
				else
					op = 0;
				
				break;
			case MA_SHORT:		
				if (srcDest->type == TYPE_SIGNED_INT)
					op = 3;
				else
					op = 2;
			
				break;

			case MA_LONG:		
				op = 4; 
				break;
				
			case MA_LINKED:		
				op = 5; 
				break;
		}
	}

	if (offset & ~0x3ff)
	{
		printAssembleError(currentSourceFile, lineno, "immediate operand out of range\n");
		return 0;
	}

	instruction = (mask->maskReg << 10)
		| (offset << 15)
		| (srcDest->index << 5)
		| (ptr->index)
		| (op << 25)
		| (isLoad << 29)
		| (1 << 31);

	addLineMapping(nextPc, lineno);
	emitLong(instruction);
	
	return 1;
}

int emitPCRelativeCInstruction(const struct Symbol *destSym,
	const struct RegisterInfo *srcDest,
	const struct MaskInfo *mask,
	int isLoad,
	enum MemoryAccessWidth width,
	int lineno)
{
	const struct RegisterInfo ptr = {
		index : PC_REG,	// PC
		isVector : 0,
		type : TYPE_UNSIGNED_INT
	};

	createFixup(destSym, FU_PCREL_MEMACCESS, lineno);

	return emitCInstruction(&ptr,
		0,	// Offset, will be fixed up later
		srcDest,
		mask,
		isLoad,
		0,	// Is strided (no)
		width,
		lineno);
}


int emitEInstruction(const struct Symbol *destination,
	const struct RegisterInfo *testReg,
	enum BranchType type,
	int lineno)
{
	int opcode;

	createFixup(destination, FU_BRANCH, lineno);

	if (testReg == NULL && type != BRANCH_ALWAYS)
	{
		printAssembleError(currentSourceFile, lineno, "syntax error: expected condition register\n");
		return 0;
	}
		
	switch (type)
	{
		case BRANCH_ALL: opcode = 0; break;
		case BRANCH_ZERO: opcode = 1; break;
		case BRANCH_NOT_ZERO: opcode = 2; break;
		case BRANCH_ALWAYS: opcode = 3; break;
	}

	addLineMapping(nextPc, lineno);
	emitLong((opcode << 26) | (testReg ? testReg->index : 0) | (0xf << 28));
	return 1;
}

int emitLabel(int lineno, struct Symbol *sym)
{
	align(4);
	if (sym->defined)
	{
		printAssembleError(currentSourceFile, lineno, "redefined label %s\n", sym->name);
		return 0;
	}

	sym->defined = 1;
	sym->value = nextPc;
	
	return 1;
}

void emitLabelAddress(const struct Symbol *sym, int lineno)
{
	createFixup(sym, FU_LABEL_ADDRESS, lineno);
	emitLong(0);
}

int adjustFixups(void)
{
	struct Fixup *fu;
	int offset;
	
	for (fu = fixupList; fu; fu = fu->next)
	{
		if (!fu->sym->defined)
		{
			printAssembleError(fu->sourceFile, fu->lineno, "undefined symbol \"%s\"\n",
				fu->sym->name);
			return 0;
		}
		
		switch (fu->type)
		{
			case FU_BRANCH:
				offset = fu->sym->value - fu->programCounter - 4;
				codes[fu->programCounter / 4] |= swap32((offset & 0x1fffff) << 5);
				break;
				
			case FU_PCREL_MEMACCESS:
				offset = fu->sym->value - fu->programCounter - 4;
				if (offset > 0x1ff || offset < -0x1ff)
					printAssembleError(fu->sourceFile, fu->lineno, "pc relative access out of range\n");
				else
					codes[fu->programCounter / 4] |= swap32((offset & 0x3ff) << 15);

				break;

			case FU_PCREL_LOAD_ADDR:
				offset = fu->sym->value - fu->programCounter - 4;
				if (offset > 0xff || offset < -0xff)
					printAssembleError(fu->sourceFile, fu->lineno, "pc relative access out of range\n");
				else
					codes[fu->programCounter / 4] |= swap32((offset & 0x1ff) << 15);

				break;
				
			case FU_LABEL_ADDRESS:
				codes[fu->programCounter / 4] = swap32(fu->sym->value);
				break;

			default:
				printAssembleError(fu->sourceFile, fu->lineno, 
					"internal error, unknown fixup type %d\n", fu->type);
		}
	}

	return 1;
}

