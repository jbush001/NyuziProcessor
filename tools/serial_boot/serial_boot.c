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
// It expects the memory file to be in the format used by the Verilog
// system task $readmemh: each line is a 32 bit hexadecimal value.
// This may optionally also take a binary ramdisk image to load at 0x4000000.
//

#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/fcntl.h>
#include <sys/time.h>
#include <termios.h>
#include <unistd.h>
#include "../../software/bootrom/protocol.h"

#define DEFAULT_UART_BAUD 921600
#define RAMDISK_BASE 0x4000000
#define BLOCK_SIZE 1024
#define PROGRESS_BAR_WIDTH 40

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
    memset(&serialopts, 0, sizeof(serialopts));
    serialopts.c_cflag = CS8 | CLOCAL | CREAD;
    cfsetspeed(&serialopts, DEFAULT_UART_BAUD);
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

        result = (result >> 8) | ((unsigned int) ch << 24);
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
    unsigned char out[4] =
    {
        value & 0xff,
        (value >> 8) & 0xff,
        (value >> 16) & 0xff,
        (value >> 24) & 0xff
    };

    if (write(serial_fd, out, 4) != 4)
    {
        perror("write");
        return 0;
    }

    return 1;
}

int fill_memory(int serial_fd, unsigned int address, const unsigned char *buffer, unsigned int length)
{
    unsigned int target_checksum;
    unsigned int local_checksum;
    unsigned char ch;
    unsigned int i;

    if (!write_serial_byte(serial_fd, LOAD_MEMORY_REQ))
        return 0;

    if (!write_serial_long(serial_fd, address))
        return 0;

    if (!write_serial_long(serial_fd, length))
        return 0;

    if (write(serial_fd, buffer, length) != length)
    {
        fprintf(stderr, "\n_error writing to serial port\n");
        return 0;
    }

    // wait for ack
    if (!read_serial_byte(serial_fd, &ch, 15000))
    {
        fprintf(stderr, "\n%08x Did not get ack for load memory\n", address);
        return 0;
    }
    else if (ch != LOAD_MEMORY_ACK)
    {
        fprintf(stderr, "\n%08x Did not get ack for load memory, got %02x instead\n", address, ch);
        return 0;
    }

    // Compute FNV-1a hash
    local_checksum = 2166136261;
    for (i = 0; i < length; i++)
        local_checksum = (local_checksum ^ buffer[i]) * 16777619;

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

// An error has occurred. Resyncronize so we can retry the command.
int fix_connection(int serial_fd)
{
    unsigned char ch = 0;
    int chars_read = 0;
    int ping_seen = 0;
    int retry = 0;

    // Clear out any waiting BAD_COMMAND bytes
    // May grab an extra byte
    while (read_serial_byte(serial_fd, &ch, 250) && ch == BAD_COMMAND)
        chars_read++;

    printf("%d BAD_COMMAND bytes seen, last was %02x\n", chars_read, ch);

    // Send pings until the processor responds
    // This can help if the processor is expecting data from us
    while (1)
    {
        if (read_serial_byte(serial_fd, &ch, 25))
        {
            if (ping_seen)
                continue; // Once you've seen one ping, ignore the rest
            else if (ch == PING_ACK)
            {
                printf("Ping return seen.\n");
                ping_seen = 1;
            }
            else
                printf("byte read: %02x\n", ch);
        }
        else
        {
            // If there's no more data, and we've seen one ping,
            // we're done here.
            if (ping_seen)
                return 1;
        }

        if (!ping_seen)
        {
            retry++;
            if (!write_serial_byte(serial_fd, PING_REQ))
                return 0;
        }

        if (retry > 40)
        {
            printf("Cannot fix connection, no ping from board recieved.\n");
            printf("Try resetting the board (KEY0) and rerunning.\n");
            return 0;
        }
    }
}

int clear_memory(int serial_fd, unsigned int address, unsigned int length)
{
    unsigned char ch;

    if (!write_serial_byte(serial_fd, CLEAR_MEMORY_REQ))
        return 0;

    if (!write_serial_long(serial_fd, address))
        return 0;

    if (!write_serial_long(serial_fd, length))
        return 0;

    // wait for ack
    if (!read_serial_byte(serial_fd, &ch, 15000) || ch != CLEAR_MEMORY_ACK)
    {
        fprintf(stderr, "\n%08x Did not get ack for clear memory\n", address);
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
        write_serial_byte(serial_fd, PING_REQ);
        if (read_serial_byte(serial_fd, &ch, 250) && ch == PING_ACK)
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

    write_serial_byte(serial_fd, EXECUTE_REQ);
    if (!read_serial_byte(serial_fd, &ch, 15000) || ch != EXECUTE_ACK)
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
    ssize_t got;

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

            if (write(STDIN_FILENO, read_buffer, (unsigned int) got) < got)
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

            if (write(serial_fd, read_buffer, (unsigned int) got) != got)
            {
                perror("write");
                return;
            }
        }
    }
}

int read_hex_file(const char *filename, unsigned char **out_ptr, unsigned int *out_length)
{
    FILE *input_file;
    char line[16];
    unsigned int offset = 0;
    unsigned char *data;
    unsigned int file_length;

    input_file = fopen(filename, "r");
    if (!input_file)
    {
        perror("Error opening input file\n");
        return 0;
    }

    fseek(input_file, 0, SEEK_END);
    file_length = (unsigned int) ftell(input_file);
    fseek(input_file, 0, SEEK_SET);

    // This may overestimate the size a bit, which is fine.
    data = malloc(file_length / 2);
    while (fgets(line, sizeof(line), input_file))
    {
        unsigned int value = (unsigned int) strtoul(line, NULL, 16);
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

int read_binary_file(const char *filename, unsigned char **out_ptr, unsigned int *out_length)
{
    FILE *input_file;
    unsigned char *data;
    unsigned int file_length;

    input_file = fopen(filename, "r");
    if (!input_file)
    {
        perror("Error opening input file");
        return 0;
    }

    fseek(input_file, 0, SEEK_END);
    file_length = (unsigned int) ftell(input_file);
    fseek(input_file, 0, SEEK_SET);

    data = malloc(file_length);
    if (fread(data, file_length, 1, input_file) != 1)
    {
        perror("Error reading file");
        fclose(input_file);
        free(data);
        return 0;
    }

    *out_ptr = data;
    *out_length = file_length;
    fclose(input_file);

    return 1;
}

void print_progress_bar(unsigned int current, unsigned int total)
{
    unsigned int num_ticks = current * PROGRESS_BAR_WIDTH / total;
    unsigned int i;

    printf("\r_loading [");
    for (i = 0; i < num_ticks; i++)
        printf("=");

    for (; i < PROGRESS_BAR_WIDTH; i++)
        printf(" ");

    printf("] (%u%%)", current * 100 / total);
    fflush(stdout);
}

static int is_empty(unsigned char *data, unsigned int length)
{
    int empty;
    unsigned int i;

    empty = 1;
    for (i = 0; i < length; i++)
    {
        if (data[i] != 0)
        {
            empty = 0;
            break;
        }
    }

    return empty;
}

int send_file(int serial_fd, unsigned int address, unsigned char *data, unsigned int data_length)
{
    unsigned int offset = 0;

    print_progress_bar(0, data_length);
    while (offset < data_length)
    {
        int copied_correctly = 1;
        unsigned int this_slice = data_length - offset;
        if (this_slice > BLOCK_SIZE)
            this_slice = BLOCK_SIZE;

        if (is_empty(data + offset, this_slice))
        {
            if (!clear_memory(serial_fd, address + offset, this_slice))
                return 0;
        }
        else
        {
            if (!fill_memory(serial_fd, address + offset, data + offset, this_slice))
            {
                copied_correctly = 0;
                if (!fix_connection(serial_fd))
                {
                    return 0;
                }
            }
        }
        if (copied_correctly)
        {
            offset += this_slice;
        }
        print_progress_bar(offset, data_length);
    }

    return 1;
}

int main(int argc, const char *argv[])
{
    unsigned char *program_data;
    unsigned int program_length;
    unsigned char *ramdisk_data = NULL;
    unsigned int ramdisk_length = 0;
    int serial_fd;

    if (argc < 3)
    {
        fprintf(stderr, "USAGE:\n    serial_boot <serial port name> <hex file> [<ramdisk image>]\n");
        return 1;
    }

    if (!read_hex_file(argv[2], &program_data, &program_length))
        return 1;

    if (argc == 4)
    {
        // Load binary ramdisk image
        if (!read_binary_file(argv[3], &ramdisk_data, &ramdisk_length))
            return 1;
    }

    serial_fd = open_serial_port(argv[1]);
    if (serial_fd < 0)
        return 1;

    if (!ping_target(serial_fd))
        return 1;

    printf("Program is %u bytes\n", program_length);
    if (!send_file(serial_fd, 0, program_data, program_length))
        return 1;

    if (ramdisk_data)
    {
        printf("\n_ramdisk is %u bytes\n", ramdisk_length);
        if (!send_file(serial_fd, RAMDISK_BASE, ramdisk_data, ramdisk_length))
            return 1;
    }

    if (!send_execute_command(serial_fd))
        return 1;

    printf("\n_program running, entering console mode\n");

    do_console_mode(serial_fd);

    return 0;
}
