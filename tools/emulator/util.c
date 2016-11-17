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

#include <assert.h>
#include <stdio.h>
#include "processor.h"
#include "util.h"

int parse_hex_vector(const char *str, uint32_t *vector_values, bool endian_swap)
{
    const char *c = str;
    int lane;
    int digit;
    uint32_t lane_value;

    for (lane = NUM_VECTOR_LANES - 1; lane >= 0 && *c; lane--)
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

uint8_t decode_hex_byte(const char *ptr)
{
    int i;
    int retval = 0;

    for (i = 0; i < 2; i++)
    {
        if (ptr[i] >= '0' && ptr[i] <= '9')
            retval = (retval << 4) | (ptr[i] - '0');
        else if (ptr[i] >= 'a' && ptr[i] <= 'f')
            retval = (retval << 4) | (ptr[i] - 'a' + 10);
        else if (ptr[i] >= 'A' && ptr[i] <= 'F')
            retval = (retval << 4) | (ptr[i] - 'A' + 10);
        else
            assert(0);	// Bad character
                        // XXX Shouldn't assert; return error.
    }

    return (uint8_t) retval;
}
