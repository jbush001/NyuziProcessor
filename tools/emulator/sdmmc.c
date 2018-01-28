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
#include "util.h"

// SD/MMC interface, SPI mode.
// hhttp://elm-chan.org/docs/mmc/mmc_e.html

#define INIT_CLOCKS 80
#define SD_COMMAND_LENGTH 6
#define DATA_TOKEN 0xfe

// Commands
enum sd_command
{
    CMD_GO_IDLE = 0x00,
    CMD_SEND_OP_COND = 0x01,
    CMD_SET_BLOCKLEN = 0x16,
    CMD_READ_SINGLE_BLOCK = 0x17,
    CMD_WRITE_SINGLE_BLOCK = 0x24
};

enum sd_state
{
    STATE_INIT_WAIT,
    STATE_IDLE,
    STATE_RECEIVE_COMMAND,
    STATE_READ_CMD_RESPONSE,
    STATE_READ_DATA_TOKEN,
    STATE_SEND_RESULT,
    STATE_READ_TRANSFER,
    STATE_WRITE_CMD_RESPONSE,
    STATE_WRITE_DATA_TOKEN,
    STATE_WRITE_TRANSFER,
    STATE_WRITE_DATA_RESPONSE
};

static uint32_t block_dev_size;
static int block_fd = -1;
static enum sd_state current_state;
static uint32_t chip_select;
static uint32_t state_delay;
static uint32_t transfer_block_address;
static uint32_t transfer_count;
static uint32_t block_length;
static uint8_t response_value;
static uint32_t init_clock_count;
static uint32_t reset_delay;
static uint8_t current_command[SD_COMMAND_LENGTH];
static uint32_t current_command_length;
static bool is_ready = false;
static char *block_buffer;

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
    block_fd = open(filename, O_RDWR);
    if (block_fd < 0)
    {
        perror("open_block_device: failed to open block device file");
        return -1;
    }

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
            if (block_fd > 0)
            {
                is_ready = true;
                current_state = STATE_SEND_RESULT;
                response_value = 1;
            }

            break;

        case CMD_SEND_OP_COND:
            if (reset_delay)
            {
                response_value = 1;
                reset_delay--;
            }
            else
                response_value = 0;

            current_state = STATE_SEND_RESULT;
            break;

        case CMD_SET_BLOCKLEN:
            if (!is_ready)
            {
                printf("CMD_SET_BLOCKLEN: card not ready\n");
                exit(1);
            }

            block_length = read_little_endian(command + 1);
            block_buffer = realloc(block_buffer, block_length);
            current_state = STATE_SEND_RESULT;
            response_value = 0;
            break;

        case CMD_READ_SINGLE_BLOCK:
            if (!is_ready)
            {
                printf("CMD_READ_SINGLE_BLOCK: card not ready\n");
                exit(1);
            }

            transfer_block_address = read_little_endian(command + 1) * block_length;
            if (lseek(block_fd, transfer_block_address, SEEK_SET) < 0)
            {
                perror("CMD_READ_SINGLE_BLOCK: seek failed");
                exit(1);
            }

            if (read(block_fd, block_buffer, block_length) != block_length)
            {
                printf("read failed for block\n");
                exit(1);
            }

            transfer_count = 0;
            current_state = STATE_READ_CMD_RESPONSE;
            state_delay = next_random() & 0xf; // Wait a random amount of time
            response_value = 0; // command response
            break;

        case CMD_WRITE_SINGLE_BLOCK:
            if (!is_ready)
            {
                printf("CMD_READ_SINGLE_BLOCK: card not ready\n");
                exit(1);
            }

            transfer_block_address = read_little_endian(command + 1) * block_length;
            transfer_count = 0;
            current_state = STATE_WRITE_CMD_RESPONSE;
            state_delay = next_random() & 0xf; // Wait a random amount of time
            response_value = 0; // Command response
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

                    response_value = 0xff;  // Ready
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
                    current_state = STATE_IDLE;
                    break;

                case STATE_READ_CMD_RESPONSE:
                    if (state_delay == 0)
                    {
                        current_state = STATE_READ_DATA_TOKEN;
                        response_value = 0;	// Signal ready
                        state_delay = next_random() & 0xf;
                    }
                    else
                    {
                        state_delay--;
                        response_value = 0xff;	// Signal busy
                    }

                    break;

                case STATE_READ_DATA_TOKEN:
                    if (state_delay == 0)
                    {
                        current_state = STATE_READ_TRANSFER;
                        response_value = DATA_TOKEN; // Send data token to start block
                        state_delay = block_length + 2;
                    }
                    else
                    {
                        state_delay--;
                        response_value = 0xff;	// Busy
                    }

                    break;

                case STATE_READ_TRANSFER:
                    // Ignore transmitted byte, put read byte in buffer
                    if (--state_delay < 2)
                        response_value = 0xff;	// Checksum
                    else
                        response_value = block_buffer[transfer_count++];

                    if (state_delay == 0)
                        current_state = STATE_IDLE;

                    break;

                case STATE_WRITE_CMD_RESPONSE:
                    if (state_delay == 0)
                    {
                        current_state = STATE_WRITE_DATA_TOKEN;
                        response_value = 0;	// Signal ready
                        state_delay = block_length + 2;
                    }
                    else
                    {
                        state_delay--;
                        response_value = 0xff;	// Signal busy
                    }

                    break;

                case STATE_WRITE_DATA_TOKEN:
                    // Wait until we see the data token
                    if (value == DATA_TOKEN)
                        current_state = STATE_WRITE_TRANSFER;

                    break;

                case STATE_WRITE_TRANSFER:
                    if (--state_delay >= 2 && transfer_block_address < block_dev_size)
                        block_buffer[transfer_count++] = value & 0xff;

                    if (state_delay == 0)
                    {
                        assert(transfer_count == block_length);
                        current_state = STATE_WRITE_DATA_RESPONSE;
                    }

                    break;

                case STATE_WRITE_DATA_RESPONSE:
                    current_state = STATE_IDLE;
                    response_value = 0x05;  // Data accepted

                    if (lseek(block_fd, transfer_block_address, SEEK_SET) < 0)
                    {
                        perror("CMD_READ_SINGLE_BLOCK: seek failed");
                        exit(1);
                    }

                    if (write(block_fd, block_buffer, block_length) != block_length)
                    {
                        printf("write failed for block\n");
                        exit(1);
                    }

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

