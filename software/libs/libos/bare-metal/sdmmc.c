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
#include "registers.h"
#include "sdmmc.h"

// SPI mode SDMMC driver.
// https://www.sdcard.org/downloads/pls/pdf/index.php?p=Part1_Physical_Layer_Simplified_Specification_Ver6.00.jpg

#define MAX_RETRIES 100
#define DATA_TOKEN 0xfe
#define CHECK_PATTERN 0x5a

typedef enum
{
    CMD_GO_IDLE_STATE = 0,
    CMD_SEND_OP_COND = 1,
    CMD_SEND_IF_COND = 8,
    CMD_SET_BLOCKLEN = 16,
    CMD_READ_SINGLE_BLOCK = 17,
    CMD_WRITE_SINGLE_BLOCK = 24,
    CMD_APP_OP_COND = 41,
    CMD_APP_CMD = 55
} SDCommand;

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

static int send_sd_command(SDCommand command, unsigned int parameter)
{
    int result;
    int retry_count = 0;

    spi_transfer(0x40 | command);
    spi_transfer((parameter >> 24) & 0xff);
    spi_transfer((parameter >> 16) & 0xff);
    spi_transfer((parameter >> 8) & 0xff);
    spi_transfer(parameter & 0xff);
    spi_transfer(0x95);	// Checksum (ignored for all but first command)

    // Read first byte of response. 0xff indicates the card is busy.
    do
    {
        result = spi_transfer(0xff);
    }
    while (result == 0xff && retry_count++ < MAX_RETRIES);

    return result;
}

int init_sdmmc_device(void)
{
    int result;
    int i;
    int retry;

    // Set clock to 200kHz (50Mhz system clock)
    set_clock_divisor(125);

    // After power on, need to send at least 74 clocks with DI and CS high
    // per the spec to initialize (10 bytes is 80 clocks).
    set_cs(1);
    for (int i = 0; i < 10; i++)
        spi_transfer(0xff);

    // Reset the card and enter SPI mode by sending CMD0 with CS low.
    set_cs(0);
    result = send_sd_command(CMD_GO_IDLE_STATE, 0);

    // The card should have returned 01 to indicate it is in SPI mode.
    if (result != 1)
    {
        if (result == 0xff)
            printf("init_sdmmc_device: timed out during reset\n");
        else
            printf("init_sdmmc_device: CMD_GO_IDLE_STATE failed: invalid response %02x\n", result);

        return -1;
    }

    // 4.2.2 It is mandatory to issue CMD8 prior to first ACMD41 for
    // initialization of High Capacity SD Memory Card.
    result = send_sd_command(CMD_SEND_IF_COND, 0x100 | CHECK_PATTERN); // 3.6v
    if (result != 1)
    {
        printf("CMD_SEND_IF_COND: invalid response %02x\n", result);
        return -1;
    }

    // Read remainder of R7 response (7.3.2.6)
    spi_transfer(0xff);
    spi_transfer(0xff);
    result = spi_transfer(0xff);
    if ((result & 0xf) != 1)
    {
        printf("error: unsupported voltage range %02x\n", result);
        return -1;
    }

    if (spi_transfer(0xff) != CHECK_PATTERN)
    {
        printf("error: R7 check pattern mismatch\n");
        return -1;
    }

    for (retry = 0; ; retry++)
    {
        result = send_sd_command(CMD_APP_CMD, 0);
        if (result != 1)
        {
            printf("CMD_APP_CMD: invalid response %02x\n", result);
            return -1;
        }

        result = send_sd_command(CMD_APP_OP_COND, 0);

        // Read remainder of R3 response
        for (i = 0; i < 5; i++)
            spi_transfer(0xff);

        if (result == 0)
            break;

        if (result != 1)
        {
            printf("CMD_APP_OP_COND: invalid response %02x\n", result);
            return -1;
        }

        if (retry == MAX_RETRIES)
        {
            printf("CMD_APP_OP_COND: timed out\n");
            return -1;
        }
    }

    // Increase clock rate to 5 Mhz
    set_clock_divisor(5);

    return 0;
}

int read_sdmmc_device(unsigned int block_address, void *ptr)
{
    int result;
    int data_timeout;

    result = send_sd_command(CMD_READ_SINGLE_BLOCK, block_address);
    if (result != 0)
    {
        printf("read_sdmmc_device: CMD_READ_SINGLE_BLOCK unexpected response %02x\n", result);
        return -1;
    }

    // Wait for start of data packet
    data_timeout = 10000;
    while (spi_transfer(0xff) != DATA_TOKEN)
    {
        if (--data_timeout == 0)
        {
            printf("read_sdmmc_device: timed out waiting for data token\n");
            return -1;
        }
    }

    for (int i = 0; i < SDMMC_BLOCK_SIZE; i++)
        ((char*) ptr)[i] = spi_transfer(0xff);

    // checksum (ignored)
    spi_transfer(0xff);
    spi_transfer(0xff);

    return SDMMC_BLOCK_SIZE;
}

int write_sdmmc_device(unsigned int block_address, void *ptr)
{
    int result;

    result = send_sd_command(CMD_WRITE_SINGLE_BLOCK, block_address);
    if (result != 0)
    {
        printf("write_sdmmc_device: CMD_WRITE_SINGLE_BLOCK unexpected response %02x\n", result);
        return -1;
    }

    spi_transfer(DATA_TOKEN);
    for (int i = 0; i < SDMMC_BLOCK_SIZE; i++)
        spi_transfer(((char*) ptr)[i]);

    // checksum (ignored)
    spi_transfer(0xff);
    spi_transfer(0xff);

    result = spi_transfer(0xff);
    if ((result & 0x1f) != 0x05)
    {
        printf("write_sdmmc_device: write failed, response %02x\n", result);
        return -1;
    }

    return SDMMC_BLOCK_SIZE;
}
