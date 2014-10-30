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
#include <sys/time.h>
#include <termios.h>
#include <unistd.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include "elf.h"

//
// Load an ELF binary over the serial port into memory on the FPGA board.  This 
// communicates with the first stage bootloader in software/bootloader
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

int main(int argc, const char *argv[])
{
	struct termios serialopts;
	unsigned char buffer[1024];
	unsigned char ch;
	struct Elf32_Ehdr eheader;
	struct Elf32_Phdr *pheader;
	FILE *input_file;
	int segment;
	unsigned int target_checksum;
	unsigned int local_checksum;
	int cksuma;
	int cksumb;
	int i;
	int retry;
	int target_ready;
	
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
	
	serialopts.c_cflag = CSTOPB | CS8 | CLOCAL | CREAD;
	cfmakeraw(&serialopts);
	cfsetspeed(&serialopts, B115200);

	if (tcsetattr(serial_fd, TCSANOW, &serialopts) != 0)
	{
		perror("Unable to initialize serial port");
		return 1;
	}

	input_file = fopen(argv[1], "rb");
	if (!input_file) 
	{
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

	if (eheader.e_machine != EM_NYUZI) 
	{
		fprintf(stderr, "Incorrect architecture\n");
		return 1;
	}

	if (eheader.e_phoff == 0) 
	{
		fprintf(stderr, "File has no program header\n");
		return 1;
	}
	
	pheader = (struct Elf32_Phdr*) calloc(sizeof(struct Elf32_Phdr), eheader.e_phnum);
	if (fseek(input_file, eheader.e_phoff, SEEK_SET) != 0)
		perror("fseek returned error");

	int got = fread(pheader, sizeof(struct Elf32_Phdr), eheader.e_phnum, input_file);
	if (got != eheader.e_phnum) 
	{
		perror("error reading program header");
		return 1;
	}
	
	printf("ping target\n");

	// Make sure target is ready
	target_ready = 0;
	for (retry = 0; retry < 5; retry++)
	{
		write_serial_byte(kPingReq);
		if (read_serial_byte(&ch, 1) && ch == kPingAck) 
		{
			target_ready = 1;
			break;
		}
	}
	
	if (!target_ready) { 
		printf("target is not responding\n");
		return 1;
	}
	
	for (segment = 0; segment < eheader.e_phnum; segment++) 
	{
		if (pheader[segment].p_type == PT_LOAD) 
		{
			if (pheader[segment].p_filesz > 0)
			{
				printf("Segment %d loading %08x-%08x ", segment, pheader[segment].p_vaddr, 
					pheader[segment].p_vaddr + pheader[segment].p_filesz);
				write_serial_byte(kLoadDataReq);
				write_serial_long(pheader[segment].p_vaddr);
				write_serial_long(pheader[segment].p_filesz);
				fseek(input_file, pheader[segment].p_offset, SEEK_SET);
				int remaining = pheader[segment].p_filesz;
				local_checksum = 0;
				cksuma = 0;
				cksumb = 0;
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
						fprintf(stderr, "\nError writing to serial port\n");
						return 1;
					}

					for (i = 0; i < slice_length; i++)
					{
						cksuma += buffer[i];
						cksumb += cksuma;
					}

					remaining -= slice_length;

					printf(".");
					fflush(stdout);
				}

				local_checksum = (cksuma & 0xffff) | ((cksumb & 0xffff) << 16);
				printf("\n");

				// wait for ack
				if (!read_serial_byte(&ch, 15) || ch != kLoadDataAck)
				{
					fprintf(stderr, "Did not get ack for load data\n");
					return 1;
				}

				if (!read_serial_long(&target_checksum, 5))
				{
					fprintf(stderr, "Timed out reading checksum\n");
					return 1;
				}
				
				if (target_checksum != local_checksum)
				{
					fprintf(stderr, "Checksum mismatch want %08x got %08x\n",
						local_checksum, target_checksum);
					return 1;
				}
				
				printf("Checksum is okay: %08x\n", target_checksum);
			}

			if (pheader[segment].p_memsz > pheader[segment].p_filesz)
			{
				printf("Clearing %08x-%08x\n", pheader[segment].p_vaddr + pheader[segment].p_filesz,
					pheader[segment].p_vaddr + pheader[segment].p_memsz);
				write_serial_byte(kClearRangeReq);
				write_serial_long(pheader[segment].p_vaddr + pheader[segment].p_filesz);
				write_serial_long(pheader[segment].p_memsz - pheader[segment].p_filesz);
				if (!read_serial_byte(&ch, 15) || ch != kClearRangeAck)
				{
					fprintf(stderr, "Error clearing memory\n");
					return 1;
				}
			}
		}
	}

	printf("program loaded, jumping to entry @%08x\n", eheader.e_entry);
	
	// Send execute command
	write_serial_byte(kExecuteReq);
	write_serial_long(eheader.e_entry);
	if (!read_serial_byte(&ch, 15) || ch != kExecuteAck)
	{
		fprintf(stderr, "Target returned error starting execution\n");
		return 1;
	}

	printf("Done\n");
	close(serial_fd);

	return 0;
}
