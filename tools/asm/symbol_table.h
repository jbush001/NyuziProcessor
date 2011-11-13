#ifndef __SYMBOL_TABLE_H
#define __SYMBOL_TABLE_H

struct Symbol
{
	enum
	{
		SYM_KEYWORD,
		SYM_LABEL,
		SYM_CONSTANT,
		SYM_REGISTER_ALIAS
	} type;
	struct Symbol *hashNext;
	int defined;
	int value;
	char name[1];
};

struct Symbol *lookupSymbol(const char *name);
struct Symbol *createSymbol(const char *name, int type, int value);
void dumpSymbolTable(void);

#endif
