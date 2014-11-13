// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
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
