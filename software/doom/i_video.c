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

#include "doomstat.h"
#include "i_system.h"
#include "v_video.h"
#include "m_argv.h"
#include "d_main.h"

#include "doomdef.h"

unsigned int gPalette[256];

static volatile unsigned int * const REGISTERS = (volatile unsigned int*) 0xffff0000;


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
	if (REGISTERS[0x38 / 4])
	{
		unsigned int code = REGISTERS[0x3c / 4];
		event_t event;
		
		switch (code & 0x7fffffff)
		{
			case 0x24: // enter
				event.data1 = KEY_ENTER;
				break;
			case 0x30:
				event.data1 = KEY_TAB;
				break;
			case 0x7b:// left arrow
				event.data1 = KEY_LEFTARROW;
				break;
			case 0x7c: // right arrow
				event.data1 = KEY_RIGHTARROW;
				break;
			case 0x7d: // down arrow
				event.data1 = KEY_DOWNARROW;
				break;
			case 0x7e: // up arrow
				event.data1 = KEY_UPARROW;
				break;
			default:
				event.data1 = code & 0x7fffffff;
		}

		if (code & 0x80000000)
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
		int x, y;
		unsigned int *fb = (unsigned int*) 0x200000;
		unsigned char *src = screens[0];
		
		for (y = 0; y < SCREENHEIGHT; y++)
		{
				for (x = 0; x < SCREENWIDTH; x++)
				{
						unsigned int color = gPalette[*src++];
						fb[0] = color;
						fb[1] = color;
						fb[640] = color;
						fb[641] = color;
						fb += 2;
				}
				
				fb += 640;
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
				gPalette[i] = (r << 16) | (g << 8) | b;
		}
}


void I_InitGraphics(void)
{
		printf("I_InitGraphics\n");
}



