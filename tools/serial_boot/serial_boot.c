// 
// Copyright 2014 Jeff Bush
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
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include "elf.h"

//
// Transfer a binary file over the serial port to the FPGA board
//

// This must match the enum in boot.c
enum Command
{
	kLoadDataReq = 0xc0,
	kLoadDataAck,
	kClearRangeReq,
	kClearRangeAck,
	kExecuteReq,
	kExecuteAck,
	kPingReq,
	kPingAck,
	kBadCommand
};

static int serial_fd = -1;

unsigned int read_serial_byte(void)
{
	unsigned char ch;
	
	if (read(serial_fd, &ch, 1) != 1)
	{
		perror("read");
		exit(1);
	}
	
	return ch;
}

void write_serial_byte(unsigned int ch)
{
	if (write(serial_fd, &ch, 1) != 1)
	{
		perror("write");
		exit(1);
	}
}

// XXX read serial should have a timeout
unsigned int read_serial_long(void)
{
	unsigned int result = 0;
	int i;
	
	for (i = 0; i < 4; i++)
		result = (result >> 8) | (read_serial_byte() << 24);

	return result;
}

void write_serial_long(unsigned int value)
{
	write_serial_byte(value & 0xff);
	write_serial_byte((value >> 8) & 0xff);
	write_serial_byte((value >> 16) & 0xff);
	write_serial_byte((value >> 24) & 0xff);
}

int main(int argc, const char *argv[])
{
	struct termios serialopts;
	char buffer[1024];
	int response;
	struct Elf32_Ehdr eheader;
	struct Elf32_Phdr *pheader;
	FILE *input_file;
	int segment;
	
	serial_fd = open("/dev/cu.usbserial", O_RDWR | O_NOCTTY);
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
	
	serialopts.c_cflag = CS8 | CLOCAL | CREAD;
	cfmakeraw(&serialopts);
	cfsetspeed(&serialopts, B115200);

	if (tcsetattr(serial_fd, TCSANOW, &serialopts) != 0)
	{
		perror("Unable to initialize serial port");
		return 1;
	}

	input_file = fopen(argv[1], "rb");
	if (!input_file) {
		fprintf(stderr, "Error opening input file\n");
		return 1;
	}

	if (fread(&eheader, sizeof(eheader), 1, input_file) != 1) 
	{
		fprintf(stderr, "Error reading header\n");
		return 1;
	}

	if (memcmp(eheader.e_ident, ELF_MAGIC, 4) != 0) 
	{
		fprintf(stderr, "Not an elf file\n");
		return 1;
	}

	if (eheader.e_machine != EM_VECTORPROC) 
	{
		fprintf(stderr, "Incorrect architecture\n");
		return 1;
	}

	if (eheader.e_phoff == 0) 
	{
		fprintf(stderr, "File has no program header\n");
		return 1;
	}

	pheader = (struct Elf32_Phdr *) calloc(sizeof(struct Elf32_Phdr), eheader.e_phnum);
	fseek(input_file, eheader.e_phoff, SEEK_SET);
	if (fread(pheader, sizeof(eheader), eheader.e_phnum, input_file) !=
		eheader.e_phnum) 
	{
		perror("error reading program header\n");
		return 1;
	}
	
	// Make sure target is ready
	write_serial_byte(kPingReq);
	response = read_serial_byte();
	if (response != kPingAck)
	{
		fprintf(stderr, "Target is not responding\n");
		return 1;
	}

	for (segment = 0; segment < eheader.e_phnum; segment++) 
	{
		if (pheader[segment].p_type == PT_LOAD) 
		{
			if (pheader[segment].p_filesz > 0)
			{
				write_serial_byte(kLoadDataReq);
				write_serial_long(pheader[segment].p_vaddr);
				write_serial_long(pheader[segment].p_filesz);

				fseek(input_file, pheader[segment].p_offset, SEEK_SET);
				int remaining = pheader[segment].p_filesz;
				while (remaining > 0)
				{
					int slice_length = remaining > sizeof(buffer) ? sizeof(buffer) : remaining;
					if (fread(buffer, slice_length, 1, input_file) != 1) 
					{
						perror("fread");
						return 1;
					}
					

					if (write(serial_fd, buffer, slice_length) != slice_length)
					{
						fprintf(stderr, "Error writing\n");
						return 1;
					}

					remaining -= slice_length;
				}
			}
			
			// wait for ack
			response = read_serial_byte();
			if (response != kLoadDataAck)
			{
				fprintf(stderr, "Target returned error loading data, segment %d\n", segment);
				return 1;
			}
			
			printf(".");
			fflush(stdout);

			if (pheader[segment].p_memsz > pheader[segment].p_filesz)
			{
				write_serial_byte(kClearRangeReq);
				write_serial_long(pheader[segment].p_vaddr + pheader[segment].p_memsz);
				write_serial_long(pheader[segment].p_memsz - pheader[segment].p_filesz);
				response = read_serial_byte();
				if (response != kClearRangeAck)
				{
					fprintf(stderr, "Target returned error clearing memory, segment %d\n", segment);
					return 1;
				}
			}
		}
	}

	close(serial_fd);

	// Send execute command
	write_serial_byte(kExecuteReq);
	write_serial_long(eheader.e_entry);

	response = read_serial_byte();
	if (response != kExecuteAck)
	{
		fprintf(stderr, "Target returned error starting execution\n");
		return 1;
	}

	return 0;
}
