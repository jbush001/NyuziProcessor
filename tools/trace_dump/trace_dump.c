// 
// Copyright 2011-2015 Jeff Bush
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
