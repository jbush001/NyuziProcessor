// Emacs style mode select	 -*- C++ -*-
//-----------------------------------------------------------------------------
//
// $Id:$
//
// Copyright (C) 1993-1996 by id Software, Inc.
//
// This source is available for distribution and/or modification
// only under the terms of the DOOM Source Code License as
// published by id Software. All rights reserved.
//
// The source is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// FITNESS FOR A PARTICULAR PURPOSE. See the DOOM Source Code License
// for more details.
//
// $Log:$
//
// DESCRIPTION:
//		DOOM graphics stuff for X11, UNIX.
//
//-----------------------------------------------------------------------------

static const char
rcsid[] = "$Id: i_x.c,v 1.6 1997/02/03 22:45:10 b1 Exp $";

#include <stdint.h>
#include <time.h>
#include <keyboard.h>
#include <vga.h>
#include "doomstat.h"
#include "i_system.h"
#include "v_video.h"
#include "m_argv.h"
#include "d_main.h"

#include "doomdef.h"

static unsigned int gPalette[256];
static clock_t lastFrameTime = 0;
static int frameCount = 0;
static unsigned int *fb_base;

void I_ShutdownGraphics(void)
{
}

//
// I_StartFrame
//
void I_StartFrame (void)
{
}

void I_GetEvent(void)
{
}

//
// I_StartTic
//
void I_StartTic (void)
{
    // Read keyboard
    unsigned int code = poll_keyboard();
    if (code != 0xffffffff)
    {
        event_t event;

        switch (code & 0xffff)
        {
            case KBD_F1:
                event.data1 = KEY_F1;
                break;
            case KBD_F2:
                event.data1 = KEY_F2;
                break;
            case KBD_F3:
                event.data1 = KEY_F3;
                break;
            case KBD_F4:
                event.data1 = KEY_F4;
                break;
            case KBD_F5:
                event.data1 = KEY_F5;
                break;
            case KBD_F6:
                event.data1 = KEY_F6;
                break;
            case KBD_F7:
                event.data1 = KEY_F7;
                break;
            case KBD_F8:
                event.data1 = KEY_F8;
                break;
            case KBD_F9:
                event.data1 = KEY_F9;
                break;
            case KBD_RIGHTARROW:
                event.data1 = KEY_RIGHTARROW;
                break;
            case KBD_LEFTARROW:
                event.data1 = KEY_LEFTARROW;
                break;
            case KBD_UPARROW:
                event.data1 = KEY_UPARROW;
                break;
            case KBD_DOWNARROW:
                event.data1 = KEY_DOWNARROW;
                break;
            case KBD_RSHIFT:
                event.data1 = KEY_RSHIFT;
                break;
            case KBD_LSHIFT:
                event.data1 = KEY_LSHIFT;
                break;
            case KBD_RALT:
                event.data1 = KEY_RALT;
                break;
            case KBD_LALT:
                event.data1 = KEY_LALT;
                break;
            case '\x08':
                event.data1 = KEY_BACKSPACE;
                break;
            case '\x27':
                event.data1 = KEY_ESCAPE;
                break;
            case '\n':
                event.data1 = KEY_ENTER;
                break;
            case '\t':
                event.data1 = KEY_TAB;
                break;
            default:
                event.data1 = code & 0xff;
        }

        if (code & KBD_PRESSED)
            event.type = ev_keydown;
        else
            event.type = ev_keyup;

        D_PostEvent(&event);
    }
}


//
// I_UpdateNoBlit
//
void I_UpdateNoBlit (void)
{
    // what is this?
}

//
// I_FinishUpdate
//
void I_FinishUpdate (void)
{
    int x, y, offs;
    veci16_t *dest = (veci16_t*) fb_base;
    const unsigned char *src = screens[0];
    veci16_t pixelVals;
    int mask;

    // Copy to framebuffer and expand palette
    for (y = 0; y < SCREENHEIGHT; y++)
    {
        for (x = 0; x < SCREENWIDTH; x += 8)
        {
            mask = 0xc000;
            for (offs = 0; offs < 8; offs++, mask >>= 2)
            {
                pixelVals = __builtin_nyuzi_vector_mixi(mask, (veci16_t) gPalette[*src++],
                                                        pixelVals);
            }

            dest[0] = pixelVals;
            dest[40] = pixelVals;
            asm("dflush %0" : : "s" (dest));
            asm("dflush %0" : : "s" (dest + 40));
            dest++;
        }

        dest += 40;
    }

    // Print some statistics
    if (++frameCount == 20)
    {
        clock_t currentTime = clock();
        float deltaTime = (float)(currentTime - lastFrameTime) / CLOCKS_PER_SEC;
        printf("%g fps\n", (float) frameCount / deltaTime);
        frameCount = 0;
        lastFrameTime = currentTime;
    }
}


//
// I_ReadScreen
//
void I_ReadScreen (byte* scr)
{
    memcpy (scr, screens[0], SCREENWIDTH*SCREENHEIGHT);
}


//
// I_SetPalette
//
void I_SetPalette (byte* palette)
{
    int i;

    for (i = 0; i < 256; i++)
    {
        byte r = gammatable[usegamma][*palette++];
        byte g = gammatable[usegamma][*palette++];
        byte b = gammatable[usegamma][*palette++];
        gPalette[i] = 0xff000000 | (b << 16) | (g << 8) | r;
    }
}


void I_InitGraphics(void)
{
    fb_base = init_vga(VGA_MODE_640x400);
}



