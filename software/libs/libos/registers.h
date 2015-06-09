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

#pragma once

static volatile unsigned int * const REGISTERS = (volatile unsigned int*) 0xffff0000;

enum RegisterIndex
{
	REG_RED_LED             = 0x0000 / 4,
	REG_GREEN_LED           = 0x0004 / 4,
	REG_HEX0                = 0x0008 / 4,
	REG_HEX1                = 0x000c / 4,
	REG_HEX2                = 0x0010 / 4,
	REG_HEX3                = 0x0014 / 4,
	REG_UART_STATUS         = 0x0018 / 4,
	REG_UART_RX             = 0x001c / 4,
	REG_UART_TX             = 0x0020 / 4,
	REG_VGA_BASE            = 0x0028 / 4,
	REG_VGA_FRAME_TOGGLE    = 0x002c / 4,
	REG_KB_STATUS           = 0x0038 / 4,
	REG_KB_SCANCODE         = 0x003c / 4,
	REG_SD_SPI_WRITE        = 0x0044 / 4,
	REG_SD_SPI_READ         = 0x0048 / 4,
	REG_SD_SPI_STATUS       = 0x004c / 4,
	REG_SD_SPI_CONTROL      = 0x0050 / 4,
	REG_SD_SPI_CLOCK_DIVIDE = 0x0054 / 4,
	REG_SD_GPIO_DIRECTION   = 0x0058 / 4,
	REG_SD_GPIO_VALUE       = 0x005c / 4
};

