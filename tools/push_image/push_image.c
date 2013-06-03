// 
// Copyright 2012-2013 Jeff Bush
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
