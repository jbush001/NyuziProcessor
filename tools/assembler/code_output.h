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
// Handles encoding instructions and writing them to the output file.
//

#ifndef __CODE_OUTPUT_H
#define __CODE_OUTPUT_H

#include "symbol_table.h"

enum OpType
{
	OP_OR,
	OP_AND,
	OP_UMINUS,
	OP_XOR,
	OP_NOT,
	OP_PLUS,
	OP_MINUS,
	OP_MULTIPLY,
	OP_DIVIDE,
	OP_SHR,
	OP_SHL,
	OP_CLZ,
	OP_EQUAL,
	OP_NOT_EQUAL,
	OP_GREATER,
	OP_GREATER_EQUAL,
	OP_LESS,
	OP_LESS_EQUAL,
	OP_FTOI,
	OP_SITOF,
	OP_FLOOR,
	OP_FRAC,
	OP_RECIP,
	OP_ABS,
	OP_SQRT,
	OP_SHUFFLE,
	OP_COPY,
	OP_CTZ,
	OP_GETLANE
};

enum BranchType
{
	BRANCH_ALL,
	BRANCH_NOT_ALL,
	BRANCH_ZERO,
	BRANCH_NOT_ZERO,
	BRANCH_ALWAYS,
	BRANCH_CALL_OFFSET,
	BRANCH_CALL_REGISTER
};

enum MemoryAccessWidth 
{
	MA_BYTE,
	MA_SHORT,
	MA_LONG,
	MA_SYNC,
	MA_CONTROL
};

enum CacheControlOp
{
	CC_DPRELOAD,
	CC_DINVALIDATE,
	CC_DFLUSH,
	CC_IINVALIDATE,
	CC_STBAR
};

struct MaskInfo
{
	int hasMask;
	int invertMask;
	int maskReg;
};

int openOutputFile(const char *file);
void closeOutputFile();

void codeOutputSetSourceFile(const char *filename);

// All of these functoins returns 1 if successful, 0 if the format was invalid.
int emitAInstruction(const struct RegisterInfo *dest, 
	const struct MaskInfo *mask, 
	const struct RegisterInfo *src1, 
	enum OpType operation, 
	const struct RegisterInfo *src2,
	int lineno);

int emitBInstruction(const struct RegisterInfo *dest, 
	const struct MaskInfo *mask, 
	const struct RegisterInfo *src1, 
	enum OpType operation, 
	int immediateOperand,
	int lineno);
	
int emitPCRelativeBInstruction(const struct Symbol *sym,
	const struct RegisterInfo *dest,
	int lineno); 

int emitCInstruction(const struct RegisterInfo *ptr,
	int offset,
	const struct RegisterInfo *srcDest,
	const struct MaskInfo *mask,
	int isLoad,
	int isStrided,
	enum MemoryAccessWidth width,
	int lineno); 

int emitPCRelativeCInstruction(const struct Symbol *destSym,
	const struct RegisterInfo *srcDest,
	const struct MaskInfo *mask,
	int isLoad,
	enum MemoryAccessWidth width,
	int lineno); 

int emitDInstruction(enum CacheControlOp op,
	const struct RegisterInfo *ptr,
	int offset,
	int lineno);

int emitEInstruction(const struct Symbol *destination,
	const struct RegisterInfo *testReg,
	enum BranchType type,
	int lineno);

int emitLabel(int lineno, struct Symbol *sym);
void emitLong(unsigned int value);
void emitShort(unsigned int value);
void emitByte(unsigned int value);
void emitNop(int lineno);
void align(int alignment);
void reserve(int amt);
void emitLabelAddress(const struct Symbol *sym, int lineno);
int adjustFixups(void);

#endif
