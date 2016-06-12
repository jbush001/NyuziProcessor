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
#include <fcntl.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include "device.h"
#include "sdmmc.h"

// Read only SD/MMC interface, SPI mode.
// https://www.sdcard.org/downloads/pls/part1_410.pdf

#define INIT_CLOCKS 80
#define SD_COMMAND_LENGTH 6

// Commands
enum sd_command
{
    CMD_GO_IDLE = 0x00,
    CMD_SEND_OP_COND = 0x01,
    CMD_SET_BLOCKLEN = 0x16,
    CMD_READ_SINGLE_BLOCK = 0x17
};

enum sd_state
{
    STATE_INIT_WAIT,
    STATE_IDLE,
    STATE_RECEIVE_COMMAND,
    STATE_WAIT_READ_RESPONSE,
    STATE_SEND_RESULT,
    STATE_DO_READ
};

static uint8_t *block_dev_data;
static uint32_t block_dev_size;
static int block_fd = -1;
static enum sd_state current_state;
static uint32_t chip_select;
static uint32_t state_delay;
static uint32_t read_offset;
static uint32_t block_length;
static uint8_t response_value;
static uint32_t init_clock_count;
static uint8_t command_result;
static uint32_t reset_delay;
static uint8_t current_command[SD_COMMAND_LENGTH];
static uint32_t current_command_length;
static bool is_ready = false;

int open_block_device(const char *filename)
{
    struct stat fs;
    if (block_fd != -1)
        return 0;	// Already open

    if (stat(filename, &fs) < 0)
    {
        perror("open_block_device: failed to stat block device file");
        return -1;
    }

    block_dev_size = (uint32_t) fs.st_size;
    block_fd = open(filename, O_RDONLY);
    if (block_fd < 0)
    {
        perror("open_block_device: failed to open block device file");
        return -1;
    }

    block_dev_data = mmap(NULL, block_dev_size, PROT_READ, MAP_SHARED, block_fd, 0);
    if (block_dev_data == NULL)
        return -1;

    printf("Loaded block device %d bytes\n", block_dev_size);
    return 0;
}

void close_block_device(void)
{
    assert(block_fd > 0);
    close(block_fd);
}

static uint32_t read_little_endian(const uint8_t *values)
{
    return (uint32_t)((values[0] << 24) | (values[1] << 16) | (values[2] << 8) | values[3]);
}

static void process_command(const uint8_t *command)
{
    switch (command[0] & 0x3f)
    {
        case CMD_GO_IDLE:
            // If a virtual block device wasn't specified, don't initialize
            if (block_dev_data)
            {
                is_ready = true;
                current_state = STATE_SEND_RESULT;
                command_result = 1;
            }

            break;

        case CMD_SEND_OP_COND:
            if (reset_delay)
            {
                command_result = 1;
                reset_delay--;
            }
            else
                command_result = 0;

            current_state = STATE_SEND_RESULT;
            break;

        case CMD_SET_BLOCKLEN:
            if (!is_ready)
            {
                printf("CMD_SET_BLOCKLEN: card not ready\n");
                exit(1);
            }

            block_length = read_little_endian(command + 1);
            current_state = STATE_SEND_RESULT;
            command_result = 0;
            break;

        case CMD_READ_SINGLE_BLOCK:
            if (!is_ready)
            {
                printf("CMD_READ_SINGLE_BLOCK: card not ready\n");
                exit(1);
            }

            read_offset = read_little_endian(command + 1) * block_length;
            current_state = STATE_WAIT_READ_RESPONSE;
            state_delay = rand() & 0xf;	// Wait a random amount of time
            response_value = 0;
            break;
    }
}

void write_sd_card_register(uint32_t address, uint32_t value)
{
    switch (address)
    {
        case REG_SD_WRITE_DATA:
            switch (current_state)
            {
                case STATE_INIT_WAIT:
                    init_clock_count += 8;
                    if (!chip_select && init_clock_count < INIT_CLOCKS)
                    {
                        printf("sdmmc error: command posted before card initialized 1\n");
                        exit(1);
                    }

                // Falls through

                case STATE_IDLE:
                    if (!chip_select && (value & 0xc0) == 0x40)
                    {
                        current_state = STATE_RECEIVE_COMMAND;
                        current_command[0] = value & 0xff;
                        current_command_length = 1;
                    }

                    break;

                case STATE_RECEIVE_COMMAND:
                    if (!chip_select)
                    {
                        current_command[current_command_length++] = value & 0xff;
                        if (current_command_length == SD_COMMAND_LENGTH)
                        {
                            process_command(current_command);
                            current_command_length = 0;
                        }
                    }

                    break;

                case STATE_SEND_RESULT:
                    response_value = command_result;
                    current_state = STATE_IDLE;
                    break;

                case STATE_WAIT_READ_RESPONSE:
                    if (state_delay == 0)
                    {
                        current_state = STATE_DO_READ;
                        response_value = 0;	// Signal ready
                        state_delay = block_length + 2;
                    }
                    else
                    {
                        state_delay--;
                        response_value = 0xff;	// Signal busy
                    }

                    break;

                case STATE_DO_READ:
                    // Ignore transmitted byte, put read byte in buffer
                    if (--state_delay < 2)
                        response_value = 0xff;	// Checksum
                    else if (read_offset < block_dev_size)
                        response_value = block_dev_data[read_offset++];
                    else
                        response_value = 0xff;

                    if (state_delay == 0)
                        current_state = STATE_IDLE;

                    break;
            }

            break;

        case REG_SD_CONTROL:
            chip_select = value & 1;
            break;

        default:
            assert("Should not be here" && 0);
    }
}

uint32_t read_sd_card_register(uint32_t address)
{
    switch (address)
    {
        case REG_SD_READ_DATA:
            return response_value;

        case REG_SD_STATUS:
            return 0x01;

        default:
            assert("Should not be here" && 0);
    }
}

