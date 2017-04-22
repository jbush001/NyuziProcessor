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

#include <arpa/inet.h>
#include <assert.h>
#include <errno.h>
#include <netinet/in.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdlib.h>
#include "processor.h"
#include "fbwindow.h"
#include "remote-gdb.h"
#include "util.h"

#define LOG_COMMANDS 0

#define TRAP_SIGNAL 5 // SIGTRAP

extern void check_interrupt_pipe(struct processor*);
static void __attribute__ ((format (printf, 1, 2))) send_formatted_response(const char *format, ...);

static int client_socket = -1;
static int *last_signals;
static const char *GENERIC_REGS[] = { "fp", "sp", "ra" };

static int read_byte(void)
{
    uint8_t ch;
    if (read(client_socket, &ch, 1) < 1)
    {
        perror("read_byte: error reading from debug socket");
        return -1;
    }

    return (int) ch;
}

static int read_packet(char *request, int max_length)
{
    int ch;
    int packet_len;

    // Wait for packet start
    do
    {
        ch = read_byte();
        if (ch < 0)
            return -1;
    }
    while (ch != '$');

    // Read body
    packet_len = 0;
    while (true)
    {
        ch = read_byte();
        if (ch < 0)
            return -1;

        if (ch == '#')
            break;

        if (packet_len < max_length)
            request[packet_len++] = (char) ch;
    }

    // Read checksum and discard
    read_byte();
    read_byte();

    request[packet_len] = '\0';

#if LOG_COMMANDS
    printf("GDB recv: %s\n", request);
#endif

    return packet_len;
}

static void send_response_packet(const char *response)
{
    uint8_t checksum;
    char checksum_chars[16];
    int i;
    size_t response_length = strlen(response);

#if LOG_COMMANDS
    printf("GDB send: %s\n", response);
#endif

    if (write(client_socket, "$", 1) < 1
            || write(client_socket, response, response_length) < (ssize_t) response_length
            || write(client_socket, "#", 1) < 1)
    {
        perror("send_response_packet: Error writing to debugger socket");
        exit(1);
    }

    checksum = 0;
    for (i = 0; response[i]; i++)
        checksum += response[i];

    sprintf(checksum_chars, "%02x", checksum);
    if (write(client_socket, checksum_chars, 2) < 2)
    {
        perror("send_response_packet: Error writing to debugger socket");
        exit(1);
    }
}

static void send_formatted_response(const char *format, ...)
{
    char buf[256];
    va_list args;
    va_start(args, format);
    vsnprintf(buf, sizeof(buf) - 1, format, args);
    va_end(args);
    send_response_packet(buf);
}

// thread_id of ALL_THREADS means run all threads.  Otherwise, run just the
// indicated thread.
static void run_until_interrupt(struct processor *proc, uint32_t thread_id, bool enable_fb_window)
{
    while (true)
    {
        if (!execute_instructions(proc, thread_id, screen_refresh_rate))
            break;

        if (enable_fb_window)
        {
            update_frame_buffer(proc);
            poll_fb_window_event();
            check_interrupt_pipe(proc);
        }

        // Break on error or if data is ready
        if (can_read_file_descriptor(client_socket))
            break;
    }
}

static uint8_t decode_hex_byte(const char *ptr)
{
    int i;
    int retval = 0;

    for (i = 0; i < 2; i++)
    {
        if (ptr[i] >= '0' && ptr[i] <= '9')
            retval = (retval << 4) | (ptr[i] - '0');
        else if (ptr[i] >= 'a' && ptr[i] <= 'f')
            retval = (retval << 4) | (ptr[i] - 'a' + 10);
        else if (ptr[i] >= 'A' && ptr[i] <= 'F')
            retval = (retval << 4) | (ptr[i] - 'A' + 10);
        else
            assert(0);	// Bad character
    }

    return (uint8_t) retval;
}

void remote_gdb_main_loop(struct processor *proc, bool enable_fb_window)
{
    int listen_socket;
    struct sockaddr_in address;
    socklen_t address_length;
    int got;
    char request[256];
    uint32_t i;
    bool no_ack_mode = false;
    int optval;
    char response[1024];
    uint32_t current_thread = 0;

    last_signals = calloc(sizeof(int), get_total_threads(proc));
    for (i = 0; i < get_total_threads(proc); i++)
        last_signals[i] = 0;

    listen_socket = socket(PF_INET, SOCK_STREAM, 0);
    if (listen_socket < 0)
    {
        perror("remote_gdb_main_loop: error setting up debug socket (socket)");
        return;
    }

    optval = 1;
    if (setsockopt(listen_socket, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof(optval)) < 0)
    {
        perror("remote_gdb_main_loop: error setting up debug socket (setsockopt)");
        return;
    }

    address.sin_family = AF_INET;
    address.sin_port = htons(8000);
    address.sin_addr.s_addr = htonl(INADDR_ANY);
    if (bind(listen_socket, (struct sockaddr*) &address, sizeof(address)) < 0)
    {
        perror("remote_gdb_main_loop: error setting up debug socket (bind)");
        return;
    }

    if (listen(listen_socket, 1) < 0)
    {
        perror("remote_gdb_main_loop: error setting up debug socket (listen)");
        return;
    }

    while (true)
    {
        // Wait for a new client socket
        while (true)
        {
            address_length = sizeof(address);
            client_socket = accept(listen_socket, (struct sockaddr*) &address,
                                   &address_length);
            if (client_socket >= 0)
                break;
        }

        no_ack_mode = false;

        // Process commands
        while (true)
        {
            got = read_packet(request, sizeof(request));
            if (got < 0)
                break;

            if (!no_ack_mode)
            {
                if (write(client_socket, "+", 1) != 1)
                {
                    perror("remote_gdb_main_loop: Error writing to debug socket");
                    exit(1);
                }
            }

            switch (request[0])
            {
                // Set arguments
                case 'A':
                    // Doesn't support setting program arguments, so just silently ignore.
                    send_response_packet("OK");
                    break;

                // Continue
                case 'c':
                case 'C':
                    run_until_interrupt(proc, ALL_THREADS, enable_fb_window);
                    last_signals[current_thread] = TRAP_SIGNAL;
                    send_formatted_response("S%02x", last_signals[current_thread]);
                    break;

                // Pick thread
                case 'H':
                {
                    uint32_t thid;

                    // XXX hack: the request type (request[1] controls which
                    // operations this applies for. I ignore it.

                    // Thread indices in GDB start at 1, but current_thread
                    // is zero based.
                    thid = (uint32_t) strtoul(request + 2, NULL, 16);
                    if (thid > get_total_threads(proc) || thid == 0)
                    {
                        send_response_packet("");
                        break;
                    }

                    current_thread = thid - 1;
                    send_response_packet("OK");
                    break;
                }

                // Kill
                case 'k':
                    return;

                // Read/write memory
                case 'm':
                case 'M':
                {
                    char *len_ptr;
                    char *data_ptr;
                    uint32_t start;
                    uint32_t length;
                    uint32_t offset;

                    start = (uint32_t) strtoul(request + 1, &len_ptr, 16);
                    length = (uint32_t) strtoul(len_ptr + 1, &data_ptr, 16);
                    if (request[0] == 'm')
                    {
                        // XXX May need dynamic allocation. At very least, buffer is too small.
                        if (length > sizeof(response) / 2)
                        {
                            printf("memory read of %d requested\n", length);
                            assert(0);
                        }

                        // Read memory
                        for (offset = 0; offset < length; offset++)
                            sprintf(response + offset * 2, "%02x", dbg_read_memory_byte(proc, start + offset));

                        send_response_packet(response);
                    }
                    else
                    {
                        // Write memory
                        data_ptr += 1;	// Skip colon
                        for (offset = 0; offset < length; offset++)
                            dbg_write_memory_byte(proc, start + offset, decode_hex_byte(data_ptr + offset * 2));

                        send_response_packet("OK");
                    }

                    break;
                }

                // Read register
                case 'p':
                case 'g':
                {
                    uint32_t reg_id = (uint32_t) strtoul(request + 1, NULL, 16);
                    uint32_t value;
                    if (reg_id < 32)
                    {
                        // Scalar register
                        value = dbg_get_scalar_reg(proc, current_thread, reg_id);
                        send_formatted_response("%08x", endian_swap32(value));
                    }
                    else if (reg_id < 64)
                    {
                        // Vector register
                        int lane_idx;
                        uint32_t values[NUM_VECTOR_LANES];

                        dbg_get_vector_reg(proc, current_thread, reg_id - 32, values);
                        for (lane_idx = 0; lane_idx < NUM_VECTOR_LANES; lane_idx++)
                        {
                            sprintf(response + lane_idx * 8, "%08x",
                                endian_swap32(values[lane_idx]));
                        }

                        send_response_packet(response);
                    }
                    else if (reg_id == 64)
                    {
                        // program counter
                        value = dbg_get_pc(proc, current_thread);
                        send_formatted_response("%08x", endian_swap32(value));
                    }
                    else
                        send_response_packet("");

                    break;
                }

                // Write register
                case 'G':
                {
                    char *data_ptr;
                    uint32_t reg_id = (uint32_t) strtoul(request + 1, &data_ptr, 16);

                    if (reg_id < 32)
                    {
                        // Scalar register
                        uint32_t reg_value = (uint32_t) strtoul(data_ptr + 1, NULL, 16);
                        dbg_set_scalar_reg(proc, current_thread, reg_id, endian_swap32(reg_value));
                        send_response_packet("OK");
                    }
                    else if (reg_id < 64)
                    {
                        // Vector register
                        uint32_t reg_value[NUM_VECTOR_LANES];

                        if (parse_hex_vector(data_ptr + 1, reg_value, true) < 0)
                            send_response_packet("");
                        else
                        {
                            dbg_set_vector_reg(proc, current_thread, reg_id - 32, reg_value);
                            send_response_packet("OK");
                        }
                    }
                    else
                        send_response_packet("");

                    break;
                }

                // Query
                case 'q':
                    if (strcmp(request + 1, "LaunchSuccess") == 0)
                        send_response_packet("OK");
                    else if (strcmp(request + 1, "HostInfo") == 0)
                        send_response_packet("triple:nyuzi;endian:little;ptrsize:4");
                    else if (strcmp(request + 1, "ProcessInfo") == 0)
                        send_response_packet("pid:1");
                    else if (strcmp(request + 1, "fThreadInfo") == 0)
                    {
                        uint32_t num_threads = get_total_threads(proc);
                        int offset = 2;

                        strcpy(response, "m1");
                        for (i = 2; i <= num_threads && offset < (int) sizeof(response); i++)
                        {
                            offset += snprintf(response + offset, sizeof(response)
                                               - (size_t) offset, ",%d", i);
                        }

                        send_response_packet(response);
                    }
                    else if (strcmp(request + 1, "sThreadInfo") == 0)
                        send_response_packet("l");
                    else if (memcmp(request + 1, "ThreadStopInfo", 14) == 0)
                        send_formatted_response("S%02x", last_signals[current_thread]);
                    else if (memcmp(request + 1, "RegisterInfo", 12) == 0)
                    {
                        uint32_t reg_id = (uint32_t) strtoul(request + 13, NULL, 16);
                        if (reg_id < 32 || reg_id == 64)
                        {
                            sprintf(response, "name:s%d;bitsize:32;encoding:uint;format:hex;set:General Purpose Scalar Registers;gcc:%d;dwarf:%d;",
                                    reg_id, reg_id, reg_id);

                            if (reg_id == 64)
                                sprintf(response + strlen(response), "generic:pc;");
                            else if (reg_id >= 29)
                                sprintf(response + strlen(response), "generic:%s;", GENERIC_REGS[reg_id - 29]);

                            send_response_packet(response);
                        }
                        else if (reg_id < 64)
                        {
                            send_formatted_response("name:v%d;bitsize:512;encoding:uint;format:vector-uint32;set:General Purpose Vector Registers;gcc:%d;dwarf:%d;",
                                                    reg_id - 32, reg_id, reg_id);
                        }
                        else
                            send_response_packet("");

                    }
                    else if (strcmp(request + 1, "C") == 0)
                        send_formatted_response("QC%02x", current_thread + 1);
                    else
                        send_response_packet("");	// Not supported

                    break;

                // Set Value
                case 'Q':
                    if (strcmp(request + 1, "StartNoAckMode") == 0)
                    {
                        no_ack_mode = true;
                        send_response_packet("OK");
                    }
                    else
                        send_response_packet("");	// Not supported

                    break;

                // Single step
                case 's':
                case 'S':
                    dbg_single_step(proc, current_thread);
                    last_signals[current_thread] = TRAP_SIGNAL;
                    send_formatted_response("S%02x", last_signals[current_thread]);
                    break;

                // Multi-character command
                case 'v':
                    if (strcmp(request, "vCont?") == 0)
                        send_response_packet("vCont;C;c;S;s");
                    else if (memcmp(request, "vCont;", 6) == 0)
                    {
                        // XXX hack.  There are two things lldb requests.  One is
                        // to step one thread while resuming the others.  In this case,
                        // I cheat and only step the one.  The other is just to continue,
                        // which I perform in the else clause.
                        const char *sreq = strchr(request, 's');
                        if (sreq != NULL)
                        {
                            // s:0001
                            current_thread = (uint32_t) strtoul(sreq + 2, NULL, 16) - 1;
                            dbg_single_step(proc, current_thread);
                            last_signals[current_thread] = TRAP_SIGNAL;
                            send_formatted_response("S%02x", last_signals[current_thread]);
                        }
                        else
                        {
                            run_until_interrupt(proc, ALL_THREADS, enable_fb_window);
                            last_signals[current_thread] = TRAP_SIGNAL;
                            send_formatted_response("S%02x", last_signals[current_thread]);
                        }
                    }
                    else
                        send_response_packet("");

                    break;

                // Clear breakpoint
                case 'z':
                    if (dbg_clear_breakpoint(proc, (uint32_t) strtoul(request + 3, NULL, 16)) < 0)
                        send_response_packet(""); // Error
                    else
                        send_response_packet("OK");

                    break;

                // Set breakpoint
                case 'Z':
                    if (dbg_set_breakpoint(proc, (uint32_t) strtoul(request + 3, NULL, 16)) < 0)
                        send_response_packet(""); // Error
                    else
                        send_response_packet("OK");

                    break;

                // Get last signal
                case '?':
                    send_formatted_response("S%02x", last_signals[current_thread]);
                    break;

                // Unknown, return error
                default:
                    send_response_packet("");
            }
        }

        close(client_socket);
    }
}

