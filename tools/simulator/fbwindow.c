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
	gFrameBuffer = SDL_CreateTexture(gRenderer, SDL_PIXELFORMAT_ARGB8888,
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
	1,	
	2,	
	3,	
	0x1e, // A
	0x30, // B
	0x2e, // C
	0x20, // D
	0x12, // E
	0x21, // F
	0x22, // G
	0x23, // H
	0x17, // I
	0x24, // J
	0x25, // K
	0x26, // L
	0x32, // M
	0x31, // N
	0x18, // O
	0x19, // P
	0x10, // Q
	0x13, // R
	0x1F, // S
	0x14, // T
	0x16, // U
	0x2F, // V
	0x11, // W
	0x2d, // X
	0x15, // Y
	0x2C, // Z
	0x02, // 1
	0x03, // 2
	0x04, // 3
	0x05, // 4
	0x06, // 5
	0x07, // 6
	0x08, // 7
	0x09, // 8
	0x0a, // 9
	0x0b, // 0
	0x1c, // return
	0x01, // escape
	0x0e, // backspace
	0x0f, // tab
	0x39, // space
	0x0c, // -
	0x0d, // =
	0x1a, // [
	0x1b, // ]
	0x2b, // backslash
	0x00, // non us hash (?)
	0x27, // ;
	0x28, // '
	0x29, // `
	0x33, // ,
	0x34, // .
	0x35, // /
	0x00, // capslock
	0x3b, // f1
	0x3c, // f2
	0x3d, // f3
	0x3e, // f4
	0x3f, // f5
	0x40, // f6
	0x41, // f7
	0x42, // f8
	0x43, // f9
	0x44, // f10
	0x57, // f11
	0x58, // f12
	0xe02a,	// print screen
	0x46,	// scroll lock
};

static void convertAndEnqueueScancode(SDL_Scancode code, int isRelease)
{
	int ps2Code;
	int releaseCode = isRelease ? 0x80 : 0;
	
	if (code <= SDL_SCANCODE_SCROLLLOCK)
		ps2Code = kSdlToPs2Table[code];
	else 
	{
		switch (code)
		{
			case SDL_SCANCODE_LSHIFT:
				ps2Code = 0x2a;
				break;
			case SDL_SCANCODE_RSHIFT:
				ps2Code = 0x36;
				break;
			case SDL_SCANCODE_LEFT:
				ps2Code = 0xe04b;
				break;
			case SDL_SCANCODE_RIGHT:
				ps2Code = 0xe04d;
				break;
			case SDL_SCANCODE_UP:
				ps2Code = 0xe048;
				break;
			case SDL_SCANCODE_DOWN:
				ps2Code = 0xe050;
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


