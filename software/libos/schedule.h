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

#ifndef __SCHEDULE_H
#define __SCHEDULE_H

typedef void (*ParallelFunc)(void *context, int x, int y, int z);

#ifdef __cplusplus
extern "C" {
#endif

// parallelSpawn should only be called from the main thread. It will wait for
// all jobs to complete before returning.
void parallelExecute(ParallelFunc func, void *context, int xDim, int yDim, int zDim);

#ifdef __cplusplus
}
#endif

#endif

