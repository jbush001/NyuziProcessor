
template <class T>
class List
{
public:
	List()
		:	fHead(0),
			fTail(0)
	{
	}
	
	bool empty() const
	{
		return fHead == 0;
	}
	
	void enqueue(const T &value)
	{
		if (fHead == 0)
			fHead = fTail = new ListNode;
		else
		{
			fTail->next = new ListNode;
			fTail = fTail->next;
		}

		fTail->next = 0;
		fTail->value = value;
	}
	
	T dequeue()
	{
		T retval = fHead->value;
		fHead = fHead->next;
		return retval;
	}

private:
	struct ListNode
	{
		ListNode *next;
		T value;
	};

	ListNode *fHead;
	ListNode *fTail;
};

unsigned int allocNext = 0x10000;

void *operator new(unsigned int size)
{
	void *ptr = (void*) allocNext;
	allocNext += size;
	return ptr;
}

void printChar(char c)
{
	*((volatile unsigned int*) 0xFFFF0004) = c;
}

int main()
{
	List<char> list;
	
	list.enqueue('a');
	list.enqueue('e');
	list.enqueue('i');
	list.enqueue('o');
	list.enqueue('u');

	while (!list.empty())
		printChar(list.dequeue());

	printChar('.');
	printChar('\n');
	return 0;
}
