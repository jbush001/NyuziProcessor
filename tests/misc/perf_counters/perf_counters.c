//
// Copyright 2015 Jeff Bush
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
#include <performance_counters.h>

//
// Check performance counters to ensure they basically look correct
//

#define NUM_EVENTS 13
#define CHECK(cond) if (!(cond)) { printf("TEST FAILED: %s:%d: %s\n", __FILE__, __LINE__, \
	#cond); abort(); }

int do_stuff(int *values, int count) __attribute__((noinline))
{
	int i;
	int result = 0;

	for (i = 0; i < count; i++)
		result += values[i];

	return result;
}

int main(int argc, const char *argv[])
{
	int base_event;
	int counter;
	int event;
	int perf_count[NUM_EVENTS];
	int values[] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

	for (base_event = 0; base_event < NUM_EVENTS; base_event += NUM_COUNTERS)
	{
		for (counter = 0; counter < NUM_COUNTERS && base_event + counter < NUM_EVENTS; counter++)
		{
			set_perf_counter_event(counter, base_event + counter);
			perf_count[base_event + counter] = read_perf_counter(counter);
		}

		do_stuff(values, 10);

		for (counter = 0; counter < NUM_COUNTERS && base_event + counter < NUM_EVENTS; counter++)
			perf_count[base_event + counter] = read_perf_counter(counter) - perf_count[base_event + counter];
	}

	// CHeck some basic invariants
	CHECK(perf_count[PERF_STORE_ROLLBACK] < perf_count[PERF_STORE]);
	CHECK(perf_count[PERF_ICACHE_HIT] >= perf_count[PERF_INSTRUCTION_ISSUED]);
	CHECK(perf_count[PERF_INSTRUCTION_ISSUED] <= perf_count[PERF_INSTRUCTION_RETIRED]);

	// Chat that values seem to be in the proper range
	CHECK(perf_count[PERF_L2_WRITEBACK] == 0);
	CHECK(perf_count[PERF_L2_MISS] < 10);
	CHECK(perf_count[PERF_L2_HIT] > 0 && perf_count[PERF_L2_HIT] < 10);
	CHECK(perf_count[PERF_STORE_ROLLBACK] < 10);
	CHECK(perf_count[PERF_STORE] < 10);
	CHECK(perf_count[PERF_ICACHE_HIT] > 0);
	CHECK(perf_count[PERF_INSTRUCTION_ISSUED] > 0);
	CHECK(perf_count[PERF_INSTRUCTION_RETIRED] > 0);

	// MMU not enabled, these must be zero
	CHECK(perf_count[PERF_DTLB_MISS] == 0);
	CHECK(perf_count[PERF_ITLB_MISS] == 0);

	printf("PASS\n");

	return 0;
}
