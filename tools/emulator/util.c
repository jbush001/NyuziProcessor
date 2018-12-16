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

#include <ctype.h>
#include <limits.h>
#include <stdio.h>
#include <sys/time.h>
#include <sys/types.h>
#include <time.h>
#include "processor.h"
#include "util.h"

static uint64_t random_state[2];

static inline uint32_t hex_digit_val(char ch) {
    if (ch >= '0' && ch <= '9')
        return (uint32_t) (ch - '0');
    else if (ch >= 'a' && ch <= 'f')
        return (uint32_t) (ch - 'a' + 10);
    else if (ch >= 'A' && ch <= 'F')
        return (uint32_t) (ch - 'A' + 10);
    else
        return UINT32_MAX;
}

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
            uint32_t digit_val = hex_digit_val(*c);
            if (digit_val == UINT32_MAX)
            {
                printf("bad character %c in hex vector\n", *c);
                return -1;
            }
            else
                lane_value = (lane_value << 4) | digit_val;

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

//
// Format is defined in IEEE 1364-2001, section 17.2.8
//
int read_hex_file(const char *filename, uint32_t *memory, uint32_t memory_size)
{
    FILE *file;
    int line_num = 1;
    uint32_t number_value;
    int push_back_char = -1;
    bool done = false;
    uint32_t address = 0;

    enum {
        SCAN_SPACE,
        SCAN_SLASH,
        SCAN_ADDRESS,
        SCAN_NUMBER,
        SCAN_MULTI_LINE_COMMENT,
        SCAN_ASTERISK,
        SCAN_SINGLE_LINE_COMMENT
    } state = SCAN_SPACE;

    file = fopen(filename, "r");
    if (file == NULL)
    {
        perror("load_hex_file: error opening hex file");
        return -1;
    }

    while (!done) {
        int ch;
        if (push_back_char != -1)
        {
            ch = push_back_char;
            push_back_char = -1;
        }
        else
            ch = fgetc(file);

        switch (state) {
            case SCAN_SPACE:
                if (ch == EOF)
                    done = true;
                else if (ch == '/')
                    state = SCAN_SLASH;
                else if (ch == '@')
                {
                    state = SCAN_ADDRESS;
                    number_value = 0;
                }
                else if (isxdigit(ch))
                {
                    number_value = hex_digit_val(ch);
                    state = SCAN_NUMBER;
                }
                else if (!isspace(ch))
                {
                    fprintf(stderr, "load_hex_file: Invalid character %c in line %d\n", ch, line_num);
                    fclose(file);
                    return -1;
                } else if (ch == '\n')
                    line_num++;

                break;

            case SCAN_SLASH:
                if (ch == '*')
                    state = SCAN_MULTI_LINE_COMMENT;
                else if (ch == '/')
                    state = SCAN_SINGLE_LINE_COMMENT;
                else
                {
                    fprintf(stderr, "load_hex_file: Invalid character %c in line %d\n", ch, line_num);
                    fclose(file);
                    return -1;
                }

                break;

            case SCAN_SINGLE_LINE_COMMENT:
                if (ch == '\n') {
                    state = SCAN_SPACE;
                } else if (ch == EOF) {
                    done = true;
                }

                break;

            case SCAN_MULTI_LINE_COMMENT:
                if (ch == '*')
                    state = SCAN_ASTERISK;
                else if (ch == EOF)
                {
                    fprintf(stderr, "load_hex_file: Missing */ at end of file\n");
                    fclose(file);
                    return -1;
                }

                break;

            case SCAN_ASTERISK:
                if (ch == '/')
                    state = SCAN_SPACE;
                else if (ch == EOF)
                {
                    fprintf(stderr, "load_hex_file: Missing */ at end of file\n");
                    fclose(file);
                    return -1;
                }

                break;

            case SCAN_NUMBER:
                if (isxdigit(ch))
                {
                    if ((number_value & 0xf0000000) != 0)
                    {
                        fprintf(stderr, "load_hex_file: number out of range in line %d\n", line_num);
                        fclose(file);
                        return -1;
                    }

                    number_value = (number_value << 4) | hex_digit_val(ch);
                }
                else
                {
                    if (address >= memory_size)
                    {
                        fprintf(stderr, "load_hex_file: hex file too big to fit in memory\n");
                        fclose(file);
                        return -1;
                    }

                    memory[address++] = endian_swap32(number_value);
                    push_back_char = ch;
                    state = SCAN_SPACE;
                }

                break;

            case SCAN_ADDRESS:
                if (isxdigit(ch))
                    number_value = (number_value << 4) | hex_digit_val(ch);
                else
                {
                    if (number_value >= memory_size)
                    {
                        fprintf(stderr, "load_hex_file: address out of range in line %d\n", line_num);
                        fclose(file);
                        return -1;
                    }

                    if (number_value % 4 != 0)
                    {
                        fprintf(stderr, "load_hex_file: address not aligned in line %d\n", line_num);
                        fclose(file);
                        return -1;
                    }

                    address = number_value / 4;
                    push_back_char = ch;
                    state = SCAN_SPACE;
                }

                break;
        }
    }

    fclose(file);
    return 0;
}
