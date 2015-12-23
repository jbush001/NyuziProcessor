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
	const struct
	{
		int min;
		int max;
	} expected_ranges[] = {
		0, 0,		// PERF_L2_WRITEBACK
		2, 2,		// PERF_L2_MISS
		4, 4,		// PERF_L2_HIT
		0, 0,		// PERF_STORE_ROLLBACK
		5, 10,		// PERF_STORE
		80, 120,	// PERF_INSTRUCTION_RETIRED
		80, 120,	// PERF_INSTRUCTION_ISSUED
		0, 0,		// PERF_ICACHE_MISS
		200, 300,	// PERF_ICACHE_HIT
		0, 0,		// PERF_ITLB_MISS
		0, 0,		// PERF_DCACHE_MISS
		5, 20,		// PERF_DCACHE_HIT
		0, 0,		// PERF_DTLB_MISS
	};

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

	for (event = 0; event < NUM_EVENTS; event++)
	{
		if (perf_count[event] < expected_ranges[event].min || perf_count[event] > expected_ranges[event].max)
		{
			printf("Invalid counter %d: %d\n", event, perf_count[event]);
			exit(1);
		}
	}

	printf("PASS\n");

	return 0;
}
