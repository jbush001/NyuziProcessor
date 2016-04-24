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

#ifndef __DEVICE_H
#define __DEVICE_H

#include <stdint.h>

enum DeviceAddress
{
    REG_HOST_INTERRUPT = 0x18,
    REG_SERIAL_STATUS = 0x40,
    REG_SERIAL_OUTPUT = 0x48,
    REG_KEYBOARD_STATUS = 0x80,
    REG_KEYBOARD_READ = 0x84,
    REG_SD_WRITE_DATA = 0xc0,
    REG_SD_READ_DATA = 0xc4,
    REG_SD_STATUS = 0xc8,
    REG_SD_CONTROL = 0xcc,
    REG_VGA_ENABLE = 0x180,
    REG_VGA_BASE = 0x188
};

void writeDeviceRegister(uint32_t address, uint32_t value);
uint32_t readDeviceRegister(uint32_t address);
void enqueueKey(uint32_t scanCode);

#endif
