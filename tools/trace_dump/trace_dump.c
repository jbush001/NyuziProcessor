// 
// Copyright (C) 2011-2014 Jeff Bush
// 
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Library General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
// 
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
// 
// You should have received a copy of the GNU Library General Public
// License along with this library; if not, write to the
// Free Software Foundation, Inc., 51 Franklin St, Fifth Floor,
// Boston, MA  02110-1301, USA.
// 

#include <stdio.h>
#include <sys/fcntl.h>
#include <termios.h>

//
// Reads binary data from serial port and prints in hex form to stdout.
// This is used for reading traces produced by the debug_trace hardware module.
//

int main(int argc, const char *argv[])
{
	int serialFD;
	struct termios serialopts;
	
	serialFD = open("/dev/cu.usbserial", O_RDWR | O_NOCTTY);
	if (serialFD < 0)
	{
		perror("couldn't open serial port");
		return 1;
	}
	
	if (tcgetattr(serialFD, &serialopts) != 0)
	{
		perror("Unable to get serial port options");
		return 1;
	}
	
	serialopts.c_cflag = CSTOPB | CS8 | CLOCAL | CREAD;
	cfmakeraw(&serialopts);
	cfsetspeed(&serialopts, B115200);

	if (tcsetattr(serialFD, TCSANOW, &serialopts) != 0)
	{
		perror("Unable to initialize serial port");
		return 1;
	}

	while (1)
	{
		unsigned char ch;
		read(serialFD, &ch, 1);
		printf("%02x\n", ch);
		fflush(stdout);
	}	

	close(serialFD);
	return 0;
}
