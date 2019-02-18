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

#include <ctype.h>
#include <errno.h>
#include <stdbool.h>
#include <string.h>
#include <stdint.h>
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
#define MIN_SEGMENT_ALLOC 1024

struct segment {
    struct segment *next;
    unsigned int address;
    unsigned char *data;
    int length;
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

// Returns true if the byte was read successfully, false if a timeout
// or other error occurred.
bool read_serial_byte(int serial_fd, unsigned char *ch, int timeout_ms)
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
        return false;

    if (read(serial_fd, ch, 1) != 1)
    {
        perror("read");
        return false;
    }

    return true;
}

bool read_serial_long(int serial_fd, unsigned int *out, int timeout)
{
    unsigned int result = 0;
    unsigned char ch;
    int i;

    for (i = 0; i < 4; i++)
    {
        if (!read_serial_byte(serial_fd, &ch, timeout))
            return false;

        result = (result >> 8) | ((unsigned int) ch << 24);
    }

    *out = result;
    return true;
}

bool write_serial_byte(int serial_fd, unsigned int ch)
{
    if (write(serial_fd, &ch, 1) != 1)
    {
        perror("write");
        return false;
    }

    return true;
}

bool write_serial_long(int serial_fd, unsigned int value)
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
        return false;
    }

    return true;
}

bool load_memory(int serial_fd, unsigned int address, const unsigned char *buffer, unsigned int length)
{
    unsigned int target_checksum;
    unsigned int local_checksum;
    unsigned char ch;
    unsigned int i;

    if (!write_serial_byte(serial_fd, LOAD_MEMORY_REQ))
        return false;

    if (!write_serial_long(serial_fd, address))
        return false;

    if (!write_serial_long(serial_fd, length))
        return false;

    if (write(serial_fd, buffer, length) != length)
    {
        fprintf(stderr, "\nError writing to serial port\n");
        return false;
    }

    // wait for ack
    if (!read_serial_byte(serial_fd, &ch, 15000))
    {
        fprintf(stderr, "\n%08x Did not get ack for load memory\n", address);
        return false;
    }
    else if (ch != LOAD_MEMORY_ACK)
    {
        fprintf(stderr, "\n%08x Did not get ack for load memory, got %02x instead\n", address, ch);
        return false;
    }

    // Compute FNV-1a hash
    local_checksum = 2166136261;
    for (i = 0; i < length; i++)
        local_checksum = (local_checksum ^ buffer[i]) * 16777619;

    if (!read_serial_long(serial_fd, &target_checksum, 5000))
    {
        fprintf(stderr, "\n%08x timed out reading checksum\n", address);
        return false;
    }

    if (target_checksum != local_checksum)
    {
        fprintf(stderr, "\n%08x checksum mismatch want %08x got %08x\n",
                address, local_checksum, target_checksum);
        return false;
    }

    return true;
}

bool clear_memory(int serial_fd, unsigned int address, unsigned int length)
{
    unsigned char ch;

    if (!write_serial_byte(serial_fd, CLEAR_MEMORY_REQ))
        return false;

    if (!write_serial_long(serial_fd, address))
        return false;

    if (!write_serial_long(serial_fd, length))
        return false;

    // wait for ack
    if (!read_serial_byte(serial_fd, &ch, 15000) || ch != CLEAR_MEMORY_ACK)
    {
        fprintf(stderr, "\n%08x Did not get ack for clear memory\n", address);
        return false;
    }

    return true;
}

bool ping_target(int serial_fd)
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
        fprintf(stderr, "target is not responding\n");
        return false;
    }

    printf("\n");

    return true;
}

// An error has occurred. Resynchronize so we can retry the command.
bool fix_connection(int serial_fd)
{
    unsigned char ch = 0;
    int chars_read = 0;
    bool ping_seen = false;
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
                ping_seen = true;
            }
            else
                printf("byte read: %02x\n", ch);
        }
        else
        {
            // If there's no more data, and we've seen one ping,
            // we're done here.
            if (ping_seen)
                return true;
        }

        if (!ping_seen)
        {
            retry++;
            if (!write_serial_byte(serial_fd, PING_REQ))
                return false;
        }

        if (retry > 40)
        {
            printf("Cannot fix connection, no ping from board received.\n");
            printf("Try resetting the board (KEY0) and rerunning.\n");
            return false;
        }
    }
}

bool send_execute_command(int serial_fd)
{
    unsigned char ch;

    write_serial_byte(serial_fd, EXECUTE_REQ);
    if (!read_serial_byte(serial_fd, &ch, 15000) || ch != EXECUTE_ACK)
    {
        fprintf(stderr, "Target returned invalid response starting execution\n");
        return false;
    }

    return true;
}

void do_console_mode(int serial_fd)
{
    fd_set set;
    int ready_fds;
    char read_buffer[256];
    ssize_t got;
    int i;
    int done = 0;

    while (!done)
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

            // A ^D will terminate the exit console mode.
            for (i = 0; i < got; i++)
                if (read_buffer[i] == 4)
                    done = 1;

            if (write(STDOUT_FILENO, read_buffer, (unsigned int) got) < got)
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

void append_to_segment(struct segment *seg, unsigned int value)
{
    if (seg->length == 0 || seg->length == MIN_SEGMENT_ALLOC
        || (seg->length & (seg->length - 1)) == 0) {
        int new_size = seg->length < MIN_SEGMENT_ALLOC ? MIN_SEGMENT_ALLOC : seg->length * 2;
        seg->data = (unsigned char*) realloc(seg->data, new_size);
    }

    seg->data[seg->length++] = value >> 24;
    seg->data[seg->length++] = (value >> 16) & 0xff;
    seg->data[seg->length++] = (value >> 8) & 0xff;
    seg->data[seg->length++] = value & 0xff;
}

inline uint32_t hex_digit_val(char ch) {
    if (ch >= '0' && ch <= '9')
        return (uint32_t) (ch - '0');
    else if (ch >= 'a' && ch <= 'f')
        return (uint32_t) (ch - 'a' + 10);
    else if (ch >= 'A' && ch <= 'F')
        return (uint32_t) (ch - 'A' + 10);
    else
        return UINT32_MAX;
}

//
// Format is defined in IEEE 1364-2001, section 17.2.8
//
struct segment *read_hex_file(const char *filename)
{
    FILE *file;
    int line_num = 1;
    uint32_t number_value;
    int push_back_char = -1;
    bool done = false;
    struct segment *segments;
    struct segment *current_segment;

    enum
    {
        SCAN_SPACE,
        SCAN_SLASH,
        SCAN_ADDRESS,
        SCAN_NUMBER,
        SCAN_MULTI_LINE_COMMENT,
        SCAN_ASTERISK,
        SCAN_SINGLE_LINE_COMMENT
    } state = SCAN_SPACE;

    file = fopen(filename, "r");
    if (file == NULL)
    {
        perror("read_hex_file: error opening hex file");
        return NULL;
    }

    segments = current_segment = (struct segment*) calloc(sizeof(struct segment), 1);

    while (!done) {
        int ch;
        if (push_back_char != -1)
        {
            ch = push_back_char;
            push_back_char = -1;
        }
        else
            ch = fgetc(file);

        switch (state)
        {
            case SCAN_SPACE:
                if (ch == EOF)
                    done = true;
                else if (ch == '/')
                    state = SCAN_SLASH;
                else if (ch == '@')
                {
                    state = SCAN_ADDRESS;
                    number_value = 0;
                }
                else if (isxdigit(ch))
                {
                    number_value = hex_digit_val(ch);
                    state = SCAN_NUMBER;
                }
                else if (!isspace(ch))
                {
                    fprintf(stderr, "read_hex_file: Invalid character %c in line %d\n", ch, line_num);
                    fclose(file);
                    return NULL;
                } else if (ch == '\n')
                    line_num++;

                break;

            case SCAN_SLASH:
                if (ch == '*')
                    state = SCAN_MULTI_LINE_COMMENT;
                else if (ch == '/')
                    state = SCAN_SINGLE_LINE_COMMENT;
                else
                {
                    fprintf(stderr, "read_hex_file: Invalid character %c in line %d\n", ch, line_num);
                    fclose(file);
                    return NULL;
                }

                break;

            case SCAN_SINGLE_LINE_COMMENT:
                if (ch == '\n') {
                    state = SCAN_SPACE;
                } else if (ch == EOF) {
                    done = true;
                }

                break;

            case SCAN_MULTI_LINE_COMMENT:
                if (ch == '*')
                    state = SCAN_ASTERISK;
                else if (ch == EOF)
                {
                    fprintf(stderr, "read_hex_file: Missing */ at end of file\n");
                    fclose(file);
                    return NULL;
                }

                break;

            case SCAN_ASTERISK:
                if (ch == '/')
                    state = SCAN_SPACE;
                else if (ch == EOF)
                {
                    fprintf(stderr, "read_hex_file: Missing */ at end of file\n");
                    fclose(file);
                    return NULL;
                }

                break;

            case SCAN_NUMBER:
                if (isxdigit(ch))
                {
                    if ((number_value & 0xf0000000) != 0)
                    {
                        fprintf(stderr, "read_hex_file: number out of range in line %d\n", line_num);
                        fclose(file);
                        return NULL;
                    }

                    number_value = (number_value << 4) | hex_digit_val(ch);
                }
                else
                {
                    append_to_segment(current_segment, number_value);
                    push_back_char = ch;
                    state = SCAN_SPACE;
                }

                break;

            case SCAN_ADDRESS:
                if (isxdigit(ch))
                    number_value = (number_value << 4) | hex_digit_val(ch);
                else
                {
                    push_back_char = ch;
                    state = SCAN_SPACE;

                    // If there is no content in the current segment, reuse it. Otherwise
                    // create a new one.
                    if (current_segment->length > 0) {
                        current_segment->next = (struct segment*) calloc(sizeof(struct segment), 1);
                        current_segment = current_segment->next;
                    }

                    current_segment->address = number_value * 4;
                }

                break;
        }
    }

    fclose(file);

    return segments;
}

bool read_binary_file(const char *filename, unsigned char **out_ptr, unsigned int *out_length)
{
    FILE *input_file;
    unsigned char *data;
    unsigned int file_length;

    input_file = fopen(filename, "r");
    if (!input_file)
    {
        perror("Error opening input file");
        return false;
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
        return false;
    }

    *out_ptr = data;
    *out_length = file_length;
    fclose(input_file);

    return true;
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

static bool is_empty(unsigned char *data, unsigned int length)
{
    bool empty;
    unsigned int i;

    empty = true;
    for (i = 0; i < length; i++)
    {
        if (data[i] != 0)
        {
            empty = false;
            break;
        }
    }

    return empty;
}

bool send_segment(int serial_fd, unsigned int address, unsigned char *data, unsigned int data_length)
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
                return false;
        }
        else
        {
            if (!load_memory(serial_fd, address + offset, data + offset, this_slice))
            {
                copied_correctly = 0;
                if (!fix_connection(serial_fd))
                {
                    return false;
                }
            }
        }
        if (copied_correctly)
        {
            offset += this_slice;
        }
        print_progress_bar(offset, data_length);
    }

    return true;
}

bool send_segments(int serial_fd, const struct segment *segments)
{
    const struct segment *current;
    for (current = segments; current; current = current->next) {
        if (!send_segment(serial_fd, current->address, current->data,
            current->length)) {
            return false;
        }
    }


    return true;
}

int main(int argc, const char *argv[])
{
    struct segment *program_data;
    unsigned char *ramdisk_data = NULL;
    unsigned int ramdisk_length = 0;
    int serial_fd;

    if (argc < 3)
    {
        fprintf(stderr, "USAGE:\n    serial_boot <serial port name> <hex file> [<ramdisk image>]\n");
        return 1;
    }

    program_data = read_hex_file(argv[2]);
    if (program_data == NULL)
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

    if (!send_segments(serial_fd, program_data))
        return 1;

    if (ramdisk_data)
    {
        printf("\n_ramdisk is %u bytes\n", ramdisk_length);
        if (!send_segment(serial_fd, RAMDISK_BASE, ramdisk_data, ramdisk_length))
            return 1;
    }

    if (!send_execute_command(serial_fd))
        return 1;

    printf("\n_program running, entering console mode\n");

    do_console_mode(serial_fd);

    return 0;
}
