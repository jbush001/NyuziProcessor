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
