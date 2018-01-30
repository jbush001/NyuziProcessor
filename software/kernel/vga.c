//
// Copyright 2015-2016 Jeff Bush
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

#include "libc.h"
#include "registers.h"
#include "thread.h"
#include "vga.h"
#include "vm_address_space.h"
#include "vm_page.h"

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

static int ucode_emit_pc;
static int ucode_sync_flags;

static void emit_op(int opcode, int counter_index, int value)
{
    REGISTERS[REG_VGA_MICROCODE] = (opcode << 18) | (counter_index << 17)
                                   | (value << 4) | ucode_sync_flags;
    ucode_emit_pc++;
}

static void emit_scanline(int hfp, int hs, int hbp, int hres, int visible)
{
    // Horizontal Front porch
    emit_op(OP_LOAD, HCOUNT, hfp - 1);
    emit_op(OP_LOOP, HCOUNT, ucode_emit_pc);

    // Horizontal Sync pulse
    ucode_sync_flags ^= F_HSYNC;
    emit_op(OP_LOAD, HCOUNT, hs - 1);
    emit_op(OP_LOOP, HCOUNT, ucode_emit_pc);
    ucode_sync_flags ^= F_HSYNC;

    // Horizontal Back porch
    emit_op(OP_LOAD, HCOUNT, hbp - 1);
    emit_op(OP_LOOP, HCOUNT, ucode_emit_pc);

    // Scanline
    if (visible)
        ucode_sync_flags ^= F_VISIBLE;

    emit_op(OP_LOAD, HCOUNT, hres - 1);
    emit_op(OP_LOOP, HCOUNT, ucode_emit_pc);
    if (visible)
        ucode_sync_flags ^= F_VISIBLE;
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
static void compile_microcode(int hfp, int hs, int hbp, int hpol, int hres,
                              int vfp, int vs, int vbp, int vpol, int vres)
{
    int v_loop_top;
    ucode_sync_flags = (vpol ? 0 : F_VSYNC) | (hpol ? 0 : F_HSYNC);
    ucode_emit_pc = 0;

    // Vertical front porch
    emit_op(OP_LOAD, VCOUNT, vfp);
    v_loop_top = ucode_emit_pc;
    emit_scanline(hfp, hs, hbp, hres, 0);
    emit_op(OP_LOOP, VCOUNT, v_loop_top);

    // Vertical sync
    ucode_sync_flags ^= F_VSYNC;
    emit_op(OP_LOAD, VCOUNT, vs);
    v_loop_top = ucode_emit_pc;
    emit_scanline(hfp, hs, hbp, hres, 0);
    emit_op(OP_LOOP, VCOUNT, v_loop_top);
    ucode_sync_flags ^= F_VSYNC;

    // Vertical back porch
    emit_op(OP_LOAD, VCOUNT, vbp);
    v_loop_top = ucode_emit_pc;
    emit_scanline(hfp, hs, hbp, hres, 0);
    emit_op(OP_LOOP, VCOUNT, v_loop_top);

    // Visible area
    emit_op(OP_LOAD, VCOUNT, vres);
    v_loop_top = ucode_emit_pc;
    emit_scanline(hfp, hs, hbp, hres, 1);
    emit_op(OP_LOOP, VCOUNT, v_loop_top);
    REGISTERS[REG_VGA_MICROCODE] = ucode_sync_flags | F_NEW_FRAME;

}

void *init_vga(enum vga_mode mode)
{
    struct vm_area *area;
    unsigned int phys_addr;
    unsigned int fb_size;

    // Must disable sequencer to load new program into it
    REGISTERS[REG_VGA_ENABLE] = 0;

    switch (mode)
    {
        case VGA_MODE_640x480:
            compile_microcode(16, 96, 48, 0, 640, 10, 2, 33, 0, 480);
            fb_size = 640 * 480 * 4;
            break;

        case VGA_MODE_640x400:
            compile_microcode(16, 96, 48, 0, 640, 12, 2, 35, 1, 400);
            fb_size = 640 * 400 * 4;
            break;

        default:
            return 0;
    }

    phys_addr = allocate_contiguous_memory(fb_size);
    area = map_contiguous_memory(current_thread()->proc->space, 0x40000000, fb_size,
        PLACE_SEARCH_UP, "frame buffer", AREA_WIRED | AREA_WRITABLE, phys_addr);

    REGISTERS[REG_VGA_BASE] = phys_addr;
    REGISTERS[REG_VGA_LENGTH] = fb_size / 4;
    REGISTERS[REG_VGA_ENABLE] = 1;

    kprintf("mapped frame buffer at %08x\n", fb_size);

    return (void*) area->low_address;
}
