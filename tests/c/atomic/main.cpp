
volatile int foo = 'a';

int main()
{
	*((unsigned int*) 0xFFFF0004) = __sync_fetch_and_add(&foo, 1);	// 'a'
	*((unsigned int*) 0xFFFF0004) = __sync_add_and_fetch(&foo, 1);	// 'c'
	*((unsigned int*) 0xFFFF0004) = __sync_add_and_fetch(&foo, 1);	// 'd'
	*((unsigned int*) 0xFFFF0004) = __sync_fetch_and_add(&foo, 1);	// 'd'

	return 0;
}
