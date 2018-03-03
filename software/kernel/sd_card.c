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

#include "libc.h"
#include "registers.h"
#include "sd_card.h"
#include "spinlock.h"
#include "trap.h"

#define MAX_RETRIES 100
#define DATA_TOKEN 0xfe
#define CHECK_PATTERN 0x5a

enum sd_command
{
    CMD_GO_IDLE_STATE = 0,
    CMD_SEND_OP_COND = 1,
    CMD_SEND_IF_COND = 8,
    CMD_SET_BLOCKLEN = 16,
    CMD_READ_SINGLE_BLOCK = 17,
    CMD_WRITE_SINGLE_BLOCK = 24,
    CMD_APP_OP_COND = 41,
    CMD_APP_CMD = 55
};

static spinlock_t sd_lock;

static void set_cs(int level)
{
    REGISTERS[REG_SD_SPI_CONTROL] = level;
}

static void set_clock_divisor(int divisor)
{
    REGISTERS[REG_SD_SPI_CLOCK_DIVIDE] = divisor - 1;
}

// Transfer a single byte bidirectionally.
static int spi_transfer(int value)
{
    REGISTERS[REG_SD_SPI_WRITE] = value & 0xff;
    while ((REGISTERS[REG_SD_SPI_STATUS] & 1) == 0)
        ;	// Wait for transfer to finish

    return REGISTERS[REG_SD_SPI_READ];
}

static int send_sd_command(enum sd_command command, unsigned int parameter)
{
    int result;
    int retry_count = 0;

    spi_transfer(0x40 | command);
    spi_transfer((parameter >> 24) & 0xff);
    spi_transfer((parameter >> 16) & 0xff);
    spi_transfer((parameter >> 8) & 0xff);
    spi_transfer(parameter & 0xff);
    spi_transfer(0x95);	// Checksum (ignored for all but first command)

    // Wait while card is busy
    do
    {
        result = spi_transfer(0xff);
    }
    while (result == 0xff && retry_count++ < MAX_RETRIES);

    return result;
}

int init_sd_device()
{
    int result;
    int retry;
    int i;

    // Set clock to 200k_hz (50Mhz system clock)
    set_clock_divisor(125);

    // After power on, send a bunch of clocks to initialize the chip
    set_cs(1);
    for (int i = 0; i < 10; i++)
        spi_transfer(0xff);

    set_cs(0);

    // Switch to SPI mode
    result = send_sd_command(CMD_GO_IDLE_STATE, 0);
    if (result != 1)
        return -1;

    result = send_sd_command(CMD_SEND_IF_COND, 0x100 | CHECK_PATTERN);
    if (result != 1)
        return -1;

    // Read remainder of R7 response (7.3.2.6)
    spi_transfer(0xff);
    spi_transfer(0xff);
    result = spi_transfer(0xff);
    if ((result & 0xf) != 1)
        return -1;

    if (spi_transfer(0xff) != CHECK_PATTERN)
        return -1;

    // Poll until it is ready
    for (retry = 0; ; retry++)
    {
        result = send_sd_command(CMD_APP_CMD, 0);
        if (result != 1)
            return -1;

        result = send_sd_command(CMD_APP_OP_COND, 0);

        // Read remainder of R3 response
        for (i = 0; i < 5; i++)
            spi_transfer(0xff);

        if (result == 0)
            break;

        if (result != 1)
            return -1;

        if (retry == MAX_RETRIES)
            return -1;
    }

    // Increase clock rate to 5 Mhz
    set_clock_divisor(5);

    return 0;
}

int read_sd_device(unsigned int block_address, void *ptr)
{
    int result;
    int old_flags;
    int data_timeout;

    old_flags = acquire_spinlock_int(&sd_lock);

    result = send_sd_command(CMD_READ_SINGLE_BLOCK, block_address);
    if (result != 0)
        return -1;

    // Wait for start of data packet
    data_timeout = 10000;
    while (spi_transfer(0xff) != DATA_TOKEN)
    {
        if (--data_timeout == 0)
            return -1;
    }

    for (int i = 0; i < BLOCK_SIZE; i++)
        ((char*) ptr)[i] = spi_transfer(0xff);

    // checksum (ignored)
    spi_transfer(0xff);
    spi_transfer(0xff);

    release_spinlock_int(&sd_lock, old_flags);

    return BLOCK_SIZE;
}
