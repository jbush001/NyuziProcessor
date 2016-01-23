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

#include "protocol.h"

//
// First stage serial bootloader. This is synthesized into ROM in high memory
// on FPGA. It communicates with a loader program on the host (tools/serial_boot),
// which loads a program into memory. Because this is running in ROM, it cannot
// use global variables.
//

extern void *memset(void *_dest, int value, unsigned int length);

static volatile unsigned int * const REGISTERS = (volatile unsigned int*) 0xffff0000;

enum RegisterIndex
{
    REG_RED_LED             = 0x0000 / 4,
    REG_UART_STATUS         = 0x0018 / 4,
    REG_UART_RX             = 0x001c / 4,
    REG_UART_TX             = 0x0020 / 4,
};

unsigned int readSerialByte(void)
{
    while ((REGISTERS[REG_UART_STATUS] & 2) == 0)
        ;

    return REGISTERS[REG_UART_RX];
}

void writeSerialByte(unsigned int ch)
{
    while ((REGISTERS[REG_UART_STATUS] & 1) == 0)	// Wait for ready
        ;

    REGISTERS[REG_UART_TX] = ch;
}

unsigned int readSerialLong(void)
{
    unsigned int result = 0;
    for (int i = 0; i < 4; i++)
        result = (result >> 8) | (readSerialByte() << 24);

    return result;
}

void writeSerialLong(unsigned int value)
{
    writeSerialByte(value & 0xff);
    writeSerialByte((value >> 8) & 0xff);
    writeSerialByte((value >> 16) & 0xff);
    writeSerialByte((value >> 24) & 0xff);
}

int main()
{
    // Turn on red LED to indicate bootloader is waiting
    REGISTERS[REG_RED_LED] = 0x1;

    for (;;)
    {
        switch (readSerialByte())
        {
            case LOAD_MEMORY_REQ:
            {
                unsigned char *loadAddr = (unsigned char*) readSerialLong();
                unsigned int length = readSerialLong();
                unsigned int checksum = 2166136261; // FNV-1a hash
                for (int i = 0; i < length; i++)
                {
                    unsigned int ch = readSerialByte();
                    checksum = (checksum ^ ch) * 16777619;
                    *loadAddr++ = ch;
                }

                writeSerialByte(LOAD_MEMORY_ACK);
                writeSerialLong(checksum);
                break;
            }

            case CLEAR_MEMORY_REQ:
            {
                void *baseAddress = (void*) readSerialLong();
                unsigned int length = readSerialLong();
                memset(baseAddress, 0, length);
                writeSerialByte(CLEAR_MEMORY_ACK);
                break;
            }

            case EXECUTE_REQ:
            {
                REGISTERS[REG_RED_LED] = 0;	// Turn off LED
                writeSerialByte(EXECUTE_ACK);
                return 0;	// Break out of main
            }

            case PING_REQ:
                writeSerialByte(PING_ACK);
                break;

            default:
                writeSerialByte(BAD_COMMAND);
        }
    }
}
