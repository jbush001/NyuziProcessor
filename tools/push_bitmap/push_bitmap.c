// 
// Copyright (C) 2011-2014 Jeff Bush
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

#include <stdio.h>
#include <sys/fcntl.h>
#include <termios.h>

//
// Transfer a binary file over the serial port to the FPGA board
//

int main(int argc, const char *argv[])
{
	int serialFD;
	int x;
	int y;
	unsigned short color;
	struct termios serialopts;
	FILE *imageFile;
	
	imageFile = fopen(argv[1], "rb");
	if (imageFile == NULL)
	{
		perror("couldn't open file");
		return 1;
	}
	
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
	
	serialopts.c_cflag = CS8 | CLOCAL | CREAD;
	cfmakeraw(&serialopts);
	cfsetspeed(&serialopts, B115200);

	if (tcsetattr(serialFD, TCSANOW, &serialopts) != 0)
	{
		perror("Unable to initialize serial port");
		return 1;
	}
	
	for (x = 0; x < 640 * 480; x++)
	{
		unsigned char triple[4];
		if (fread(triple, 3, 1, imageFile) <= 0)
		{
			perror("error reading file");
			break;
		}

		triple[3] = 0xFF;
		if (write(serialFD, triple, 4) != 4)
		{
			perror("write");
			break;
		}
	}	
	
	close(serialFD);
	return 0;
}
