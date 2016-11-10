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

#ifndef DEVICE_H
#define DEVICE_H

#include <stdint.h>

#define REG_HOST_INTERRUPT  0xffff0018
#define REG_SERIAL_STATUS   0xffff0040
#define REG_SERIAL_OUTPUT   0xffff0048
#define REG_KEYBOARD_STATUS 0xffff0080
#define REG_KEYBOARD_READ   0xffff0084
#define REG_SD_WRITE_DATA   0xffff00c0
#define REG_SD_READ_DATA    0xffff00c4
#define REG_SD_STATUS       0xffff00c8
#define REG_SD_CONTROL      0xffff00cc
#define REG_THREAD_RESUME   0xffff0100
#define REG_THREAD_HALT     0xffff0104
#define REG_VGA_ENABLE      0xffff0180
#define REG_VGA_BASE        0xffff0188
#define REG_TIMER_INT       0xffff0240

#define INT_COSIM 0x00000001
#define INT_TIMER 0x00000002
#define INT_UART_RX 0x00000004
#define INT_PS2_RX 0x00000008
#define INT_VGA_FRAME 0x00000010

struct processor;

void init_device(struct processor *proc);
void write_device_register(uint32_t address, uint32_t value);
uint32_t read_device_register(uint32_t address);
void enqueue_key(uint32_t scan_code);

#endif
