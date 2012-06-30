#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <getopt.h>

#define OP_SHUFFLE 13
#define OP_SFTOI 48
#define OP_SITOF 42

struct ABOpInfo
{
	int isInfix;		// If 1, the format is R op R, otherwise it is op(R)
	int numArgs;
	int isFloat;
	const char *name;
} abOpcodeTable[] = {
	{ 1, 2, 0, "|" },	// 0
	{ 1, 2, 0, "&" }, 	// 1
	{ 1, 1, 0, "-" }, // 2
	{ 1, 2, 0, "^" },	// 3
	{ 1, 1, 0, "~" },	// 4
	{ 1, 2, 0, "+" }, 	// 5
	{ 1, 2, 0, "-" },	// 6
	{ 1, 2, 0, "*" },	// 7
	{ 1, 2, 0, "/" },	// 8
	{ 1, 2, 0, ">>" },	// 9	(signed)
	{ 1, 2, 0, ">>" },	// 10 	(unsigned) 
	{ 1, 2, 0, "<<" }, 	// 11
	{ 0, 1, 0, "clz" },	// 12
	{ 0, 2, 0, "shuffle" },// 13
	{ 0, 1, 0, "ctz" },// 14
	{ 1, 1, 0, "" },	// 15 (copy)
	{ 1, 2, 0, "==" },	// 16
	{ 1, 2, 0, "<>" },	// 17
	{ 1, 2, 0, ">" },	// 18 (signed)
	{ 1, 2, 0, ">=" },	// 19
	{ 1, 2, 0, "<" },	// 20
	{ 1, 2, 0, "<=" },	// 21
	{ 1, 2, 0, ">" },	// 22  (unsigned)
	{ 1, 2, 0, ">=" },	// 23
	{ 1, 2, 0, "<" },	//24
	{ 1, 2, 0, "<=" },	// 25
	{ 0, 0, 0, "" }, // 26
	{ 0, 0, 0, "" }, // 27
	{ 0, 0, 0, "" }, // 28
	{ 0, 0, 0, "" }, // 29
	{ 0, 0, 0, "" }, // 30
	{ 0, 0, 0, "" }, // 31
	{ 1, 2, 1, "+" },	// 32
	{ 1, 2, 1, "-" },	// 33
	{ 1, 2, 1, "*" },	// 34
	{ 1, 2, 1, "/" },	// 35
	{ 0, 0, 0, "" },
	{ 0, 0, 0, "" },
	{ 0, 1, 1, "floor" },// 38
	{ 0, 1, 1, "frac" },// 39
	{ 0, 1, 1, "reciprocal" },// 40
	{ 0, 1, 1, "abs" },	// 41
	{ 0, 2, 1, "sitof" },// 42
	{ 0, 0, 0, "" },
	{ 1, 2, 1, ">" },	// 44
	{ 1, 2, 1, ">=" },	// 45
	{ 1, 2, 1, "<" },	// 46
	{ 1, 2, 1, "<=" },	// 47
	{ 0, 2, 1, "sftoi" },// 48
};

struct AFmtInfo
{
	int op1IsScalar;
	int op2IsScalar;
	int masked;
	int invertMask;
} aFormatTab[] = {
	{ 1, 1, 0, 0 },
	{ 0, 1, 0, 0 },
	{ 0, 1, 1, 0 },
	{ 0, 1, 1, 1 },
	{ 0, 0, 0, 0 },
	{ 0, 0, 1, 0 },
	{ 0, 0, 1, 1 },
	{ 0, 0, 0, 0 }
};

struct BFmtInfo
{
	int destIsScalar;
	int op1IsScalar;
	int masked;
	int invertMask;
} bFormatTab[] = {
	{ 1, 1, 0, 0 },
	{ 0, 0, 0, 0 },
	{ 0, 0, 1, 0 },
	{ 0, 0, 1, 1 },
	{ 0, 1, 0, 0 },
	{ 0, 1, 1, 0 },
	{ 0, 1, 1, 1 },
	{ 0, 0, 0, 0 },
};

int isCompareInstruction(int opcode)
{
	return (opcode >= 16 && opcode <= 26)
		|| (opcode >= 44 && opcode <= 47);
}

void disassembleAOp(unsigned int instr)
{
	int opcode = (instr >> 23) & 0x3f;
	const struct ABOpInfo *opInfo = &abOpcodeTable[opcode];
	const struct AFmtInfo *fmtInfo = &aFormatTab[(instr >> 20) & 7];
	char vecSpec;
	char typeSpec;
	char optype;
	int isCompare = isCompareInstruction(opcode);
	
	if (isCompare)
	{
		vecSpec = 's';
		typeSpec = 'i';	
	}
	else
	{
		vecSpec = fmtInfo->op1IsScalar ? 's' : 'v';
		typeSpec = opInfo->isFloat && opcode != OP_SFTOI ? 'f' : 'i';
	}
	
	printf("%c%c%d", vecSpec, typeSpec, (instr >> 5) & 0x1f);

	if (fmtInfo->masked && !isCompare)
	{
		printf("{");
		if (fmtInfo->invertMask)
			printf("~");
			
		printf("si%d}", (instr >> 10) & 0x1f);
	}
	
	printf(" = ");
	if (opInfo->isInfix)
	{
		if (opInfo->numArgs == 1)
		{
			printf("%s %c%c%d\n", opInfo->name, 
				fmtInfo->op2IsScalar ? 's' : 'v',
				opInfo->isFloat ? 'f' : 'i',
				(instr >> 15) & 0x1f);
		}
		else
		{
			if ((opcode >= 22 && opcode <= 25) || (opcode == 10))
				optype = 'u';	// special case for unsigned compares and shifts
			else if (opInfo->isFloat)
				optype = 'f';
			else
				optype = 'i';

			printf("%c%c%d %s %c%c%d\n", 
				fmtInfo->op1IsScalar ? 's' : 'v',
				optype,
				instr & 0x1f,
				opInfo->name, 
				fmtInfo->op2IsScalar ? 's' : 'v',
				optype,
				(instr >> 15) & 0x1f);
		}
	}
	else
	{
		if (opInfo->numArgs == 1)
		{
			printf("%s(%c%c%d)\n", opInfo->name, 
				fmtInfo->op2IsScalar ? 's' : 'v',
				opInfo->isFloat ? 'f' : 'i',
				(instr >> 15) & 0x1f);
		}
		else
		{
			int op2IsScalar = opcode == OP_SHUFFLE ? 0 : fmtInfo->op2IsScalar;
		
			// NOTE: we explicitly check for sftoi and sitof, which
			// have odd parameter types (since they are type conversions)
			printf("%s(%c%c%d, %c%c%d)\n", 
				opInfo->name, 
				fmtInfo->op1IsScalar ? 's' : 'v',
				(opcode != OP_SITOF && opInfo->isFloat) ? 'f' : 'i',
				instr & 0x1f,
				op2IsScalar ? 's' : 'v',
				(opInfo->isFloat) ? 'f' : 'i',
				(instr >> 15) & 0x1f);
		}
	}
}

void disassembleBOp(unsigned int instr)
{
	int opcode = (instr >> 26) & 0x1f;
	const struct ABOpInfo *opInfo = &abOpcodeTable[opcode];
	const struct BFmtInfo *fmtInfo = &bFormatTab[(instr >> 23) & 7];
	char vecSpec;
	int immValue;
	char optype;
	int isCompare = isCompareInstruction(opcode);
	int isUnsigned = (opcode >= 22 && opcode <= 25) || (opcode == 10);

	if (isCompare)
		vecSpec = 's';
	else
		vecSpec = fmtInfo->destIsScalar ? 's' : 'v';
	
	printf("%c%c%d", vecSpec, opcode == OP_SITOF ? 'f' : 'i', (instr >> 5) & 0x1f);

	if (fmtInfo->masked && !isCompare)
	{
		printf("{");
		if (fmtInfo->invertMask)
			printf("~");
			
		printf("si%d}", (instr >> 10) & 0x1f);
	}
	
	printf(" = ");

	if (fmtInfo->masked && !isCompare)
	{
		immValue = (instr >> 15) & 0xff;
		if (immValue & 0x80)
			immValue |= 0xffffff00;	// Sign extend
	}
	else
	{
		immValue = (instr >> 10) & 0x1fff;
		if (immValue & 0x1000)
			immValue |= 0xffffe000;	// Sign extend
	}

	// Assume two ops: one op B instructions are not allowed
	if (opInfo->isInfix)
	{
		if (opcode == 0 && immValue == 0)
		{
			// OP_COPY
			printf("%c%c%d", 
				fmtInfo->op1IsScalar ? 's' : 'v',
				opInfo->isFloat ? 'f' : 'i',
				instr & 0x1f);
		}
		else if (opcode == 15)
		{
			// Transfer
			printf("%d", immValue);
		}
		else
		{
			if (isUnsigned)
				optype = 'u';	// special case for unsigned compares and shifts
			else if (opInfo->isFloat)
				optype = 'f';
			else
				optype = 'i';

			printf("%c%c%d %s ", 
				fmtInfo->op1IsScalar ? 's' : 'v',
				optype,
				instr & 0x1f,
				opInfo->name);
				
			if (isUnsigned)
				printf("%d", immValue);
			else
				printf("%i", immValue);
		}
	}
	else
	{
		printf("%s(%c%c%d, %d)", 
			opInfo->name, 
			fmtInfo->op1IsScalar ? 's' : 'v',
			(opcode != OP_SITOF && opInfo->isFloat) ? 'f' : 'i',
			instr & 0x1f,
			immValue);
	}

	printf("\n");
}

const char *memSuffixes[] = {
	"b",
	"b",
	"s",
	"s",
	"l",
	"sync"
};

struct CFmtInfo
{
	enum
	{
		SCALAR,
		BLOCK,
		STRIDED,
		SCATTER_GATHER
	} accessType;
	int masked;
	int invertMask;
} cFormatTab[] = {
	{ SCALAR, 0, 0 },
	{ SCALAR, 0, 0 },
	{ SCALAR, 0, 0 },
	{ SCALAR, 0, 0 },
	{ SCALAR, 0, 0 },
	{ SCALAR, 0, 0 },
	{ SCALAR, 0, 0 },
	{ BLOCK, 0, 0 },
	{ BLOCK, 1, 0 },
	{ BLOCK, 1, 1 },
	{ STRIDED, 0, 0 },
	{ STRIDED, 1, 0 },
	{ STRIDED, 1, 1 },
	{ SCATTER_GATHER, 0, 0 },
	{ SCATTER_GATHER, 1, 0 },
	{ SCATTER_GATHER, 1, 1 }
};

void printMemRef(const struct CFmtInfo *fmtInfo,
	int offset,
	int ptrReg,
	int op)
{
	switch (fmtInfo->accessType)
	{
		case SCALAR:
			// Scalar
			printf("mem_%s[si%d", memSuffixes[op], ptrReg);
			if (offset != 0)
				printf(" + %d", offset);
				
			break;

		case BLOCK:
			printf("mem_l[si%d", ptrReg);
			if (offset != 0)
				printf(" + %d", offset);
			
			break;
		
		case STRIDED:
			printf("mem_l[si%d", ptrReg);
			if (offset != 0)
				printf(", %d", offset);
				
			break;
		
		case SCATTER_GATHER:
			printf("mem_l[vi%d", ptrReg);
			if (offset != 0)
				printf(" + %d", offset);

			break;
			
		default:
			break;
	}
	
	printf("]");
}

void printMemMask(const struct CFmtInfo *fmtInfo, int instr)
{
	if (fmtInfo->masked)
	{
		printf("{");
		if (fmtInfo->invertMask)
			printf("~");
			
		printf("si%d}", (instr >> 10) & 0x1f);
	}
}

void disassembleCOp(unsigned int instr)
{
	const struct CFmtInfo *fmtInfo = &cFormatTab[(instr >> 25) & 0xf];
	int op = (instr >> 25) & 0xf;
	int offset = (instr >> 15) & 0x3ff;
	int ptrReg = instr & 0x1f;
	int srcDest = (instr >> 5) & 0x1f;
	int isLoad = (instr >> 29) & 1;
	
	if (offset & 0x200)
		offset |= 0xfffffc00;	//  Sign extend

	if (op == 6)
	{
		// Control register move
		if (isLoad)
			printf("s%d = cr%d\n", srcDest, ptrReg);
		else
			printf("cr%d = s%d\n", ptrReg, srcDest);
	
		return;
	}

	if (isLoad)
	{
		// Load
		if (fmtInfo->accessType == SCALAR)
		{
			if (op == 1 || op == 3)
				printf("si%d = ", srcDest);	// Sign extend
			else
				printf("su%d = ", srcDest);	// Unsigned
		}
		else
		{
			printf("v%d", srcDest);
			printMemMask(fmtInfo, instr);
			printf(" = ");
		}

		printMemRef(fmtInfo, offset, ptrReg, op);
	}
	else
	{
		// Store
		printMemRef(fmtInfo, offset, ptrReg, op);
		if (fmtInfo->accessType == SCALAR)
			printf(" = s%d", srcDest);
		else
		{
			printMemMask(fmtInfo, instr);
			printf(" = v%d", srcDest);
		}
	}
	
	printf("\n");
}

void disassembleDOp(unsigned int address, unsigned int instr)
{
	int type = (instr >> 25) & 7;
	int offset = (instr >> 15) & 0x3ff;
	if (offset & 0x200)
		offset |= 0xfffffc00;	//  Sign extend

	switch (type)
	{
		case 0: 
			printf("dpreload");
			break;

		case 1:
			printf("dinvalidate");
			break;

		case 2:
			printf("dflush");
			break;

		case 3:
			printf("iinvalidate");
			break;

		case 4:
			printf("barrier");
			break;

		default:
			printf("???");
			break;
	}
	
	if (type != 4)
	{
		printf("(s%d", instr & 0x1f);
		if (offset != 0)
			printf(" + %d",offset);
			
		printf(")");
	}
	
	printf("\n");
}

void disassembleEOp(unsigned int address, unsigned int instr)
{
	int offset = (instr >> 5) & 0xfffff;
	int sourceReg = instr & 0x1f;
	if (offset & 0x80000)
		offset |= 0xfff00000;	// Sign extend

	unsigned int target = address + 4 + offset;
	switch ((instr >> 25) & 7)
	{
		case 0:
			printf("if all(si%d) goto %08x\n", sourceReg, target);
			break;
		case 1:
			printf("if !si%d goto %08x\n", sourceReg, target);
			break;
		case 2:
			printf("if si%d goto %08x\n", sourceReg, target);
			break;
		case 3:
			printf("goto %08x\n", target);
			break;
		case 4:
			printf("call %08x\n", target);
			break;
		case 5:
			printf("if !all(si%d) goto %08x\n", sourceReg, target);
			break;
		default:
			printf("bad branch type %d\n", (instr >> 25) & 7);
			break;
	}
}

void disassemble(int showAddresses, unsigned int address, unsigned int instr)
{
	if (showAddresses)
		printf("%08x %08x ", address, instr);

	if (instr == 0)
		printf("nop\n");
	else if ((instr & 0xe0000000) == 0xc0000000)
		disassembleAOp(instr);
	else if ((instr & 0x80000000) == 0)
		disassembleBOp(instr);
	else if ((instr & 0xc0000000) == 0x80000000)
		disassembleCOp(instr);
	else if ((instr & 0xf0000000) == 0xe0000000)
		disassembleDOp(address, instr);
	else if ((instr & 0xf0000000) == 0xf0000000)
		disassembleEOp(address, instr);
	else
		printf("Unknown instruction\n");
}

unsigned int swap(unsigned int value)
{
	return ((value & 0x000000ff) << 24)
		| ((value & 0x0000ff00) << 8)
		| ((value & 0x00ff0000) >> 8)
		| ((value & 0xff000000) >> 24);
}

int main(int argc, char *argv[])
{
	FILE *file;
	char line[64];
	unsigned int instr;
	int c;
	unsigned int address = 0;
	int showAddresses = 0;
	
	while ((c = getopt(argc, argv, "a")) != -1)
	{
		switch (c)
		{
			case 'a':
				showAddresses = 1;
				break;
		}
	}

	if (optind == argc)
	{
		fprintf(stderr, "No source files\n");
		return 1;
	}

	file = fopen(argv[optind], "r");
	if (file == NULL)
	{
		perror("Error opening file");
		return 1;
	}

	while (fgets(line, sizeof(line), file))
	{
		instr = swap(strtoul(line, NULL, 16));
		disassemble(showAddresses, address, instr);	
		address += 4;
	}
	
	fclose(file);
	return 0;
}
