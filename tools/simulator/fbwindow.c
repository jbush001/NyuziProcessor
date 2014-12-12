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
const int kSdlToPs2Table[] = {
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
};

int convertScancode(SDL_Scancode code)
{
	if (code <= SDL_SCANCODE_SLASH)
		return kSdlToPs2Table[code];
	else 
	{
		switch (code)
		{
			case SDL_SCANCODE_LSHIFT:
				return 0x2a;
			case SDL_SCANCODE_RSHIFT:
				return 0x36;
			case SDL_SCANCODE_LEFT:
				return 0xe04b;
			case SDL_SCANCODE_RIGHT:
				return 0xe04d;
			case SDL_SCANCODE_UP:
				return 0xe048;
			case SDL_SCANCODE_DOWN:
				return 0xe050;
			default:
				return -1;
		}
	}

	return -1;
}


void pollEvent()
{
	SDL_Event event;
	int ps2Code;
	
	while (SDL_PollEvent(&event))
	{
		switch (event.type)
		{
			case SDL_QUIT:
				exit(0);
			
			case SDL_KEYDOWN:
				if (event.key.keysym.scancode == gLastCode)
					return;	// Supress autorepeat, otherwise driver queue fills up
	
				gLastCode = event.key.keysym.scancode;

				ps2Code = convertScancode(event.key.keysym.scancode);
				if (ps2Code >= 0xff)
				{
					enqueueKey(ps2Code >> 8);
					enqueueKey(ps2Code & 0xff);
				}
				else if (ps2Code >= 0)
					enqueueKey(ps2Code);

				break;
				
			case SDL_KEYUP:
				gLastCode = -1;
				ps2Code = convertScancode(event.key.keysym.scancode);
				if (ps2Code >= 0xff)
				{
					enqueueKey(ps2Code >> 8);
					enqueueKey((ps2Code & 0xff) | 0x80);
				}
				else if (ps2Code >= 0)
					enqueueKey(ps2Code | 0x80);

				break;
		}
	}	
}

void updateFB(void *base)
{
	SDL_UpdateTexture(gFrameBuffer, NULL, base, gFbWidth * 4);
	SDL_RenderCopy(gRenderer, gFrameBuffer, NULL, NULL);
	SDL_RenderPresent(gRenderer);
}


