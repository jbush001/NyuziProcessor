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


#include <libc.h>

//
// Various runtime functions, which are just included in-line for simplicity
//

namespace __cxxabiv1
{
	class __class_type_info
	{
	public:
		__class_type_info() {}
		virtual ~__class_type_info() {}
	};

	class __si_class_type_info
	{
	public:
		__si_class_type_info() {}
		virtual ~__si_class_type_info() {}
	};

	__class_type_info cti;
	__si_class_type_info sicti;
}   

void *__dso_handle;
unsigned int allocNext = 0x10000;

extern "C"  {
	void __cxa_atexit(void (*f)(void *), void *objptr, void *dso);
	void __cxa_pure_virtual();
}

namespace std {
	class bad_alloc {
	};
};

void *operator new(unsigned int size) throw (std::bad_alloc)
{
	void *ptr = (void*) allocNext;
	allocNext += size;
	return ptr;
}

void operator delete(void *ptr) throw()
{
}

void __cxa_atexit(void (*f)(void *), void *objptr, void *dso)
{
}

void __cxa_pure_virtual()
{
}

void *calloc(unsigned int size, int count)
{
	int totalSize = size * count;

	void *ptr = (void*) allocNext;
	allocNext += totalSize;
	memset(ptr, 0, totalSize);
	
	return ptr;
}

