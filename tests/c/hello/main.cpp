
void printstr(const char *string)
{	
	for (const char *c = string; *c; c++)
		*((unsigned*) 0xFFFF0004) = *c;
}

int main()
{
	printstr("Hello World\n");
	return 0;
}
