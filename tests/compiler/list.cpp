// 
// Copyright 2011-2015 Jeff Bush
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


#include <stdio.h>

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

int main()
{
	List<char> list;
	
	list.enqueue('a');
	list.enqueue('e');
	list.enqueue('i');
	list.enqueue('o');
	list.enqueue('u');
	

	while (!list.empty())
		printf("%c", list.dequeue());

	printf(".\n");

	// CHECK: aeiou.

	return 0;
}
