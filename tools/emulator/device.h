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

// Device addresses
#define DEV_SERIAL_STATUS 0x18
#define DEV_SERIAL_OUTPUT 0x20
#define DEV_KEYBOARD_STATUS 0x38
#define DEV_KEYBOARD_READ 0x3c
#define DEV_REAL_TIME_CLOCK 0x40 
#define DEV_SD_WRITE_DATA 0x44
#define DEV_SD_READ_DATA 0x48
#define DEV_SD_STATUS 0x4c
#define DEV_SD_CONTROL 0x50

int openBlockDevice(const char *filename);
void closeBlockDevice();
void writeDeviceRegister(uint32_t address, uint32_t value);
uint32_t readDeviceRegister(uint32_t address);
void enqueueKey(uint32_t scanCode);

#endif
