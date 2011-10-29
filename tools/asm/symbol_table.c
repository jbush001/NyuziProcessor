#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "symbol_table.h"

#define HASH_SIZE 57

struct Symbol *symbolHash[HASH_SIZE];

// FNV hash
unsigned int genhash(const char *string)
{
	const char *c;
	int hash = 2166136261U;

	for (c = string; *c; c++)
		hash = (hash ^ *c) * 16777619;

	return hash;
}

struct Symbol *lookupSymbol(const char *name)
{
	unsigned int bucket = genhash(name) % HASH_SIZE;
	struct Symbol *symbol;

	for (symbol = symbolHash[bucket]; symbol; symbol = symbol->hashNext)
	{
		if (strcmp(symbol->name, name) == 0)
			return symbol;
	}

	return NULL;
}

struct Symbol *createSymbol(const char *name, int type, int value)
{
	unsigned int bucket;
	struct Symbol *sym;
	
	bucket = genhash(name) % HASH_SIZE;
	sym = (struct Symbol*) calloc(sizeof(struct Symbol) + strlen(name), 1);
	sym->hashNext = symbolHash[bucket];
	symbolHash[bucket] = sym;
	sym->type = type;
	sym->defined = 0;
	strcpy(sym->name, name);
	sym->value = value;

	return sym;
}

void dumpSymbolTable(void)
{
	int bucket;
	struct Symbol *sym;

	for (bucket = 0; bucket < HASH_SIZE; bucket++)
	{
		for (sym = symbolHash[bucket]; sym; sym = sym->hashNext)
		{
			if (sym->type != SYM_KEYWORD)
				printf(" %s %d %d\n", sym->name, sym->type, sym->value);
		}
	
	}
}


