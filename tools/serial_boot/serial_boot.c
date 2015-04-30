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
#include <sys/time.h>
#include <termios.h>
#include <unistd.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>

//
// Load an ELF binary over the serial port into memory on the FPGA board.  This 
// communicates with the first stage bootloader in software/bootloader
//

// This must match the enum in boot.c
enum Command
{
	kLoadDataReq = 0xc0,
	kLoadDataAck,
	kExecuteReq,
	kExecuteAck,
	kPingReq,
	kPingAck,
	kBadCommand
};

static int serial_fd = -1;

// Returns 1 if the byte was read successfully, 0 if a timeout
// or other error occurred.
int read_serial_byte(unsigned char *ch, int timeout)
{	
	fd_set set;
	struct timeval tv;
	int ready_fds;
     
	FD_ZERO(&set);
	FD_SET(serial_fd, &set);

	tv.tv_sec = timeout;
	tv.tv_usec = 0;

	do 
	{
		ready_fds = select(FD_SETSIZE, &set, NULL, NULL, &tv);
	} 
	while (ready_fds < 0 && errno == EINTR);

	if (ready_fds == 0)
		return 0;
	
	if (read(serial_fd, ch, 1) != 1)
	{
		perror("read");
		exit(1);
	}
	
	return 1;
}

int read_serial_long(unsigned int *out, int timeout)
{
	unsigned int result = 0;
	unsigned char ch;
	int i;
	
	for (i = 0; i < 4; i++)
	{
		if (!read_serial_byte(&ch, timeout))
			return 0;

		result = (result >> 8) | (ch << 24);
	}
	
	*out = result;
	return 1;
}

void write_serial_byte(unsigned int ch)
{
	if (write(serial_fd, &ch, 1) != 1)
	{
		perror("write");
		exit(1);
	}
}

void write_serial_long(unsigned int value)
{
	write_serial_byte(value & 0xff);
	write_serial_byte((value >> 8) & 0xff);
	write_serial_byte((value >> 16) & 0xff);
	write_serial_byte((value >> 24) & 0xff);
}

// XXX add error recovery

void send_buffer(unsigned int address, const unsigned char *buffer, int length)
{
	unsigned int target_checksum;
	unsigned int local_checksum;
	int cksuma;
	int cksumb;
	unsigned char ch;
	int i;

	write_serial_byte(kLoadDataReq);
	write_serial_long(address);
	write_serial_long(length);
	local_checksum = 0;
	cksuma = 0;
	cksumb = 0;

	if (write(serial_fd, buffer, length) != length)
	{
		fprintf(stderr, "\nError writing to serial port\n");
		exit(1);
	}

	// wait for ack
	if (!read_serial_byte(&ch, 15) || ch != kLoadDataAck)
	{
		fprintf(stderr, "\n%08x Did not get ack for load data\n", address);
		exit(1);
	}

	for (i = 0; i < length; i++)
	{
		cksuma += buffer[i];
		cksumb += cksuma;
	}

	local_checksum = (cksuma & 0xffff) | ((cksumb & 0xffff) << 16);

	if (!read_serial_long(&target_checksum, 5))
	{
		fprintf(stderr, "\n%08x timed out reading checksum\n", address);
		exit(1);
	}

	if (target_checksum != local_checksum)
	{
		fprintf(stderr, "\n%08x checksum mismatch want %08x got %08x\n",
			address, local_checksum, target_checksum);
		exit(1);
	}
}

int main(int argc, const char *argv[])
{
	struct termios serialopts;
	unsigned char buffer[1024];
	unsigned char ch;
	FILE *input_file;
	int target_ready;
	int send_buf_length = 0;
	char line[128];
	unsigned int address;
	int retry;
	
	if (argc < 3)
	{
		fprintf(stderr, "Incorrect number of arguments.  Need <serial port name> <elf image>\n");
		return 1;
	}
	
	serial_fd = open(argv[1], O_RDWR | O_NOCTTY);
	if (serial_fd < 0)
	{
		perror("couldn't open serial port");
		return 1;
	}
	
	if (tcgetattr(serial_fd, &serialopts) != 0)
	{
		perror("Unable to get serial port options");
		return 1;
	}
	
	serialopts.c_cflag = CSTOPB | CS8 | CLOCAL | CREAD;
	cfmakeraw(&serialopts);
	cfsetspeed(&serialopts, B115200);

	if (tcsetattr(serial_fd, TCSANOW, &serialopts) != 0)
	{
		perror("Unable to initialize serial port");
		return 1;
	}

	input_file = fopen(argv[2], "rb");
	if (!input_file) 
	{
		fprintf(stderr, "Error opening input file\n");
		return 1;
	}

	printf("ping target");

	// Make sure target is ready
	target_ready = 0;
	for (retry = 0; retry < 5; retry++)
	{
		printf(".");
		fflush(stdout);
		write_serial_byte(kPingReq);
		
		if (read_serial_byte(&ch, 1) && ch == kPingAck) 
		{
			target_ready = 1;
			break;
		}
	}
	
	if (!target_ready) 
	{ 
		printf("target is not responding\n");
		return 1;
	}

	printf("\nuploading program\n");

	address = 0;
	while (fgets(line, sizeof(line), input_file)) 
	{
		unsigned int value = strtoul(line, NULL, 16);
		buffer[send_buf_length++] = (value >> 24) & 0xff;
		buffer[send_buf_length++] = (value >> 16) & 0xff;
		buffer[send_buf_length++] = (value >> 8) & 0xff;
		buffer[send_buf_length++] = value & 0xff;
		
		if (send_buf_length == sizeof(buffer))
		{
			printf("#");
			fflush(stdout);

			send_buffer(address, buffer, send_buf_length);
			address += send_buf_length;
			send_buf_length = 0;
		}
	}

	if (send_buf_length > 0)
		send_buffer(address, buffer, send_buf_length);
	
	printf("program loaded, executing\n");

	// Send execute command
	write_serial_byte(kExecuteReq);
	if (!read_serial_byte(&ch, 15) || ch != kExecuteAck)
	{
		fprintf(stderr, "Target returned error starting execution\n");
		return 1;
	}

	printf("program is running\n");
	
	// Go into console mode, dump received bytes to stdout
	while (1)
	{
		read(serial_fd, &ch, 1);
		putchar(ch);
		fflush(stdout);
	}	

	return 0;
}
