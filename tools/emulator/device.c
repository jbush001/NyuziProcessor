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
#include <stdio.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include "core.h"
#include "device.h"
#include "fbwindow.h"
#include "sdmmc.h"

#define KEY_BUFFER_SIZE 64

extern void sendHostInterrupt(uint32_t num);

static uint32_t gKeyBuffer[KEY_BUFFER_SIZE];
static int gKeyBufferHead;
static int gKeyBufferTail;

void writeDeviceRegister(uint32_t address, uint32_t value)
{
    switch (address)
    {
        case REG_SERIAL_OUTPUT:
            putc(value & 0xff, stdout);
            fflush(stdout);
            break;

        case REG_SD_WRITE_DATA:
        case REG_SD_CONTROL:
            writeSdCardRegister(address, value);
            break;

        case REG_VGA_ENABLE:
            enableFramebuffer(value & 1);
            break;

        case REG_VGA_BASE:
            setFramebufferAddress(value);
            break;

        case REG_HOST_INTERRUPT:
            sendHostInterrupt(value);
            break;
    }
}

uint32_t readDeviceRegister(uint32_t address)
{
    uint32_t value;

    switch (address)
    {
        case REG_SERIAL_STATUS:
            return 1;

        case REG_KEYBOARD_STATUS:
            if (gKeyBufferHead != gKeyBufferTail)
                return 1;
            else
                return 0;

        case REG_KEYBOARD_READ:
            if (gKeyBufferHead != gKeyBufferTail)
            {
                value = gKeyBuffer[gKeyBufferTail];
                gKeyBufferTail = (gKeyBufferTail + 1) % KEY_BUFFER_SIZE;
            }
            else
                value = 0;

            return value;

        case REG_SD_READ_DATA:
        case REG_SD_STATUS:
            return readSdCardRegister(address);

        default:
            return 0xffffffff;
    }
}

void enqueueKey(uint32_t scanCode)
{
    gKeyBuffer[gKeyBufferHead] = scanCode;
    gKeyBufferHead = (gKeyBufferHead + 1) % KEY_BUFFER_SIZE;

    // If the buffer is full, discard the oldest character
    if (gKeyBufferHead == gKeyBufferTail)
        gKeyBufferTail = (gKeyBufferTail + 1) % KEY_BUFFER_SIZE;
}
