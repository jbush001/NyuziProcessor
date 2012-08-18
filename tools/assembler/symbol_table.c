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

#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "symbol_table.h"

#define HASH_SIZE 57

struct Scope
{
	struct Scope *previous;
};

static struct Symbol *symbolHash[HASH_SIZE];
static struct Scope *currentScope;
static struct Scope *globalScope;

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
	struct Scope *scope;

	for (scope = currentScope; scope != NULL; scope = scope->previous)
	{
		for (symbol = symbolHash[bucket]; symbol; symbol = symbol->hashNext)
		{
			if (strcmp(symbol->name, name) == 0 && symbol->scope == scope)
				return symbol;
		}
	}

	return NULL;
}

struct Symbol *createSymbol(const char *name, int type, int value, int global)
{
	unsigned int bucket;
	struct Symbol *symbol;
	
	bucket = genhash(name) % HASH_SIZE;
	symbol = (struct Symbol*) calloc(sizeof(struct Symbol) + strlen(name), 1);
	symbol->hashNext = symbolHash[bucket];
	symbolHash[bucket] = symbol;
	symbol->type = type;
	symbol->defined = 0;
	strcpy(symbol->name, name);
	symbol->value = value;
	if (global)
		symbol->scope = globalScope;
	else
		symbol->scope = currentScope;

	return symbol;
}

void createGlobalRegisterAlias(const char *name, int index, int isVector, int type)
{
	struct Symbol *symbol = createSymbol(name, SYM_REGISTER_ALIAS, 0, 1);
	symbol->regInfo.index = index;
	symbol->regInfo.isVector = isVector;
	symbol->regInfo.type = type;
}

void enterScope(void)
{
	struct Scope *newScope = (struct Scope*) malloc(sizeof(struct Scope));
	newScope->previous = currentScope;
	currentScope = newScope;
	if (globalScope == NULL)
		globalScope = currentScope;
}

void exitScope(void)
{
	currentScope = currentScope->previous;
	assert(currentScope != NULL);
}

void dumpSymbolTable(void)
{
	int bucket;
	struct Symbol *symbol;

	for (bucket = 0; bucket < HASH_SIZE; bucket++)
	{
		for (symbol = symbolHash[bucket]; symbol; symbol = symbol->hashNext)
		{
			if (symbol->type != SYM_KEYWORD)
				printf(" %s %d %d %p\n", symbol->name, symbol->type, symbol->value, symbol->scope);
		}
	}
}
