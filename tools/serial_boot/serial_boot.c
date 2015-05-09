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

//
// Loads file over the serial port into memory on the FPGA board.  This 
// communicates with the first stage bootloader in software/bootloader.
// The format is that expected by the Verilog system task $readmemh:
// each line is a 32 bit hexadecimal value.
//

#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/fcntl.h>
#include <sys/time.h>
#include <termios.h>
#include <unistd.h>

#define BLOCK_SIZE 1024
#define PROGRESS_BAR_WIDTH 40

// This must match the enum in software/bootloader/boot.c
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

int open_serial_port(const char *path)
{
	struct termios serialopts;
	int serial_fd;

	serial_fd = open(path, O_RDWR | O_NOCTTY);
	if (serial_fd < 0)
	{
		perror("couldn't open serial port");
		return -1;
	}
	
	// Configure serial options
	if (tcgetattr(serial_fd, &serialopts) != 0)
	{
		perror("Unable to get serial port options");
		return -1;
	}
	
	serialopts.c_cflag = CSTOPB | CS8 | CLOCAL | CREAD;
	cfmakeraw(&serialopts);
	cfsetspeed(&serialopts, B115200);

	if (tcsetattr(serial_fd, TCSANOW, &serialopts) != 0)
	{
		perror("Unable to initialize serial port");
		return -1;
	}
	
	// Clear out any junk that may already be buffered in the 
	// serial driver (otherwise the ping sequence may fail)
	tcflush(serial_fd, TCIOFLUSH);

	return serial_fd;
}

// Returns 1 if the byte was read successfully, 0 if a timeout
// or other error occurred.
int read_serial_byte(int serial_fd, unsigned char *ch, int timeout_ms)
{	
	fd_set set;
	struct timeval tv;
	int ready_fds;

	FD_ZERO(&set);
	FD_SET(serial_fd, &set);

	tv.tv_sec = timeout_ms / 1000;
	tv.tv_usec = (timeout_ms % 1000) * 1000;

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
		return 0;
	}
	
	return 1;
}

int read_serial_long(int serial_fd, unsigned int *out, int timeout)
{
	unsigned int result = 0;
	unsigned char ch;
	int i;
	
	for (i = 0; i < 4; i++)
	{
		if (!read_serial_byte(serial_fd, &ch, timeout))
			return 0;

		result = (result >> 8) | (ch << 24);
	}
	
	*out = result;
	return 1;
}

int write_serial_byte(int serial_fd, unsigned int ch)
{
	if (write(serial_fd, &ch, 1) != 1)
	{
		perror("write");
		return 0;
	}

	return 1;
}

int write_serial_long(int serial_fd, unsigned int value)
{
	char out[4] = { value & 0xff, (value >> 8) & 0xff, (value >> 16) & 0xff,
		(value >> 24) & 0xff };
	
	if (write(serial_fd, out, 4) != 4)
	{
		perror("write");
		return 0;
	}

	return 1;
}

// XXX add error recovery
int send_buffer(int serial_fd, unsigned int address, const unsigned char *buffer, int length)
{
	unsigned int target_checksum;
	unsigned int local_checksum;
	int cksuma;
	int cksumb;
	unsigned char ch;
	int i;

	if (!write_serial_byte(serial_fd, kLoadDataReq))
		return 0;
	
	if (!write_serial_long(serial_fd, address))
		return 0;
	
	if (!write_serial_long(serial_fd, length))
		return 0;
	
	local_checksum = 0;
	cksuma = 0;
	cksumb = 0;

	if (write(serial_fd, buffer, length) != length)
	{
		fprintf(stderr, "\nError writing to serial port\n");
		return 0;
	}

	// wait for ack
	if (!read_serial_byte(serial_fd, &ch, 15000) || ch != kLoadDataAck)
	{
		fprintf(stderr, "\n%08x Did not get ack for load data\n", address);
		return 0;
	}

	for (i = 0; i < length; i++)
	{
		cksuma += buffer[i];
		cksumb += cksuma;
	}

	local_checksum = (cksuma & 0xffff) | ((cksumb & 0xffff) << 16);

	if (!read_serial_long(serial_fd, &target_checksum, 5000))
	{
		fprintf(stderr, "\n%08x timed out reading checksum\n", address);
		return 0;
	}

	if (target_checksum != local_checksum)
	{
		fprintf(stderr, "\n%08x checksum mismatch want %08x got %08x\n",
			address, local_checksum, target_checksum);
		return 0;
	}

	return 1;
}

int ping_target(int serial_fd)
{
	int retry;
	unsigned char ch;
	
	printf("ping target");

	int target_ready = 0;
	for (retry = 0; retry < 20; retry++)
	{
		printf(".");
		fflush(stdout);
		write_serial_byte(serial_fd, kPingReq);
		if (read_serial_byte(serial_fd, &ch, 250) && ch == kPingAck) 
		{
			target_ready = 1;
			break;
		}
	}
	
	if (!target_ready) 
	{ 
		printf("target is not responding\n");
		return 0;
	}
	
	printf("\n");
	
	return 1;
}

int send_execute_command(int serial_fd)
{
	unsigned char ch;
	
	write_serial_byte(serial_fd, kExecuteReq);
	if (!read_serial_byte(serial_fd, &ch, 15000) || ch != kExecuteAck)
	{
		fprintf(stderr, "Target returned error starting execution\n");
		return 0;
	}
	
	return 1;
}

void do_console_mode(int serial_fd)
{
	fd_set set;
	int ready_fds;
	char read_buffer[256];
	int got;

	while (1)
	{
		FD_ZERO(&set);
		FD_SET(serial_fd, &set);
		FD_SET(STDIN_FILENO, &set);	// stdin

		do 
		{
			ready_fds = select(FD_SETSIZE, &set, NULL, NULL, NULL);
		} 
		while (ready_fds < 0 && errno == EINTR);

		if (FD_ISSET(serial_fd, &set))
		{
			// Serial -> Terminal
			got = read(serial_fd, read_buffer, sizeof(read_buffer));
			if (got <= 0)
			{
				perror("read");
				return;
			}
			
			if (write(STDIN_FILENO, read_buffer, got) < got)
			{
				perror("write");
				return;
			}
		}
		
		if (FD_ISSET(STDIN_FILENO, &set))
		{
			// Terminal -> Serial
			got = read(STDIN_FILENO, read_buffer, sizeof(read_buffer));
			if (got <= 0)
			{
				perror("read");
				return;
			}
			
			if (write(serial_fd, read_buffer, got) != got)
			{
				perror("write");
				return;
			}
		}	
	}
}

int read_hex_file(const char *filename, unsigned char **out_ptr, int *out_length)
{
	FILE *input_file;
	char line[128];
	int offset = 0;
	unsigned char *data;
	int file_length;

	input_file = fopen(filename, "r");
	if (!input_file) 
	{
		fprintf(stderr, "Error opening input file\n");
		return 0;
	}

	fseek(input_file, 0, SEEK_END);
	file_length = ftell(input_file);
	fseek(input_file, 0, SEEK_SET);
	
	// This may overestimate the size a bit, which is fine.
	data = malloc(file_length / 2);
	while (fgets(line, sizeof(line), input_file)) 
	{
		unsigned int value = strtoul(line, NULL, 16);
		data[offset++] = (value >> 24) & 0xff;
		data[offset++] = (value >> 16) & 0xff;
		data[offset++] = (value >> 8) & 0xff;
		data[offset++] = value & 0xff;
	}
	
	*out_ptr = data;
	*out_length = offset;
	fclose(input_file);
	
	return 1;
}

void print_progress_bar(int current, int total)
{
	int numTicks = current * PROGRESS_BAR_WIDTH / total;
	int i;

	printf("\rLoading [");
	for (i = 0; i < numTicks; i++)
		printf("=");

	for (; i < PROGRESS_BAR_WIDTH; i++)
		printf(" ");
	
	printf("] (%d%%)", current * 100 / total);
	fflush(stdout);
}

int main(int argc, const char *argv[])
{
	unsigned char *data;
	int dataLen;
	int address;
	int serial_fd;
	
	if (argc < 3)
	{
		fprintf(stderr, "Incorrect number of arguments.  Need <serial port name> <hex file>\n");
		return 1;
	}

	if (!read_hex_file(argv[2], &data, &dataLen))
		return 1;
	
	serial_fd = open_serial_port(argv[1]);
	if (serial_fd < 0)
		return 1;

	if (!ping_target(serial_fd))
		return 1;

	printf("Loading %d bytes\n", dataLen);

	print_progress_bar(0, dataLen);
	for (address = 0; address < dataLen; address += BLOCK_SIZE)
	{
		int thisSlice = dataLen - address;
		if (thisSlice > BLOCK_SIZE)
			thisSlice = BLOCK_SIZE;

		if (!send_buffer(serial_fd, address, data + address, thisSlice))
			return 1;

		print_progress_bar(address + thisSlice, dataLen);
	}
	
	printf("\nProgram loaded, executing\n");

	if (!send_execute_command(serial_fd))
		return 1;
	
	printf("Program is running, entering console mode\n");
	
	do_console_mode(serial_fd);
	
	return 0;
}
