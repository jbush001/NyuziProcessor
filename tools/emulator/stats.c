// 
// Copyright (C) 2014 Jeff Bush
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
#include "stats.h"

static int64_t counters[MAX_STAT_TYPES];
int64_t __total_instructions;
#if LOG_INSTRUCTIONS
static const char *kNames[] = {
    "vector",
    "load",
    "store",
    "branch",
    "immediate arithmetic",
    "register arithmetic",
};
#endif
	
void __logInstruction(InstructionType type)
{
	counters[type]++;
}

void dumpInstructionStats()
{
#if LOG_INSTRUCTIONS
	int i;
#endif
	
	printf("%lld total instructions\n", __total_instructions);
#if LOG_INSTRUCTIONS
	for (i = 0; i < MAX_STAT_TYPES; i++)
	{
		printf("%s %lld %.4g%%\n", kNames[i], counters[i], 
			(double) counters[i] / __total_instructions * 100);
	}
#endif
}

