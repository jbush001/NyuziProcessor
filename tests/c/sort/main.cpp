
void sort(char *array, int length)
{
	for (int i = 0; i < length - 1; i++)
	{
		for (int j = i + 1; j < length; j++)
		{
			if (array[i] > array[j])
			{
				char tmp = array[i];
				array[i] = array[j];
				array[j] = tmp;
			}
		}	
	}
}

int main()
{
	char tmp[11] = "atjlnpqdgs";
	sort(tmp, 10);

	for (int i = 0; i < 10; i++)
		*((volatile unsigned int*) 0xFFFF0004) = tmp[i];

	*((volatile unsigned int*) 0xFFFF0004) = '\n';
	return 0;
}
