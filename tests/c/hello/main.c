
void sort(int *array, int length)
{
	int x, y;
	
	for (x = 0; x < length - 1; x++)
	{
		for (y = x + 1; y < length; y++)
		{
			if (array[x] > array[y])
			{
				int temp = array[x];
				array[x] = array[y];
				array[y] = temp;
			}
		}
	}
}

int array[256];

int main()
{
	sort(array, sizeof(array));
	return 0;
}


