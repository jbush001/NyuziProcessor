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
#include <sys/time.h>
#include <sys/types.h>
#include <time.h>
#include "processor.h"
#include "util.h"

static uint64_t random_state[2];

int parse_hex_vector(const char *str, uint32_t *vector_values, bool endian_swap)
{
    const char *c = str;
    int lane;
    int digit;
    uint32_t lane_value;

    for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
    {
        lane_value = 0;
        for (digit = 0; digit < 8; digit++)
        {
            if (*c >= '0' && *c <= '9')
                lane_value = (lane_value << 4) | (uint32_t) (*c - '0');
            else if (*c >= 'a' && *c <= 'f')
                lane_value = (lane_value << 4) | (uint32_t) (*c - 'a' + 10);
            else if (*c >= 'A' && *c <= 'F')
                lane_value = (lane_value << 4) | (uint32_t) (*c - 'A' + 10);
            else
            {
                printf("bad character %c in hex vector\n", *c);
                return -1;
            }

            if (*c == '\0')
            {
                printf("Error parsing hex vector\n");
                break;
            }
            else
                c++;
        }

        vector_values[lane] = endian_swap ? endian_swap32(lane_value) : lane_value;
    }

    return 0;
}

void seed_random(uint64_t value)
{
    int stir;

    random_state[0] = value;
    random_state[1] = value;
    for (stir = 0; stir < 5; stir++)
        next_random();
}

// xorshift128+ random number generator
// https://arxiv.org/abs/1404.0390
uint64_t next_random(void)
{
	uint64_t x = random_state[0];
	uint64_t const y = random_state[1];
	random_state[0] = y;
	x ^= x << 23;
	random_state[1] = x ^ y ^ (x >> 17) ^ (y >> 26);
	return random_state[1] + y;
}

uint64_t current_time_us(void)
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (uint64_t) tv.tv_sec * 1000000 + (uint64_t) tv.tv_usec;
}

