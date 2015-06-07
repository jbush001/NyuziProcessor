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

