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
#include "core.h"
#include "fbwindow.h"
#include "remote-gdb.h"
#include "util.h"

#define TRAP_SIGNAL 5 // SIGTRAP

extern void check_interrupt_pipe(struct core*);
static void __attribute__ ((format (printf, 1, 2))) send_formatted_response(const char *format, ...);

static int client_socket = -1;
static int *last_signals;
static const char *GENERIC_REGS[] = { "fp", "sp", "ra", "pc" };

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
    return packet_len;
}

static void send_response_packet(const char *request)
{
    uint8_t checksum;
    char checksum_chars[16];
    int i;
    size_t request_length = strlen(request);

    if (write(client_socket, "$", 1) < 1
            || write(client_socket, request, request_length) < (ssize_t) request_length
            || write(client_socket, "#", 1) < 1)
    {
        perror("send_response_packet: Error writing to debugger socket");
        exit(1);
    }

    checksum = 0;
    for (i = 0; request[i]; i++)
        checksum += request[i];

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
static void run_until_interrupt(struct core *core, uint32_t thread_id, bool enable_fb_window)
{
    while (true)
    {
        if (!execute_instructions(core, thread_id, screen_refresh_rate))
            break;

        if (enable_fb_window)
        {
            update_frame_buffer(core);
            poll_fb_window_event();
            check_interrupt_pipe(core);
        }

        // Break on error or if data is ready
        if (can_read_file_descriptor(client_socket) != 0)
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

void remote_gdb_main_loop(struct core *core, bool enable_fb_window)
{
    int listen_socket;
    struct sockaddr_in address;
    socklen_t address_length;
    int got;
    char request[256];
    uint32_t i;
    bool no_ack_mode = false;
    int optval;
    char response[256];
    uint32_t current_thread = 0;

    last_signals = calloc(sizeof(int), get_total_threads(core));
    for (i = 0; i < get_total_threads(core); i++)
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
                    run_until_interrupt(core, ALL_THREADS, enable_fb_window);
                    last_signals[current_thread] = TRAP_SIGNAL;
                    send_formatted_response("S%02x", last_signals[current_thread]);
                    break;

                // Pick thread
                case 'H':
                    if (request[1] == 'g' || request[1] == 'c')
                    {
                        // XXX hack: the request type controls which operations this
                        // applies for.
                        current_thread = (uint32_t)(request[2] - '1');
                        send_response_packet("OK");
                    }
                    else
                        send_response_packet("");

                    break;

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
                        // Read memory
                        for (offset = 0; offset < length; offset++)
                            sprintf(response + offset * 2, "%02x", debug_read_memory_byte(core, start + offset));

                        send_response_packet(response);
                    }
                    else
                    {
                        // Write memory
                        data_ptr += 1;	// Skip colon
                        for (offset = 0; offset < length; offset++)
                            debug_write_memory_byte(core, start + offset, decode_hex_byte(data_ptr + offset * 2));

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
                        value = get_scalar_register(core, current_thread, reg_id);
                        send_formatted_response("%08x", endian_swap32(value));
                    }
                    else if (reg_id < 64)
                    {
                        uint32_t lane;

                        for (lane = 0; lane < NUM_VECTOR_LANES; lane++)
                        {
                            value = get_vector_register(core, current_thread, reg_id, lane);
                            sprintf(response + lane * 8, "%08x", endian_swap32(value));
                        }

                        send_response_packet(response);
                    }
                    else
                        send_response_packet("");

                    break;
                }

                // XXX need to implement write register

                // Query
                case 'q':
                    if (strcmp(request + 1, "LaunchSuccess") == 0)
                        send_response_packet("OK");
                    else if (strcmp(request + 1, "HostInfo") == 0)
                        send_response_packet("triple:nyuzi;endian:little;ptrsize:4");
                    else if (strcmp(request + 1, "ProcessInfo") == 0)
                        send_response_packet("pid:1");
                    else if (strcmp(request + 1, "fThreadInfo") == 0)
                        send_response_packet("m1,2,3,4");	// XXX need to query number of threads
                    else if (strcmp(request + 1, "sThreadInfo") == 0)
                        send_response_packet("l");
                    else if (memcmp(request + 1, "ThreadStopInfo", 14) == 0)
                        send_formatted_response("S%02x", last_signals[current_thread]);
                    else if (memcmp(request + 1, "RegisterInfo", 12) == 0)
                    {
                        uint32_t reg_id = (uint32_t) strtoul(request + 13, NULL, 16);
                        if (reg_id < 32)
                        {
                            sprintf(response, "name:s%d;bitsize:32;encoding:uint;format:hex;set:General Purpose Scalar Registers;gcc:%d;dwarf:%d;",
                                    reg_id, reg_id, reg_id);

                            if (reg_id >= 28)
                                sprintf(response + strlen(response), "generic:%s;", GENERIC_REGS[reg_id - 28]);

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
                    single_step(core, current_thread);
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
                            single_step(core, current_thread);
                            last_signals[current_thread] = TRAP_SIGNAL;
                            send_formatted_response("S%02x", last_signals[current_thread]);
                        }
                        else
                        {
                            run_until_interrupt(core, ALL_THREADS, enable_fb_window);
                            last_signals[current_thread] = TRAP_SIGNAL;
                            send_formatted_response("S%02x", last_signals[current_thread]);
                        }
                    }
                    else
                        send_response_packet("");

                    break;

                // Clear breakpoint
                case 'z':
                    if (clear_breakpoint(core, (uint32_t) strtoul(request + 3, NULL, 16)) < 0)
                        send_response_packet(""); // Error
                    else
                        send_response_packet("OK");

                    break;

                // Set breakpoint
                case 'Z':
                    if (set_breakpoint(core, (uint32_t) strtoul(request + 3, NULL, 16)) < 0)
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

