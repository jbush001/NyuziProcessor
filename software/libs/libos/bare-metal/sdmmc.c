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

static const unsigned char CRC7_TABLE[256] = {
    0x00, 0x09, 0x12, 0x1b, 0x24, 0x2d, 0x36, 0x3f,
    0x48, 0x41, 0x5a, 0x53, 0x6c, 0x65, 0x7e, 0x77,
    0x19, 0x10, 0x0b, 0x02, 0x3d, 0x34, 0x2f, 0x26,
    0x51, 0x58, 0x43, 0x4a, 0x75, 0x7c, 0x67, 0x6e,
    0x32, 0x3b, 0x20, 0x29, 0x16, 0x1f, 0x04, 0x0d,
    0x7a, 0x73, 0x68, 0x61, 0x5e, 0x57, 0x4c, 0x45,
    0x2b, 0x22, 0x39, 0x30, 0x0f, 0x06, 0x1d, 0x14,
    0x63, 0x6a, 0x71, 0x78, 0x47, 0x4e, 0x55, 0x5c,
    0x64, 0x6d, 0x76, 0x7f, 0x40, 0x49, 0x52, 0x5b,
    0x2c, 0x25, 0x3e, 0x37, 0x08, 0x01, 0x1a, 0x13,
    0x7d, 0x74, 0x6f, 0x66, 0x59, 0x50, 0x4b, 0x42,
    0x35, 0x3c, 0x27, 0x2e, 0x11, 0x18, 0x03, 0x0a,
    0x56, 0x5f, 0x44, 0x4d, 0x72, 0x7b, 0x60, 0x69,
    0x1e, 0x17, 0x0c, 0x05, 0x3a, 0x33, 0x28, 0x21,
    0x4f, 0x46, 0x5d, 0x54, 0x6b, 0x62, 0x79, 0x70,
    0x07, 0x0e, 0x15, 0x1c, 0x23, 0x2a, 0x31, 0x38,
    0x41, 0x48, 0x53, 0x5a, 0x65, 0x6c, 0x77, 0x7e,
    0x09, 0x00, 0x1b, 0x12, 0x2d, 0x24, 0x3f, 0x36,
    0x58, 0x51, 0x4a, 0x43, 0x7c, 0x75, 0x6e, 0x67,
    0x10, 0x19, 0x02, 0x0b, 0x34, 0x3d, 0x26, 0x2f,
    0x73, 0x7a, 0x61, 0x68, 0x57, 0x5e, 0x45, 0x4c,
    0x3b, 0x32, 0x29, 0x20, 0x1f, 0x16, 0x0d, 0x04,
    0x6a, 0x63, 0x78, 0x71, 0x4e, 0x47, 0x5c, 0x55,
    0x22, 0x2b, 0x30, 0x39, 0x06, 0x0f, 0x14, 0x1d,
    0x25, 0x2c, 0x37, 0x3e, 0x01, 0x08, 0x13, 0x1a,
    0x6d, 0x64, 0x7f, 0x76, 0x49, 0x40, 0x5b, 0x52,
    0x3c, 0x35, 0x2e, 0x27, 0x18, 0x11, 0x0a, 0x03,
    0x74, 0x7d, 0x66, 0x6f, 0x50, 0x59, 0x42, 0x4b,
    0x17, 0x1e, 0x05, 0x0c, 0x33, 0x3a, 0x21, 0x28,
    0x5f, 0x56, 0x4d, 0x44, 0x7b, 0x72, 0x69, 0x60,
    0x0e, 0x07, 0x1c, 0x15, 0x2a, 0x23, 0x38, 0x31,
    0x46, 0x4f, 0x54, 0x5d, 0x62, 0x6b, 0x70, 0x79
};

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
    int crc;
    int index;

    const unsigned char command_encoding[] = {
        0x40 | command,
        (parameter >> 24) & 0xff,
        (parameter >> 16) & 0xff,
        (parameter >> 8) & 0xff,
        parameter & 0xff
    };

    // Only commands 0 and 8 check the CRC in SPI mode.
    crc = 0;
    for (index = 0; index < 5; index++)
        crc = CRC7_TABLE[(crc << 1) ^ command_encoding[index]];

    for (index = 0; index < 5; index++)
        spi_transfer(command_encoding[index]);

    spi_transfer((crc << 1) | 1);

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

        // HCS (bit 30) is 1. Bits 15-23 set voltage window.
        result = send_sd_command(CMD_APP_OP_COND, 0x40fc0000);

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
