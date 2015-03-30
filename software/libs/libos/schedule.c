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

	while (gCurrentIndex != gMaxIndex)
		dispatchJob();
	
	while (gActiveJobs)
		; // Wait for threads to finish
}

void workerThread()
{
	while (1)
	{
		while (gCurrentIndex == gMaxIndex)
			;
		
		__sync_fetch_and_add(&gActiveJobs, 1);
		dispatchJob();
		__sync_fetch_and_add(&gActiveJobs, -1);
	}
}

