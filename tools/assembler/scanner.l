%{
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
// Note: it seems like it should be as simple as just using yylineno
// from the parser, but, since we need to do lookahead for a number of rules,
// that would return the wrong line number in many cases.  Instead, we keep
// track of the line number on a per rule basis by adding a YY_USER_ACTION
// hook.
//

extern YYLTYPE yyloc;

#define YY_USER_ACTION yylloc.first_line = yylloc.last_line = yylineno; 
%}

%option yylineno
%option nounput

NUM							[0-9]
ALPHA						[A-Za-z]
ALPHANUM					[A-Za-z0-9]
HEXDIGIT					[A-Za-z0-9]

%%

;[^\r\n]*					{ /* Comment */ }
#[^\r\n]*					{ /* Comment */ }

[fiu]{NUM}+					{
								if (yytext[0] == 'f')
									yylval.reg.type = TYPE_FLOAT;
								else if (yytext[0] == 'u')
									yylval.reg.type = TYPE_UNSIGNED_INT;
								else
									yylval.reg.type = TYPE_SIGNED_INT;
								
								yylval.reg.isVector = 0;
								yylval.reg.index = atoi(yytext + 1);
								if (yylval.reg.index > 31)
								{
									printAssembleError(currentSourceFile, yylineno, 
										"invalid register %s\n", yytext);
								}
								
								return TOK_REGISTER; 
							}
[vs]{NUM}+					{
								yylval.reg.type = TYPE_SIGNED_INT;
								yylval.reg.isVector = (yytext[0] == 'v');
								yylval.reg.index = atoi(yytext + 1);
								if (yylval.reg.index > 31)
								{
									printAssembleError(currentSourceFile, yylineno, 
										"invalid register %s\n", yytext);
								}

								return TOK_REGISTER; 
							}
[vs][fiu]{NUM}+				{ 
								yylval.reg.isVector = (yytext[0] == 'v');
								if (yytext[1] == 'f')
									yylval.reg.type = TYPE_FLOAT;
								else if (yytext[1] == 'u')
									yylval.reg.type = TYPE_UNSIGNED_INT;
								else
									yylval.reg.type = TYPE_SIGNED_INT;

								yylval.reg.index = atoi(yytext + 2);
								if (yylval.reg.index > 31)
								{
									printAssembleError(currentSourceFile, yylineno, 
										"invalid register %s\n", yytext);
								}

								return TOK_REGISTER; 
							}
cr{NUM}+					{
								yylval.reg.isVector = 0;
								yylval.reg.index = atoi(yytext + 2);
								if (yylval.reg.index > 31)
								{
									printAssembleError(currentSourceFile, yylineno, 
										"invalid register %s\n", yytext);
								}

								return TOK_CONTROL_REGISTER; 
							}
"=="						{ return TOK_EQUAL_EQUAL; }
">="						{ return TOK_GREATER_EQUAL; }
"<="						{ return TOK_LESS_EQUAL; }
"<>"						{ return TOK_NOT_EQUAL; }
"<<"						{ return TOK_SHL; }
">>"						{ return TOK_SHR; }
[\(\)\{\}\~\=\,\[\]\+\-\*\/\&\|\^\<\>\!]	{ return yytext[0]; }
-?{NUM}+"."{NUM}+			{ 
								yylval.floatval = strtof(yytext, NULL);
								return TOK_FLOAT_LITERAL; 
							}
-?{NUM}+"."{NUM}+[Ee]-?{NUM}+ { 
								yylval.floatval = strtof(yytext, NULL);
								return TOK_FLOAT_LITERAL; 
							}
-?{NUM}+					{ 
								yylval.intval = atoi(yytext);
								return TOK_INTEGER_LITERAL; 
							}
0x{HEXDIGIT}+				{
								// Hexadecimal string
								yylval.intval = strtoul(yytext, NULL, 16);
								return TOK_INTEGER_LITERAL;
							}
mem_[bsl][x]?				{
								strcpy(yylval.str, yytext);
								return TOK_MEMORY_SPECIFIER;
							}
mem_sync					{
								strcpy(yylval.str, yytext);
								return TOK_MEMORY_SPECIFIER;
							}
if							{ return TOK_IF; }
goto						{ return TOK_GOTO; }
all							{ return TOK_ALL; }
call						{ return TOK_CALL; }
\"[^"]*\"					{
								strcpy(yylval.str, yytext + 1);
								yylval.str[strlen(yylval.str) - 1] = '\0';
								return TOK_LITERAL_STRING;
							}
nop							{ return TOK_NOP; }
dpreload					{ return TOK_DPRELOAD; }
dinvalidate					{ return TOK_DINVALIDATE; }
dflush						{ return TOK_DFLUSH; }
iinvalidate					{ return TOK_IINVALIDATE; }
stbar						{ return TOK_STBAR; }

[_A-Za-z][_A-Za-z0-9]*:		{
								struct Symbol *sym;
								char nocolon[256];
								size_t symlength;
								
								symlength = strlen(yytext);
								if (symlength >= sizeof(nocolon) - 1)
								{
									printAssembleError(currentSourceFile, yylineno, 
										"label is too long\n");
								}
								else
								{
									memcpy(nocolon, yytext, symlength - 1);
									nocolon[symlength - 1] = '\0';
									sym = lookupSymbol(nocolon);
									if (sym == NULL)
										sym = createSymbol(nocolon, SYM_LABEL, 0, 0);
									else if (sym->type != SYM_LABEL)
									{
										printAssembleError(currentSourceFile, yylineno, 
											"%s redefined as a label\n", nocolon);
									}
									
									yylval.sym = sym;
								}

								return TOK_LABELDEF; 
							}	


[@_A-Za-z][_A-Za-z0-9]*		{ 
								struct Symbol *sym;
								
								if (yytext[0] == '@')
								{
									// The @ symbol forces the symbol to be in
									// the global scope
									sym = lookupSymbol(yytext + 1);
									if (sym == NULL)
											sym = createSymbol(yytext + 1, SYM_LABEL, 0, 1);
								}
								else
								{
									sym = lookupSymbol(yytext);
									if (sym == NULL)
											sym = createSymbol(yytext, SYM_LABEL, 0, 0);
								}
								
								switch (sym->type)
								{
									case SYM_KEYWORD:
										yylval.sym = sym;
										return TOK_KEYWORD;

									case SYM_CONSTANT:
										yylval.sym = sym;
										return TOK_CONSTANT;
										
									case SYM_REGISTER_ALIAS:
										yylval.reg = sym->regInfo;
										return TOK_REGISTER; 
										
									default:
										yylval.sym = sym;
										return TOK_IDENTIFIER; 
								}
							}
							
\.word						{ return TOK_WORD; }
\.short						{ return TOK_SHORT; }
\.byte						{ return TOK_BYTE; }
\.float						{ return TOK_FLOAT; }
\.string					{ return TOK_STRING; }
\.align						{ return TOK_ALIGN; }
\.reserve					{ return TOK_RESERVE; }
\.regalias					{ return TOK_REG_ALIAS; }
\.enterscope				{ return TOK_ENTER_SCOPE; }
\.exitscope					{ return TOK_EXIT_SCOPE; }
[ \t\r\n]					{ }
