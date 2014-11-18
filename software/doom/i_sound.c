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
//		System interface for sound.
//
//-----------------------------------------------------------------------------

#include "sounds.h"

static const char
rcsid[] = "$Id: i_unix.c,v 1.5 1997/02/03 22:45:10 b1 Exp $";






//
// SFX API
// Note: this was called by S_Init.
// However, whatever they did in the
// old DPMS based DOS version, this
// were simply dummies in the Linux
// version.
// See soundserver initdata().
//
void I_SetChannels()
{
}		

 
void I_SetSfxVolume(int volume)
{
}

// MUSIC API - dummy. Some code from DOS version.
void I_SetMusicVolume(int volume)
{
}


//
// Retrieve the raw data lump index
//	for a given SFX name.
//
int I_GetSfxLumpNum(sfxinfo_t* sfx)
{
}

//
// Starting a sound means adding it
//	to the current list of active sounds
//	in the internal channels.
// As the SFX info struct contains
//	e.g. a pointer to the raw data,
//	it is ignored.
// As our sound handling does not handle
//	priority, it is ignored.
// Pitching (that is, increased speed of playback)
//	is set, but currently not used by mixing.
//
int
I_StartSound
( int			id,
  int			vol,
  int			sep,
  int			pitch,
  int			priority )
{
	return 0;
}



void I_StopSound (int handle)
{
}


int I_SoundIsPlaying(int handle)
{
}




//
// This function loops all active (internal) sound
//	channels, retrieves a given number of samples
//	from the raw sound data, modifies it according
//	to the current (internal) channel parameters,
//	mixes the per channel samples into the global
//	mixbuffer, clamping it to the allowed range,
//	and sets up everything for transferring the
//	contents of the mixbuffer to the (two)
//	hardware channels (left and right, that is).
//
// This function currently supports only 16bit.
//
void I_UpdateSound( void )
{
}


// 
// This would be used to write out the mixbuffer
//	during each game loop update.
// Updates sound buffer and audio device at runtime. 
// It is called during Timer interrupt with SNDINTR.
// Mixing now done synchronous, and
//	only output be done asynchronous?
//
void
I_SubmitSound(void)
{
}



void
I_UpdateSoundParams
( int	handle,
  int	vol,
  int	sep,
  int	pitch)
{
}




void I_ShutdownSound(void)
{	 
}

void
I_InitSound()
{ 
}




//
// MUSIC API.
// Still no music done.
// Remains. Dummies.
//
void I_InitMusic(void)			{ }
void I_ShutdownMusic(void)		{ }

void I_PlaySong(int handle, int looping)
{
}

void I_PauseSong (int handle)
{
}

void I_ResumeSong (int handle)
{
}

void I_StopSong(int handle)
{
}

void I_UnRegisterSong(int handle)
{
}

int I_RegisterSong(void* data)
{
}

// Is the song playing?
int I_QrySongPlaying(int handle)
{
	return 1;
}



void I_HandleSoundTimer( int ignore )
{
}

// Get the interrupt. Set duration in millisecs.
int I_SoundSetTimer( int duration_of_tick )
{
	return 0;
}


// Remove the interrupt. Set duration to zero.
void I_SoundDelTimer()
{
}
