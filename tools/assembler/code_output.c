// 
// Copyright 2011-2012 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

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
		FU_PCREL_MEMACCESS_MASK,	// PC relative load address into register, masked
		FU_PCREL_MEMACCESS_NOMASK,	// PC relative load address into register, no mask
		FU_PCREL_COMPUTE_ADDR,     // PC relative load address into register
		FU_LABEL_ADDRESS	// Data, just the address of a label
	} type;
	int programCounter;
	const struct Symbol *sym;
	const char *sourceFile;
	int lineno;
};

struct LiteralPoolEntry
{
	struct LiteralPoolEntry *next;
	enum {
		LP_LABEL_ADDRESS,
		LP_CONSTANT
	} type;

	unsigned int referencePc;
	unsigned int constValue;
	const struct Symbol *label;
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

extern void printAssembleError(const char *filename, int lineno, const char *fmt, ...);

static unsigned int *codes;
static int codeAlloc;
static int nextPc = 0;
static struct Fixup *fixupList = NULL;
static struct LiteralPoolEntry *literalsHead = NULL;
static struct LiteralPoolEntry *literalsTail = NULL;
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

void reserve(int amt)
{
	nextPc += amt;
}

void ensure(int count)
{
	if (nextPc + count >= codeAlloc)
	{
		int newAlloc = ((nextPc + count + ALLOC_SIZE - 1) / ALLOC_SIZE)
			* ALLOC_SIZE;
		codes = realloc(codes, newAlloc);
		memset((char*) codes + codeAlloc, 0, newAlloc - codeAlloc);
		codeAlloc = newAlloc;
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

void emitNop(int lineno)
{
	addLineMapping(nextPc, lineno);
	emitLong(0);
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
// First array index is operation type (enum OpType).  This must stay in the same
// order as the enum.
// Second is type and count of parameters (enum ParamConfig)
int abOpcodeTable[][4] = {
	{ -1, 0, -1, -1 },	// OP_OR
	{ -1, 1, -1, -1 },	// OP_AND
	{ 2, -1, -1, -1 },	// OP_UMINUS
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
	{ -1, -1, -1, -1 },	// OP_FTOI *unused, we have a conditional to handle this*
	{ -1, -1, -1, -1 }, // OP_ITOF *unused, we have a conditional to handle this*
	{ -1, -1, 38, -1 }, // OP_FLOOR
	{ -1, -1, 39, -1 }, // OP_FRAC
	{ -1, -1, 28, -1 },	// OP_RECIP
	{ -1, -1, 41, -1 },	// OP_ABS
	{ -1, -1, 46, -1 },	// OP_SQRT
	{ -1, 13, -1, 13 }, // OP_SHUFFLE
	{ 15, 15, 15, 15 },	// OP_COPY  (note, this is internal.  Allowing all formats is a hack)
	{ 14, -1, -1, -1 },	// OP_CTZ
	{ -1, 26, -1, -1 }, // OP_GETLANE
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
// Index is made up of { dest type, op1 type, masked, invert mask }
// where type is 1 if it is a vector.  This returns the value of the
// format field for an B intruction.
//
int bFormatTable[] = {
	0,	 	// S S N N
	-1,		// S S N Y
	-1,		// S S Y N
	-1,		// S S Y Y
	1,		// S V N N  (Comparisons or getlane only)
	-1,		// S V N Y
	-1,		// S V Y N
	-1,		// S V Y Y
	4,		// V S N N
	-1,		// V S N Y
	5,		// V S Y N
	6,		// V S Y Y
	1,		// V V N N
	-1,		// V V N Y
	2,		// V V Y N
	3		// V V Y Y
};

// True if instruction translates between integer <-> float
int isTypeConversion(enum OpType operation)
{
	return operation == OP_FTOI || operation == OP_ITOF;
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

	if (operation == OP_FTOI)
	{
		// One float argument
		opcode = 27;
		if (src1 || !src2 || src2->type != TYPE_FLOAT)
		{
			printAssembleError(currentSourceFile, lineno, "invalid operand types\n");
			return 0;
		}
	}
	else if (operation == OP_ITOF)
	{
		// Special: the second argument is an int
		opcode = 42;
		if (src1 || !src2 || src2->type != TYPE_SIGNED_INT)
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
	else if (operation == OP_GETLANE)
	{
		if (dest->isVector)
		{
			printAssembleError(currentSourceFile, lineno, "bad destination register type (must be scalar)\n");
			return 0;
		}

		if (!src1->isVector)
		{
			printAssembleError(currentSourceFile, lineno, "first operand must be vector\n");
			return 0;
		}

		if (src2->isVector)
		{
			printAssembleError(currentSourceFile, lineno, "second operand must be scalar\n");
			return 0;
		}
		
		if (mask->hasMask)
		{
			printAssembleError(currentSourceFile, lineno, "mask not allowed\n");
			return 0;
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
		| (fmt << 26)
		| (opcode << 20)
		| (6 << 29);
	addLineMapping(nextPc, lineno);
	emitLong(instruction);
	
	// If this is an unconditional branch, we know the next line of code will not be
	// executed and we can safely insert a literal pool.
	if (dest->index == PC_REG && !dest->isVector)
		emitLiteralPoolValues(lineno);
	
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

	if (!dest->isVector && src1 && src1->isVector && !isCompareOperation(operation)
		&& operation != OP_GETLANE)
	{
		printAssembleError(currentSourceFile, lineno, "invalid operand types\n");
		return 0;
	}

	fmt = bFormatTable[(dest->isVector << 3)
		| (src1 ? src1->isVector << 2 : 0)
		| (mask->hasMask << 1)
		| mask->invertMask];
	if (fmt == -1)
	{
		printAssembleError(currentSourceFile, lineno, "invalid operand types\n");
		return 0;
	}

	// We perform assignments (even floating) by oring with zero, so check
	// for that here.
	if ((dest->type == TYPE_FLOAT || (src1 && src1->type == TYPE_FLOAT))
		&& (operation != OP_OR || immediateOperand != 0))
	{
		printAssembleError(currentSourceFile, lineno, "invalid operand types\n");
		return 0;
	}

	opcode = abOpcodeTable[operation][src1 ? BINARY_INT : UNARY_INT];
	if (opcode == -1)
	{
		printAssembleError(currentSourceFile, lineno, "invalid operand types\n");
		return 0;
	}

	// Special case for signed shifts (which shift in ones if the number is 
	// negative).
	if (operation == OP_SHR && (src1 && src1->type == TYPE_UNSIGNED_INT))
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
		if (src1 && src1->type == TYPE_UNSIGNED_INT)
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
	else if (operation == OP_GETLANE)
	{
		if (dest->isVector)
		{
			printAssembleError(currentSourceFile, lineno, "bad destination register type (must be scalar)\n");
			return 0;
		}

		if (!src1->isVector)
		{
			printAssembleError(currentSourceFile, lineno, "first operand must be vector\n");
			return 0;
		}

		if (mask->hasMask)
		{
			printAssembleError(currentSourceFile, lineno, "mask not allowed\n");
			return 0;
		}
	}
	else
	{
		if (src1 && (src1->type == TYPE_FLOAT) != ((dest->type == TYPE_FLOAT) 
			^ isTypeConversion(operation)))
		{
			printAssembleError(currentSourceFile, lineno, "bad destination register type (float/int)\n");
			return 0;
		}
	}

	instruction = (dest->index << 5)
		| (src1 ? src1->index : 0)
		| (fmt << 28)
		| (opcode << 23);
	
	if (mask->hasMask)
	{
		if ((immediateOperand > 0 && (immediateOperand & ~0x7f) != 0)
			|| (immediateOperand < 0 && (-immediateOperand & ~0x7f) != 0))
		{
			printAssembleError(currentSourceFile, lineno, "immediate operand out of range\n");
			return 0;
		}

		immediateOperand &= 0xff;	// Be sure to mask if this is negative
		instruction |= (mask->maskReg << 10) | (immediateOperand << 15);
	}
	else
	{
		if ((immediateOperand > 0 && (immediateOperand & ~0xfff) != 0)
			|| (immediateOperand < 0 && (-immediateOperand & ~0xfff) != 0))
		{
			printAssembleError(currentSourceFile, lineno, "immediate operand out of range\n");
			return 0;
		}

		// If there is no mask, we use the mask register field as part of
		// the immediate field
		immediateOperand &= 0x1fff;	// Be sure to mask if this is negative
		instruction |= (immediateOperand << 10);
	}

	addLineMapping(nextPc, lineno);
	emitLong(instruction);

	// If this is an unconditional branch, we know the next line of code will not be
	// executed and we can safely insert a literal pool.
	if (dest->index == PC_REG && !dest->isVector)
		emitLiteralPoolValues(lineno);

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
		createFixup(sym, FU_PCREL_COMPUTE_ADDR, lineno);
		emitBInstruction(dest, &mask, &op1, OP_PLUS, 0, lineno);
	}

	// If this is an unconditional branch, we know the next line of code will not be
	// executed and we can safely insert a literal pool.
	if (dest->index == PC_REG && !dest->isVector)
		emitLiteralPoolValues(lineno);
	
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
	if (mask && mask->hasMask)
	{
		if (width == MA_CONTROL)
		{
			printAssembleError(currentSourceFile, lineno, "mask is not allowed with this expression type\n");
			return 0;		
		}
	
		if (mask->invertMask)
			maskOffset = 2;
		else
			maskOffset = 1;
	}

	if (width == MA_CONTROL && (ptr->isVector || srcDest->isVector))
	{
		printAssembleError(currentSourceFile, lineno, "Control register transfer can only use scalar register\n");
		return 0;		
	}

	if (ptr->isVector)
	{
		// Scatter gather access
		op = 0xd + maskOffset;
	}
	else if (srcDest->isVector)
	{
		// Block or strided vector access
		if (isStrided)
			op = 10 + maskOffset;
		else
			op = 7 + maskOffset;
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
				
			case MA_SYNC:		
				op = 5; 
				break;
				
			case MA_CONTROL:
				op = 6;
				break;
				
			default:
				printAssembleError(currentSourceFile, lineno, "Internal assembler error: unknown width %d\n",
					width);
		}
	}

	if (width == MA_SHORT)
		offset /= 2;
	else if (width != MA_BYTE)
		offset /= 4;

	instruction = (mask && mask->hasMask ? mask->maskReg << 10 : 0)
		| (srcDest->index << 5)
		| (ptr->index)
		| (op << 25)
		| (isLoad << 29)
		| (1 << 31);

	if (mask && mask->hasMask)
	{
		if ((offset > 0 && (offset & ~0x1ff) != 0)
			|| (offset < 0 && (-offset & ~0x1ff) != 0))
		{
			printAssembleError(currentSourceFile, lineno, "immediate operand out of range\n");
			return 0;
		}
	
		offset &= 0x3ff;
		instruction |= (offset << 15);
	}
	else
	{
		if ((offset > 0 && (offset & ~0x3fff) != 0)
			|| (offset < 0 && (-offset & ~0x3fff) != 0))
		{
			printAssembleError(currentSourceFile, lineno, "immediate operand out of range\n");
			return 0;
		}
	
		offset &= 0x7fff;
		instruction |= (offset << 10);
	}

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

	if (width == MA_BYTE || width == MA_SHORT)
	{
		// ...not because of any inherent instruction limitation, but because I was too lazy
		// to implement the fixup types.
		printAssembleError(currentSourceFile, lineno, "Cannot support PC relative addressing with non 32-bit loads");
		return 0;
	}

	createFixup(destSym, mask && mask->hasMask ? FU_PCREL_MEMACCESS_MASK 
		: FU_PCREL_MEMACCESS_NOMASK, lineno);

	return emitCInstruction(&ptr,
		0,	// Offset, will be fixed up later
		srcDest,
		mask,
		isLoad,
		0,	// Is strided (no)
		width,
		lineno);
}

struct LiteralPoolEntry *emitLiteralPoolRef(const struct RegisterInfo *dest, int lineno)
{
	const struct RegisterInfo ptr = {
		index : PC_REG,	// PC
		isVector : 0,
		type : TYPE_UNSIGNED_INT
	};

	struct LiteralPoolEntry *entry = (struct LiteralPoolEntry*) calloc(
		sizeof(struct LiteralPoolEntry), 1);
	if (literalsHead == NULL)
		literalsHead = literalsTail = entry;
	else
	{
		literalsTail->next = entry;
		literalsTail = entry;
	}
	
	entry->sourceFile = currentSourceFile;
	entry->lineno = lineno;
	entry->referencePc = nextPc;

	emitCInstruction(&ptr,
		0,	// Offset, will be fixed up later
		dest,
		NULL,	// Mask (none)
		1,	// Is load
		0,	// Is strided (no)
		MA_LONG,
		lineno);
		
	return entry;
}

int emitLiteralPoolLabelRef(const struct RegisterInfo *dest,
	const struct Symbol *label, int lineno)
{
	struct LiteralPoolEntry *entry = emitLiteralPoolRef(dest, lineno);
	entry->type = LP_LABEL_ADDRESS;
	entry->label = label;

	return 1;
}

int emitLiteralPoolConstRef(const struct RegisterInfo *dest,
	unsigned int constValue, int lineno)
{
	struct LiteralPoolEntry *entry = emitLiteralPoolRef(dest, lineno);
	entry->type = LP_CONSTANT;
	entry->constValue = constValue;

	return 1;
}

int emitLiteralPoolValues(int lineno)
{
	struct LiteralPoolEntry *entry;
	unsigned int tableIndex = 0;
	unsigned int offset;
	int success = 1;
	
	while (literalsHead)
	{
		entry = literalsHead;
		literalsHead = entry->next;

		// Fixup the original load offset to point to the constant pool.
		offset = nextPc - entry->referencePc - 4;
		if (offset > 0x1ff)
		{
			printAssembleError(currentSourceFile, lineno, "literal pool too far away from reference\n");
			success = 0;
		}
		else
		{
			// Fixup type C opcode.  This will always have a wide offset, since it
			// is a scalar load.
			codes[entry->referencePc / 4] |= swap32(((offset / 4) & 0x7fff) << 10);
		}
		
		switch (entry->type)
		{
			case LP_LABEL_ADDRESS:
				// This will create another fixup for the label
				emitLabelAddress(entry->label, entry->lineno);
				break;
			
			case LP_CONSTANT:
				emitLong(entry->constValue);
				break;
				
			default:
				assert(0);
		}

		free(entry);
		tableIndex++;
	}

	literalsTail = NULL;
	return success;
}

int emitDInstruction(enum CacheControlOp op,
	const struct RegisterInfo *ptr,
	int offset,
	int lineno)
{
	unsigned int instruction = 0xe0000000 | (op << 25);

	if (ptr != NULL)
	{
		if (ptr->isVector || ptr->type == TYPE_FLOAT)
			printAssembleError(currentSourceFile, lineno, "Bad register type for cache control operation\n");
		else
			instruction |= ptr->index;
	}

	if ((offset > 0 && (offset & ~0x1ff) != 0)
		|| (offset < 0 && (-offset & ~0x1ff) != 0))
	{
		printAssembleError(currentSourceFile, lineno, "offset out of range\n");
		return 0;
	}

	instruction |= offset << 15;

	addLineMapping(nextPc, lineno);
	emitLong(instruction);
	
	return 1;
}

int emitEInstruction(const struct Symbol *destination,
	const struct RegisterInfo *testReg,
	enum BranchType type,
	int lineno)
{
	int opcode;

	if (destination)
		createFixup(destination, FU_BRANCH, lineno);

	if (testReg == NULL && type != BRANCH_ALWAYS && type != BRANCH_CALL_OFFSET)
	{
		printAssembleError(currentSourceFile, lineno, "syntax error: expected condition register\n");
		return 0;
	}
		
	switch (type)
	{
		case BRANCH_ALL: opcode = 0; break;
		case BRANCH_NOT_ALL: opcode = 5; break;
		case BRANCH_ZERO: opcode = 1; break;
		case BRANCH_NOT_ZERO: opcode = 2; break;
		case BRANCH_ALWAYS: opcode = 3; break;
		case BRANCH_CALL_OFFSET: opcode = 4; break;
		case BRANCH_CALL_REGISTER: opcode = 6; break;
	}

	addLineMapping(nextPc, lineno);
	emitLong((opcode << 25) | (testReg ? testReg->index : 0) | (0xf << 28));

	// If this is an unconditional branch, we know the next line of code will not be
	// executed and we can safely insert a literal pool.
	if (type == BRANCH_ALWAYS)
		emitLiteralPoolValues(lineno);

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
	int success = 1;
	
	if (literalsHead != NULL)
	{
		printAssembleError(literalsHead->sourceFile, literalsHead->lineno, 
			"literal table never emitted\n");
		success = 0;
	}
	
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
				codes[fu->programCounter / 4] |= swap32((offset & 0xfffff) << 5);
				break;
				
			case FU_PCREL_MEMACCESS_MASK:
				offset = fu->sym->value - fu->programCounter - 4;
				if (offset > 0x1ff || offset < -0x1ff)
				{
					printAssembleError(fu->sourceFile, fu->lineno, "pc relative access out of range\n");
					success = 0;
				}
				else
					codes[fu->programCounter / 4] |= swap32(((offset / 4) & 0x3ff) << 15);

				break;

			case FU_PCREL_MEMACCESS_NOMASK:
				offset = fu->sym->value - fu->programCounter - 4;
				if (offset > 0x3fff || offset < -0x3fff)
				{
					printAssembleError(fu->sourceFile, fu->lineno, "pc relative access out of range\n");
					success = 0;
				}
				else
					codes[fu->programCounter / 4] |= swap32(((offset / 4) & 0x7fff) << 10);

				break;

			case FU_PCREL_COMPUTE_ADDR:
				offset = fu->sym->value - fu->programCounter - 4;
				if (offset > 0x1fff || offset < -0x1fff)
				{
					printAssembleError(fu->sourceFile, fu->lineno, "pc relative access out of range\n");
					success = 0;
				}
				else
					codes[fu->programCounter / 4] |= swap32((offset & 0x1fff) << 10);

				break;
				
			case FU_LABEL_ADDRESS:
				codes[fu->programCounter / 4] = swap32(fu->sym->value);
				break;

			default:
				printAssembleError(fu->sourceFile, fu->lineno, 
					"internal error, unknown fixup type %d\n", fu->type);
				success = 0;
		}
	}

	return success;
}

static int countBits(unsigned int value)
{
	int count;
	
	for (count = 0; value; count++)
		value &= value - 1;
		
	return count;
}

void saveRegs(unsigned int bitmask, int lineno)
{
	int index;
	int totalRegs;
	const struct MaskInfo mask = { 0, 0, 0 };
	const struct RegisterInfo spreg = { 29, 0, 2 };
	struct RegisterInfo reg = { 0, 0, 2 };

	if (bitmask & ((1 << 29) | (1 << 31)))
	{
		printAssembleError(currentSourceFile, lineno, "cannot put SP or PC in save list\n");
		return;
	}

	totalRegs = countBits(bitmask);

	// sp = sp - (num regs * 4)
	emitBInstruction(&spreg, &mask, &spreg, OP_MINUS, totalRegs * 4, lineno);
	
	int offset = 0;
	for (index = 0; index < 32; index++)
	{
		if (bitmask & (1 << index))
		{
			reg.index = index;
			emitCInstruction(&spreg, offset, &reg, &mask, 0, 0, MA_LONG, lineno);
			offset += 4;
		}
	}
}

void restoreRegs(unsigned int bitmask, int lineno)
{
	const struct RegisterInfo spreg = { 29, 0, 2 };
	const struct MaskInfo mask = { 0, 0, 0 };
	struct RegisterInfo reg = { 0, 0, 2 };
	int index;

	if (bitmask & ((1 << 29) | (1 << 31)))
	{
		printAssembleError(currentSourceFile, lineno, "cannot put SP or PC in restore list\n");
		return;
	}

	int offset = 0;
	for (index = 0; index < 32; index++)
	{
		if (bitmask & (1 << index))
		{
			reg.index = index;
			emitCInstruction(&spreg, offset, &reg, &mask, 1, 0, MA_LONG, lineno);
			offset += 4;
		}
	}

	// sp = sp + (num regs * 4)
	emitBInstruction(&spreg, &mask, &spreg, OP_PLUS, offset, lineno);
}
