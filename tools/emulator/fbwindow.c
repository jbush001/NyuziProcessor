// 
// Copyright (C) 2014 Jeff Bush
// 
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
// 

#include <SDL.h>
#include "fbwindow.h"
#include "device.h"

static SDL_Window *gWindow;
static SDL_Renderer *gRenderer;
static SDL_Texture *gFrameBuffer;
static int gFbWidth;
static SDL_Scancode gLastCode;

int initFB(int width, int height)
{
	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_NOPARACHUTE) != 0)
	{
		printf("SDL_Init error: %s\n", SDL_GetError());
		return 0;
	}
	
	gWindow = SDL_CreateWindow("FrameBuffer", SDL_WINDOWPOS_UNDEFINED, 
		SDL_WINDOWPOS_UNDEFINED, width, height, SDL_WINDOW_SHOWN);
	if (!gWindow)
	{
		printf("SDL_CreateWindow error: %s\n", SDL_GetError());
		return 0;
	}
	
	gRenderer = SDL_CreateRenderer(gWindow, -1, SDL_RENDERER_ACCELERATED);
	if (!gRenderer)
	{
		printf("SDL_CreateRenderer error: %s\n", SDL_GetError());
		return 0;
	}
	
	gFbWidth = width;
	gFrameBuffer = SDL_CreateTexture(gRenderer, SDL_PIXELFORMAT_ABGR8888,
		SDL_TEXTUREACCESS_STREAMING, width, height);
	if (!gFrameBuffer)
	{
		printf("SDL_CreateTexture error: %s\n", SDL_GetError());
		return 0;
	}
	
	return 1;
}

// PS2 Scan code set 1
static const int kSdlToPs2Table[] = {
	0,	
	0,	
	0,	
	0,	
	0x1e, // SDL_SCANCODE_A
	0x30, // SDL_SCANCODE_B
	0x2e, // SDL_SCANCODE_C
	0x20, // SDL_SCANCODE_D
	0x12, // SDL_SCANCODE_E
	0x21, // SDL_SCANCODE_F
	0x22, // SDL_SCANCODE_G
	0x23, // SDL_SCANCODE_H
	0x17, // SDL_SCANCODE_I
	0x24, // SDL_SCANCODE_J
	0x25, // SDL_SCANCODE_K
	0x26, // SDL_SCANCODE_L
	0x32, // SDL_SCANCODE_M
	0x31, // SDL_SCANCODE_N
	0x18, // SDL_SCANCODE_O
	0x19, // SDL_SCANCODE_P
	0x10, // SDL_SCANCODE_Q
	0x13, // SDL_SCANCODE_R
	0x1F, // SDL_SCANCODE_S
	0x14, // SDL_SCANCODE_T
	0x16, // SDL_SCANCODE_U
	0x2F, // SDL_SCANCODE_V
	0x11, // SDL_SCANCODE_W
	0x2d, // SDL_SCANCODE_X
	0x15, // SDL_SCANCODE_Y
	0x2C, // SDL_SCANCODE_Z
	0x02, // SDL_SCANCODE_1
	0x03, // SDL_SCANCODE_2
	0x04, // SDL_SCANCODE_3
	0x05, // SDL_SCANCODE_4
	0x06, // SDL_SCANCODE_5
	0x07, // SDL_SCANCODE_6
	0x08, // SDL_SCANCODE_7
	0x09, // SDL_SCANCODE_8
	0x0a, // SDL_SCANCODE_9
	0x0b, // SDL_SCANCODE_0
	0x1c, // SDL_SCANCODE_RETURN
	0x01, // SDL_SCANCODE_ESCAPE
	0x0e, // SDL_SCANCODE_BACKSPACE
	0x0f, // SDL_SCANCODE_TAB
	0x39, // SDL_SCANCODE_SPACE
	0x0c, // SDL_SCANCODE_MINUS
	0x0d, // SDL_SCANCODE_EQUALS
	0x1a, // SDL_SCANCODE_LEFTBRACKET
	0x1b, // SDL_SCANCODE_RIGHTBRACKET
	0x2b, // SDL_SCANCODE_BACKSLASH
	0x00, // SDL_SCANCODE_NONUSHASH
	0x27, // SDL_SCANCODE_SEMICOLON
	0x28, // SDL_SCANCODE_APOSTROPHE
	0x29, // SDL_SCANCODE_GRAVE
	0x33, // SDL_SCANCODE_COMMA
	0x34, // SDL_SCANCODE_PERIOD
	0x35, // SDL_SCANCODE_SLASH
	0x3a, // SDL_SCANCODE_CAPSLOCK
	0x3b, // SDL_SCANCODE_F1
	0x3c, // SDL_SCANCODE_F2
	0x3d, // SDL_SCANCODE_F3
	0x3e, // SDL_SCANCODE_F4
	0x3f, // SDL_SCANCODE_F5
	0x40, // SDL_SCANCODE_F6
	0x41, // SDL_SCANCODE_F7
	0x42, // SDL_SCANCODE_F8
	0x43, // SDL_SCANCODE_F9
	0x44, // SDL_SCANCODE_F10
	0x57, // SDL_SCANCODE_F11
	0x58, // SDL_SCANCODE_F12
	0xe02a,	// SDL_SCANCODE_PRINTSCREEN
	0x46,	// SDL_SCANCODE_SCROLLLOCK
	0xe11d45, // SDL_SCANCODE_PAUSE
	0xe0f2,	// SDL_SCANCODE_INSERT
	0xe047,	// SDL_SCANCODE_HOME
	0xe049,	// SDL_SCANCODE_PAGEUP
	0xe053,	// SDL_SCANCODE_DELETE
	0xe04f,	// SDL_SCANCODE_END
	0xe051,	// SDL_SCANCODE_PAGEDOWN
	0xe04d,	// SDL_SCANCODE_RIGHT
	0xe04b,	// SDL_SCANCODE_LEFT
	0xe050, // SDL_SCANCODE_DOWN
	0xe048,	// SDL_SCANCODE_UP
	0x45,	// SDL_SCANCODE_NUMLOCKCLEAR (?)
	0xe035,	// SDL_SCANCODE_KP_DIVIDE
	0x37,	// SDL_SCANCODE_KP_MULTIPLY
	0x4a,	// SDL_SCANCODE_KP_MINUS
	0x4e, 	// SDL_SCANCODE_KP_PLUS
	0xe01c,	// SDL_SCANCODE_KP_ENTER
	0x4f,	// SDL_SCANCODE_KP_1
	0x50,	// SDL_SCANCODE_KP_2
	0x51, 	// SDL_SCANCODE_KP_3
	0x4b, 	// SDL_SCANCODE_KP_4
	0x4c,	// SDL_SCANCODE_KP_5
	0x4d,	// SDL_SCANCODE_KP_6
	0x47,	// SDL_SCANCODE_KP_7
	0x48,	// SDL_SCANCODE_KP_8
	0x49,	// SDL_SCANCODE_KP_9
	0x52,	// SDL_SCANCODE_KP_0
	0x53,	// SDL_SCANCODE_KP_PERIOD
};

static void convertAndEnqueueScancode(SDL_Scancode code, int isRelease)
{
	int ps2Code;
	int releaseCode = isRelease ? 0x80 : 0;
	
	if (code <= SDL_SCANCODE_KP_PERIOD)
		ps2Code = kSdlToPs2Table[code];
	else 
	{
		switch (code)
		{
			case SDL_SCANCODE_LCTRL:
				ps2Code = 0x1d;
				break;
			case SDL_SCANCODE_LSHIFT:
				ps2Code = 0x2a;
				break;
			case SDL_SCANCODE_LALT:
				ps2Code = 0x38;
				break;
			case SDL_SCANCODE_LGUI:
				ps2Code = 0xe05b;
				break;
			case SDL_SCANCODE_RCTRL:
				ps2Code = 0xe01d;
				break;
			case SDL_SCANCODE_RSHIFT:
				ps2Code = 0x36;
				break;
			case SDL_SCANCODE_RALT:
				ps2Code = 0xe038;
				break;
			case SDL_SCANCODE_RGUI:
				ps2Code = 0xe05c;
				break;
			default:
				return;
		}
	}

	if (ps2Code > 0xffff)
	{
		enqueueKey(ps2Code >> 16);
		enqueueKey((ps2Code >> 8) & 0xff);
		enqueueKey((ps2Code & 0xff) | releaseCode);
	}
	else if (ps2Code > 0xff)
	{
		enqueueKey(ps2Code >> 8);
		enqueueKey((ps2Code & 0xff) | releaseCode);
	}
	else
		enqueueKey(ps2Code | releaseCode);
}


void pollEvent()
{
	SDL_Event event;
	
	while (SDL_PollEvent(&event))
	{
		switch (event.type)
		{
			case SDL_QUIT:
				exit(0);
			
			case SDL_KEYDOWN:
				// Supress autorepeat, otherwise driver queue fills up
				if (gLastCode == event.key.keysym.scancode)
					return;	
	
				gLastCode = event.key.keysym.scancode;
				convertAndEnqueueScancode(event.key.keysym.scancode, 0);
				break;
				
			case SDL_KEYUP:
				gLastCode = -1;
				convertAndEnqueueScancode(event.key.keysym.scancode, 1);
				break;
		}
	}	
}

void updateFB(const void *base)
{
	SDL_UpdateTexture(gFrameBuffer, NULL, base, gFbWidth * 4);
	SDL_RenderCopy(gRenderer, gFrameBuffer, NULL, NULL);
	SDL_RenderPresent(gRenderer);
}


