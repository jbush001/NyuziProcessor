//
// Copyright 2015 Jeff Bush
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

#include "registers.h"
#include "vga.h"

#define nelems(x) (sizeof(x) / sizeof(x[0]))
#define IN_VIS 1
#define NEW_FRAME 2
#define HSYNC 4
#define VSYNC 8
#define CTL_LOOP (1 << 18)

// Initiaze counter with value
#define INITCNT(counter, value) (((counter) << 17) | ((value) << 4))

// Decrement counter and jump to target PC if it is not yet zero
#define LOOP(counter, target) (CTL_LOOP | ((counter) << 17) | ((target) << 4))

//
// Load microcode into sequencer to generate timing for a given resolution
// - hpf: horizontal front porch length (pixel clocks)
// - hs: horizontal sync pulse length
// - hbp: horizontal back porch length
// - hpol: polarity of horizontal sync, 1 is high, 0 is low
// - hres: horizontal resolution (pixels)
// - vfp: vertical front porch length (lines)
// - vs: vertical sync pulse length
// - vbp: vertical back porch length
// - vpol: vertical polarity
// - vres: vertical resolution (pixels)
//
void load_microcode(int hfp, int hs, int hbp, int hpol, int hres,
	int vfp, int vs, int vbp, int vpol, int vres)
{
	int hsync = (vpol ? 0 : VSYNC) | (hpol ? HSYNC : 0);
	int vsync = (vpol ? VSYNC : 0) | (hpol ? 0 : HSYNC);
	int hsync_vsync = (vpol ? VSYNC : 0) | (hpol ? HSYNC : 0);
	int nosync = (vpol ? 0 : VSYNC) | (hpol ? 0 : HSYNC);
	int i;
	unsigned int UPGM[] = {
			// Vertical front porch
	/*0*/	INITCNT(1, vfp) | nosync,
			INITCNT(0, hfp - 1) | nosync,  // Horizontal Front porch (16 clocks)
			LOOP(0, 2) | nosync,
			INITCNT(0, hs - 1) | hsync,    // Horizontal Sync pulse (neg, 96 clocks)
	/*4*/	LOOP(0, 4) | hsync,
			INITCNT(0, hbp - 1) | nosync,  // Horizontal Back porch (48 clocks)
			LOOP(0, 6) | nosync,
			INITCNT(0, hres - 1) | nosync, // Scanline
	/*8*/	LOOP(0, 8) | nosync,
			LOOP(1, 1) | nosync,

			// Vertical sync (negative)
			INITCNT(1, vs) | vsync,
			INITCNT(0, hfp - 2) | vsync,      // Horizontal Front porch
	/*12*/	LOOP(0, 12) | vsync,
			INITCNT(0, hs - 1) | hsync_vsync, // Horizontal Sync pulse
			LOOP(0, 14) | hsync_vsync,
			INITCNT(0, hbp - 1) | vsync,      // Horizontal Back porch
	/*16*/	LOOP(0, 16) | vsync,
			INITCNT(0, hres - 1) | vsync,     // Scanline
			LOOP(0, 18) | vsync,
			LOOP(1, 11) | vsync,

			// Vertical back porch
	/*20*/	INITCNT(1, vbp) | nosync,
			INITCNT(0, hfp - 1) | nosync,  // Horizontal Front porch
			LOOP(0, 22) | nosync,
			INITCNT(0, hs - 1) | hsync,    // Horizontal Sync pulse
	/*24*/	LOOP(0, 24) | hsync,
			INITCNT(0, hbp - 1) | nosync,  // Horizontal Back porch
			LOOP(0, 26) | nosync,
			INITCNT(0, hres - 1) | nosync, // Scanline
	/*28*/	LOOP(0, 28) | nosync,
			LOOP(1, 21) | nosync,

			// Visible area
			INITCNT(1, vres) | nosync,
			INITCNT(0, hfp - 1) | nosync,   // Horizontal Front porch
	/*32*/	LOOP(0, 32) | nosync,
			INITCNT(0, hs - 1) | hsync,     // Horizontal Sync pulse
			LOOP(0, 34) | hsync,
			INITCNT(0, hbp - 1) | nosync,   // Horizontal Back porch
	/*36*/	LOOP(0, 36) | nosync,
			INITCNT(0, hres - 1) | nosync | IN_VIS,  // Visible area
			LOOP(0, 38) | nosync | IN_VIS,
			LOOP(1, 31) | nosync,
	/*40*/	NEW_FRAME | nosync
	};
	int length = nelems(UPGM);

	// Must disable sequencer to load new program into it
	REGISTERS[REG_VGA_ENABLE] = 0;
	for (i = 0; i < length; i++)
		REGISTERS[REG_VGA_MICROCODE] = UPGM[i];

	REGISTERS[REG_VGA_BASE] = 0x200000;
	REGISTERS[REG_VGA_LENGTH] = hres * vres;
	REGISTERS[REG_VGA_ENABLE] = 1;
}

int init_vga(int mode)
{
	switch (mode)
	{
		case VGA_MODE_640x480:
			load_microcode(16, 96, 48, 0, 640, 10, 2, 33, 0, 480);
			break;

		case VGA_MODE_640x400:
			load_microcode(16, 96, 48, 0, 640, 12, 2, 35, 1, 400);
			break;

		default:
			return -1;
	}

	return 0;
}
