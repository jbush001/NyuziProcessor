
%{
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
[_A-Za-z][_A-Za-z0-9]* 		{ 
								struct Symbol *sym = lookupSymbol(yytext);
								if (sym == NULL)
									sym = createSymbol(yytext, SYM_LABEL, 0);
								
								switch (sym->type)
								{
									case SYM_KEYWORD:
										yylval.sym = sym;
										return TOK_KEYWORD;

									case SYM_CONSTANT:
										yylval.sym = sym;
										return TOK_CONSTANT;
										
									case SYM_REGISTER_ALIAS:
										yylval.reg.type = TYPE_UNSIGNED_INT;
										yylval.reg.isVector = 0;
										yylval.reg.index = sym->value;
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
[ \t\r\n]					{ }
