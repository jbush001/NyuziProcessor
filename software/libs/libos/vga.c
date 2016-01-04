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

// Microinstruction format:
//    op (1)  0: load counter 1: loop
//    counter value or branch dest (13)
//    vsync (1)
//    hsync (1)
//    new_frame (1)
//    in_visible (1)

#define OP_LOAD 0
#define OP_LOOP 1
#define HCOUNT 0
#define VCOUNT 1
#define F_VISIBLE 1
#define F_NEW_FRAME 2
#define F_HSYNC 4
#define F_VSYNC 8

static int gCurrentPc;
static int gSyncFlags;

static void emitOp(int opcode, int counterIndex, int value)
{
    REGISTERS[REG_VGA_MICROCODE] = (opcode << 18) | (counterIndex << 17)
                                   | (value << 4) | gSyncFlags;
    gCurrentPc++;
}

static void emitScanline(int hfp, int hs, int hbp, int hres, int visible)
{
    // Horizontal Front porch
    emitOp(OP_LOAD, HCOUNT, hfp - 1);
    emitOp(OP_LOOP, HCOUNT, gCurrentPc);

    // Horizontal Sync pulse
    gSyncFlags ^= F_HSYNC;
    emitOp(OP_LOAD, HCOUNT, hs - 1);
    emitOp(OP_LOOP, HCOUNT, gCurrentPc);
    gSyncFlags ^= F_HSYNC;

    // Horizontal Back porch
    emitOp(OP_LOAD, HCOUNT, hbp - 1);
    emitOp(OP_LOOP, HCOUNT, gCurrentPc);

    // Scanline
    if (visible)
        gSyncFlags ^= F_VISIBLE;

    emitOp(OP_LOAD, HCOUNT, hres - 1);
    emitOp(OP_LOOP, HCOUNT, gCurrentPc);
    if (visible)
        gSyncFlags ^= F_VISIBLE;
}

//
// Compile microcode to generate synchronization signals for resolution and
// load into microsequencer.
//
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
static void compileMicrocode(int hfp, int hs, int hbp, int hpol, int hres,
                             int vfp, int vs, int vbp, int vpol, int vres)
{
    int vLoopTop;
    gSyncFlags = (vpol ? 0 : F_VSYNC) | (hpol ? 0 : F_HSYNC);
    gCurrentPc = 0;

    // Must disable sequencer to load new program into it
    REGISTERS[REG_VGA_ENABLE] = 0;

    // Vertical front porch
    emitOp(OP_LOAD, VCOUNT, vfp);
    vLoopTop = gCurrentPc;
    emitScanline(hfp, hs, hbp, hres, 0);
    emitOp(OP_LOOP, VCOUNT, vLoopTop);

    // Vertical sync
    gSyncFlags ^= F_VSYNC;
    emitOp(OP_LOAD, VCOUNT, vs);
    vLoopTop = gCurrentPc;
    emitScanline(hfp, hs, hbp, hres, 0);
    emitOp(OP_LOOP, VCOUNT, vLoopTop);
    gSyncFlags ^= F_VSYNC;

    // Vertical back porch
    emitOp(OP_LOAD, VCOUNT, vbp);
    vLoopTop = gCurrentPc;
    emitScanline(hfp, hs, hbp, hres, 0);
    emitOp(OP_LOOP, VCOUNT, vLoopTop);

    // Visible area
    emitOp(OP_LOAD, VCOUNT, vres);
    vLoopTop = gCurrentPc;
    emitScanline(hfp, hs, hbp, hres, 1);
    emitOp(OP_LOOP, VCOUNT, vLoopTop);
    REGISTERS[REG_VGA_MICROCODE] = gSyncFlags | F_NEW_FRAME;

    REGISTERS[REG_VGA_BASE] = 0x200000;
    REGISTERS[REG_VGA_LENGTH] = hres * vres;
    REGISTERS[REG_VGA_ENABLE] = 1;
}

int initVGA(VGAMode mode)
{
    switch (mode)
    {
        case VGA_MODE_640x480:
            compileMicrocode(16, 96, 48, 0, 640, 10, 2, 33, 0, 480);
            break;

        case VGA_MODE_640x400:
            compileMicrocode(16, 96, 48, 0, 640, 12, 2, 35, 1, 400);
            break;

        default:
            return -1;
    }

    return 0;
}
