#ifndef __SYMBOL_TABLE_H
#define __SYMBOL_TABLE_H

struct RegisterInfo
{
	int index;
	int isVector;
	enum 
	{
		TYPE_FLOAT,
		TYPE_SIGNED_INT,
		TYPE_UNSIGNED_INT
	} type;
};

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
	struct Scope *scope;
	char defined;
	int value;
	struct RegisterInfo regInfo;
	char name[1];
};

struct Symbol *lookupSymbol(const char *name);
struct Symbol *createSymbol(const char *name, int type, int value, int global);
void createGlobalRegisterAlias(const char *name, int index, int isVector, int type);
void enterScope(void);
void exitScope(void);
void dumpSymbolTable(void);

#endif
