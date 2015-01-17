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

#include <stdio.h>
#include "schedule.h"

static ParallelFunc gCurrentFunc;
static int gXDim;
static int gYDim;
static int gZDim;
static volatile int gCurrentIndex;
static volatile int gMaxIndex;
static volatile int gActiveJobs;
static void * volatile gContext;

static int dispatchJob()
{
	int thisIndex;
	int x, y, z;

	do
	{
		thisIndex = gCurrentIndex;
		if (thisIndex == gMaxIndex)
			return 0;	// No more jobs in this batch
	}
	while (!__sync_bool_compare_and_swap(&gCurrentIndex, thisIndex, thisIndex + 1));

	x = thisIndex % gXDim;
	thisIndex /= gXDim;
	y = thisIndex % gYDim;
	thisIndex /= gYDim;
	z = thisIndex;

	gCurrentFunc(gContext, x, y, z);

	return 1;
}

void parallelExecute(ParallelFunc func, void *context, int xDim, int yDim, int zDim)
{
	gCurrentFunc = func;
	gContext = context;
	gXDim = xDim;
	gYDim = yDim;
	gZDim = zDim;
	gCurrentIndex = 0;
	gMaxIndex = xDim * yDim * zDim;	
	__builtin_nyuzi_write_control_reg(30, 0xffffffff);	// Start all threads

	while (gCurrentIndex != gMaxIndex)
		dispatchJob();
	
	while (gActiveJobs)
		; // Wait for threads to finish
}

void workerThread()
{
	// This starts other threads in a multicore environment
	__builtin_nyuzi_write_control_reg(30, 0xffffffff);
	
	while (1)
	{
		while (gCurrentIndex == gMaxIndex)
			;
		
		__sync_fetch_and_add(&gActiveJobs, 1);
		dispatchJob();
		__sync_fetch_and_add(&gActiveJobs, -1);
	}
}

