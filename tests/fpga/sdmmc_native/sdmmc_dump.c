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
#include <sdmmc.h>
#include <unistd.h>

//
// This utility attempts to dump SD card contents using the native
// SD protocol (as opposed to SPI). This code is not fully working;
// I'm using it to debug the interface. The define BITBANG_SDMMC must
// be set in hardware/fpga/de2-115/de2_115_top.sv for this to operate.
//

enum gpio_num {
    GPIO_SD_DAT0 = 0,
    GPIO_SD_DAT1 = 1,
    GPIO_SD_DAT2 = 2,
    GPIO_SD_DAT3 = 3,
    GPIO_SD_CMD = 4,
    GPIO_SD_CLK = 5
};

enum sd_command
{
    SD_GO_IDLE = 0,
    SD_ALL_SEND_CID = 2,
    SD_SEND_RELATIVE_ADDR = 3,
    SD_SET_BUS_WIDTH = 6,
    SD_SELECT_CARD = 7,
    SD_SEND_IF_COND = 8,
    SD_SEND_CSD = 9,
    SD_SEND_CID = 10,
    SD_STOP_TRANSMISSION = 12,
    SD_SET_BLOCKLEN = 16,
    SD_READ_SINGLE_BLOCK = 17,
    SD_SEND_OP_COND = 41,
    SD_APP_CMD = 55,
};

#define GPIO_IN 0
#define GPIO_OUT 1

static volatile unsigned int * const REGISTERS = (volatile unsigned int*) 0xffff0000;
static int current_direction = 0;
static int current_value = 0;

static const unsigned char k_crc7Table[256] = {
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

static void set_direction(int gpio, int out)
{
    if (out)
        current_direction |= (1 << gpio);
    else
        current_direction &= ~(1 << gpio);

    REGISTERS[0x58 / 4] = current_direction;
}

static void set_value(int gpio, int value)
{
    if (value)
        current_value |= (1 << gpio);
    else
        current_value &= ~(1 << gpio);

    REGISTERS[0x5c / 4] = current_value;
}

static int get_value(int gpio)
{
    return (REGISTERS[0x5c / 4] >> gpio) & 1;
}

static void sd_send_byte(int value)
{
    int i;

    for (i = 0; i < 8; i++)
    {
        set_value(GPIO_SD_CLK, 0);
        set_value(GPIO_SD_CMD, (value >> 7) & 1);
        set_value(GPIO_SD_CLK, 1);
        value <<= 1;
    }
}

static void sd_send_command(int cval, unsigned int param)
{
    printf("CMD%d\n", cval);
    printf("send: ");

    int index;
    const unsigned char command[] = {
        0x40 | cval,
        (param >> 24) & 0xff,
        (param >> 16) & 0xff,
        (param >> 8) & 0xff,
        param & 0xff
    };

    set_direction(GPIO_SD_CMD, GPIO_OUT);
    int crc = 0;
    for (index = 0; index < 5; index++)
        crc = k_crc7Table[(crc << 1) ^ command[index]];

    for (index = 0; index < 5; index++)
    {
        sd_send_byte(command[index]);
        printf("%02x ", command[index]);
    }

    sd_send_byte((crc << 1) | 1);
    printf("%02x ", (crc << 1) | 1);
    printf("\n");
}

static int sd_receive_response(unsigned char *out_response, int length, int has_crc)
{
    int timeout = 10000;
    int bit;
    int byte;
    int byte_index = 0;
    unsigned char crc;

    set_direction(GPIO_SD_CMD, GPIO_IN);

    // Wait for start bit
    while (timeout > 0)
    {
        set_value(GPIO_SD_CLK, 0);
        set_value(GPIO_SD_CLK, 1);
        if (get_value(GPIO_SD_CMD) == 0)
            break;

        timeout--;
    }

    if (timeout == 0)
    {
        printf("command timeout\n");
        return -1;
    }

    printf("receive: ");
    // Shift in rest of packet
    bit = 6;
    byte = 0;
    crc = 0;
    while (byte_index < length)
    {
        set_value(GPIO_SD_CLK, 0);
        set_value(GPIO_SD_CLK, 1);

        byte = (byte << 1) | get_value(GPIO_SD_CMD);
        if (bit-- == 0)
        {
            out_response[byte_index++] = byte;
            printf("%02x ", byte);
            byte = 0;
            bit = 7;
        }
    }
    printf("\n");

    if ((out_response[length - 1] & 1) != 1)
        printf("bad framing bit\n");

    if (has_crc)
    {
        for (byte_index = 0; byte_index < length - 1; byte_index++)
            crc = k_crc7Table[(crc << 1) ^ out_response[byte_index]];

        if (crc != (out_response[length - 1] >> 1))
            printf("bad CRC want %02x got %02x\n", crc, (out_response[length - 1] >> 1));
    }

    // 4.4 After the last SD Memory Card bus transaction, the host is required,
    // to provide 8 (eight) clock cycles for the card to complete the operation
    // before shutting down the clock.
    set_direction(GPIO_SD_CLK, GPIO_OUT);
    sd_send_byte(0xff);

    return length;
}

static unsigned int get_dat4()
{
    return REGISTERS[0x5c / 4] & 0xf;
}

static int read_sd_data(void *data)
{
    int byte_index;
    int bit_index;
    int timeout = 10000;
    int value;

    // Wait for start bit
    do
    {
        set_value(GPIO_SD_CLK, 0);
        value = get_dat4();
        set_value(GPIO_SD_CLK, 1);
        timeout--;
    }
    while (value == 0xf && timeout-- > 0);

    if (timeout == 0)
    {
        printf("timeout in read_sd_data\n");
        return -1;
    }

    for (byte_index = 0; byte_index < 512; byte_index++)
    {
        unsigned int byte_value = 0;
        for (bit_index = 0; bit_index < 8; bit_index += 4)
        {
            set_value(GPIO_SD_CLK, 0);
            byte_value = (byte_value << 4) | get_dat4();
            set_value(GPIO_SD_CLK, 1);
        }

        ((unsigned char*) data)[byte_index] = byte_value;
    }

    // Read CRC
    for (bit_index = 0; bit_index < 16; bit_index++)
    {
        set_value(GPIO_SD_CLK, 0);
        set_value(GPIO_SD_CLK, 1);
    }

    // Check end bit
    set_value(GPIO_SD_CLK, 0);
    if (get_value(GPIO_SD_DAT0) != 1)
    {
        printf("Framing error at end of data\n");
        return -1;
    }

    set_value(GPIO_SD_CLK, 1);

    return 512;
}

void dump_r1Status(unsigned char status_bytes[4])
{
    const unsigned int status_value = (status_bytes[0] << 24) | (status_bytes[1] << 16) | (status_bytes[2] << 8)
                                     | status_bytes[3];
    int current_state;

    // Table 4-41
    const char *k_error_codes[] = {
        "OUT_OF_RANGE",
        "ADDRESS_ERROR",
        "BLOCK_LEN_ERROR",
        "ERASE_SEQ_ERROR",
        "ERASE_PARAM",
        "WP_VIOLATION",
        "CARD_IS_LOCKED",
        "LOCK_UNLOCK_FAILED",
        "COM_CRC_ERROR",
        "ILLEGAL_COMMAND",
        "CARD_ECC_FAILED",
        "CC_ERROR",
        "ERROR",
        "reserved",
        "reserved",
        "CSD_OVERWRITE",
        "WP_ERASE_SKIP",
        "CARD_ECC_DISABLED",
        "ERASE_RESET",
        NULL
    };

    const char *k_state_names[] = {
        "idle",
        "ready",
        "ident",
        "stby",
        "tran",
        "data",
        "rcv",
        "prg",
        "dis"
    };

    printf("card status (%08x):\n", status_value);
    for (int i = 0, status_mask = 0x80000000; k_error_codes[i]; i++, status_mask >>= 1)
    {
        if (status_value & status_mask)
            printf(" %s\n", k_error_codes[i]);
    }

    current_state = ((status_value >> 9) & 15);
    if (current_state < 8)
        printf(" current_state = %s\n", k_state_names[current_state]);
    else
        printf(" unknown state %d\n", current_state);

    if (current_state & (1 << 8))
        printf(" READY_FOR_DATA\n");

    if (current_state & (1 << 5))
        printf(" APP_CMD\n");

    if (current_state & (1 << 3))
        printf(" AKE_SEQ_ERROR\n");
}

int main()
{
    int i;
    unsigned char data[512];
    unsigned char response[32];
    int block;

    set_direction(GPIO_SD_CLK, GPIO_OUT);
    set_direction(GPIO_SD_CMD, GPIO_OUT);
    set_value(GPIO_SD_CMD, 1);

    printf("initialize\n");

    // 6.4.1.1: Device may use up to 74 clocks for preparation before
    // receiving the first command.
    for (i = 0; i < 80; i++)
    {
        set_value(GPIO_SD_CLK, 0);
        set_value(GPIO_SD_CLK, 1);
    }

    // Reset card, 4.2.1
    sd_send_command(SD_GO_IDLE, 0);
    sd_send_byte(0xff);

    // 4.2.2 It is mandatory to issue CMD8 prior to first ACMD41 to initialize
    // SDHC or SDXC Card
    sd_send_command(SD_SEND_IF_COND, (1 << 8));	// Supply voltage 3.3V
    sd_receive_response(response, 6, 1);
    dump_r1Status(response + 1);

    // Set voltage level, wait for card ready 4.2.3
    do
    {
        usleep(100000);
        sd_send_command(SD_APP_CMD, 0);
        sd_receive_response(response, 6, 1);
        dump_r1Status(response + 1);

        sd_send_command(SD_SEND_OP_COND, (1 << 20) | (1 << 30) | (1 << 28));	// 3.3V, XD, no power save
        sd_receive_response(response, 6, 0);
    }
    while ((response[1] & 0x80) == 0);

    sd_send_command(SD_ALL_SEND_CID, 0);
    sd_receive_response(response, 17, 0);

    // Get the relative address of the card
    sd_send_command(SD_SEND_RELATIVE_ADDR, 0);
    sd_receive_response(response, 6, 1);

    int rca = (response[1] << 8) | response[2];
    printf("RCA is %d\n", rca);

    // Select the card, using the relative address returned from CMD3
    sd_send_command(SD_SELECT_CARD, (rca << 16));
    sd_receive_response(response, 6, 1);
    dump_r1Status(response + 1);

    // Enable 4-bit mode
    sd_send_command(SD_APP_CMD, (rca << 16));
    sd_receive_response(response, 6, 1);
    dump_r1Status(response + 1);

    sd_send_command(SD_SET_BUS_WIDTH, 2);
    sd_receive_response(response, 6, 1);
    dump_r1Status(response + 1);

    for (block = 0; block < 10; block++)
    {
        sd_send_command(SD_READ_SINGLE_BLOCK, block);
        sd_receive_response(response, 6, 1);
        dump_r1Status(response + 1);

        printf("receiving data\n");
        if (read_sd_data(data) < 0)
            return 1;

        printf("done\n");
        for (int address = 0; address < BLOCK_SIZE; address += 16)
        {
            printf("%08x ", address);
            for (int offset = 0; offset < 16; offset++)
                printf("%02x ", data[address + offset]);

            printf("  ");
            for (int offset = 0; offset < 16; offset++)
            {
                unsigned char c = data[address + offset];
                if (c >= 32 && c <= 128)
                    printf("%c", c);
                else
                    printf(".");
            }

            printf("\n");
        }
    }

    return 0;
}
