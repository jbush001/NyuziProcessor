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
#include "processor.h"
#include "device.h"
#include "fbwindow.h"
#include "sdmmc.h"

#define KEY_BUFFER_SIZE 64
#define SERIAL_BUFFER_SIZE 64

extern void send_host_interrupt(uint32_t num);

static uint32_t key_buf[KEY_BUFFER_SIZE];
static int key_buf_head;
static int key_buf_tail;
static uint8_t serial_read_buf[SERIAL_BUFFER_SIZE];
static int serial_read_buf_head;
static int serial_read_buf_tail;
static struct processor *proc;

void init_device(struct processor *_proc)
{
    proc = _proc;
}

void write_device_register(uint32_t address, uint32_t value)
{
    switch (address)
    {
        case REG_SERIAL_OUTPUT:
            putc(value & 0xff, stdout);
            fflush(stdout);
            break;

        case REG_SD_WRITE_DATA:
        case REG_SD_CONTROL:
            write_sd_card_register(address, value);
            break;

        case REG_VGA_ENABLE:
            enable_frame_buffer(value & 1);
            break;

        case REG_VGA_BASE:
            set_frame_buffer_address(value);
            break;

        case REG_HOST_INTERRUPT:
            send_host_interrupt(value);
            break;
    }
}

uint32_t read_device_register(uint32_t address)
{
    uint32_t value;

    switch (address)
    {
        case REG_SERIAL_STATUS:
            return 1 | ((serial_read_buf_head != serial_read_buf_tail) ? 2 : 0);

        case REG_SERIAL_INPUT:
            if (serial_read_buf_head != serial_read_buf_tail)
            {
                value = serial_read_buf[serial_read_buf_tail];
                serial_read_buf_tail = (serial_read_buf_tail + 1)
                    % SERIAL_BUFFER_SIZE;
            }
            else
                value = 0;

            if (serial_read_buf_head == serial_read_buf_tail)
                clear_interrupt(proc, INT_UART_RX);

            return value;


        case REG_KEYBOARD_STATUS:
            if (key_buf_head != key_buf_tail)
                return 1;
            else
                return 0;

        case REG_KEYBOARD_READ:
            if (key_buf_head != key_buf_tail)
            {
                value = key_buf[key_buf_tail];
                key_buf_tail = (key_buf_tail + 1) % KEY_BUFFER_SIZE;
            }
            else
                value = 0;

            if (key_buf_head == key_buf_tail)
                clear_interrupt(proc, INT_PS2_RX);

            return value;

        case REG_SD_READ_DATA:
        case REG_SD_STATUS:
            return read_sd_card_register(address);

        default:
            return 0xffffffff;
    }
}

void enqueue_key(uint32_t scan_code)
{
    key_buf[key_buf_head] = scan_code;
    key_buf_head = (key_buf_head + 1) % KEY_BUFFER_SIZE;

    // If the buf is full, discard the oldest character
    if (key_buf_head == key_buf_tail)
        key_buf_tail = (key_buf_tail + 1) % KEY_BUFFER_SIZE;

    raise_interrupt(proc, INT_PS2_RX);
}

void enqueue_serial_char(uint32_t scan_code)
{
    serial_read_buf[serial_read_buf_head] = scan_code;
    serial_read_buf_head = (serial_read_buf_head + 1) % SERIAL_BUFFER_SIZE;

    // If the buf is full, discard the oldest character.
    // XXX Technically this should set the overrun flag.
    if (serial_read_buf_head == serial_read_buf_tail)
        serial_read_buf_tail = (serial_read_buf_tail + 1) % SERIAL_BUFFER_SIZE;

    raise_interrupt(proc, INT_UART_RX);
}
