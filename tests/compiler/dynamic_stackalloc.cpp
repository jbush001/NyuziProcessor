#include "cxx_runtime.h"
#include "output.h"

Output output;

int bar(char *buffer, int size)
{
	char tmp[size * 2];
	int index = 0;

	output << "enter bar\n";

	for (int i = 0; i < size; i++)
	{
		if (buffer[i] == 'i')
		{
			tmp[index++] = '~';
			tmp[index++] = 'i';
		}
		else
			tmp[index++] = buffer[i];
	}
	
	memcpy(buffer, tmp, index);
	return index;
}

int main()
{
	char foo[256] = "this is a test";
 
	int newLen = bar(foo, strlen(foo));
	for (int i = 0; i < newLen; i++)
		output << foo[i];

	// CHECK: th~is ~is a test
}