// 
// Copyright (C) 2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 

//
// Various runtime functions, which are just included in-line for simplicity
//

#include <stdlib.h>

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

namespace std {
	class bad_alloc {
	};
};

void *operator new(size_t size) throw(std::bad_alloc)
{
	return malloc(size);
}

void operator delete(void *ptr) throw()
{
	return free(ptr);
}

void *operator new[](size_t size) throw(std::bad_alloc)
{
	return malloc(size);
}

void operator delete[](void *ptr) throw()
{
	return free(ptr);
}

extern "C" void __cxa_atexit(void (*f)(void *), void *objptr, void *dso)
{
}

extern "C" void __cxa_pure_virtual()
{
	abort();
}

