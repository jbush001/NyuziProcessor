// 
// Copyright (C) 2011-2014 Jeff Bush
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


#ifndef __SPINLOCK_H
#define __SPINLOCK_H

namespace runtime
{

class Spinlock
{
public:
	Spinlock()
		:	fFlag(0)
	{}
	
	void acquire()
	{
		while (fFlag != 0 || __sync_fetch_and_or(&fFlag, 1) != 0)
			;
	}
	
	void release()
	{
		fFlag = 0;
		__sync_synchronize();
	}

private:
	volatile int fFlag;
};

}

#endif
