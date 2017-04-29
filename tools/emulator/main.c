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

#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <unistd.h>
#include "processor.h"
#include "cosimulation.h"
#include "device.h"
#include "fbwindow.h"
#include "instruction-set.h"
#include "remote-gdb.h"
#include "sdmmc.h"
#include "util.h"

extern void check_interrupt_pipe(struct processor*);

static int recv_interrupt_fd = -1;
static int send_interrupt_fd = -1;

static void usage(void)
{
    fprintf(stderr, "usage: emulator [options] <hex image file>\n");
    fprintf(stderr, "options:\n");
    fprintf(stderr, "  -v Verbose, will print register transfer traces to stdout\n");
    fprintf(stderr, "  -m Mode, one of:\n");
    fprintf(stderr, "     normal  Run to completion (default)\n");
    fprintf(stderr, "     cosim   Cosimulation validation mode\n");
    fprintf(stderr, "     gdb     Start GDB listener on port 8000\n");
    fprintf(stderr, "  -f <width>x<height> Display frame buffer output in window\n");
    fprintf(stderr, "  -d <filename>,<start>,<length>  Dump memory\n");
    fprintf(stderr, "  -b <filename> Load file into a virtual block device\n");
    fprintf(stderr, "  -t <num> Threads per core (default 4)\n");
    fprintf(stderr, "  -p <num> Number of cores (default 1)\n");
    fprintf(stderr, "  -c <size> Total amount of memory\n");
    fprintf(stderr, "  -r <cycles> Refresh rate, cycles between each screen update\n");
    fprintf(stderr, "  -s <file> Memory map file as shared memory\n");
    fprintf(stderr, "  -i <file> Named pipe to receive interrupts. Pipe must already be created.\n");
    fprintf(stderr, "  -o <file> Named pipe to send interrupts. Pipe must already be created\n");
}

static uint32_t parse_num_arg(const char *argval)
{
    if (argval[0] == '0' && argval[1] == 'x')
        return (uint32_t) strtoul(argval + 2, NULL, 16);
    else
        return (uint32_t) strtoul(argval, NULL, 10);
}

// An external process can send interrupts to the emulator by writing to a
// named pipe. Poll the pipe to determine if any messages are pending. If
// so, call into the proc to dispatch.
void check_interrupt_pipe(struct processor *proc)
{
    int result;
    char interrupt_id;

    if (recv_interrupt_fd < 0)
        return;

    result = can_read_file_descriptor(recv_interrupt_fd);
    if (result == 0)
        return;

    if (result < 0)
    {
        perror("check_interrupt_pipe: select failed");
        exit(1);
    }

    if (read(recv_interrupt_fd, &interrupt_id, 1) < 1)
    {
        perror("check_interrupt_pipe: read failed");
        exit(1);
    }

    if (interrupt_id > 16)
    {
        fprintf(stderr, "Received invalidate interrupt ID %d\n", interrupt_id);
        return; // Ignore invalid interrupt IDs
    }

    raise_interrupt(proc, 1 << interrupt_id);
}

void send_host_interrupt(uint32_t num)
{
    char c = (char) num;

    if (send_interrupt_fd < 0)
        return;

    if (write(send_interrupt_fd, &c, 1) < 1)
    {
        perror("send_host_interrupt: write failed");
        exit(1);
    }
}

int main(int argc, char *argv[])
{
    struct processor *proc;
    int option;
    bool enable_memory_dump = false;
    uint32_t mem_dump_base = 0;
    uint32_t mem_dump_length = 0;
    char *mem_dump_filename = NULL;
    size_t mem_dump_filename_len = 0;
    bool verbose = false;
    uint32_t fb_width = 640;
    uint32_t fb_height = 480;
    bool block_device_open = false;
    bool enable_fb_window = false;
    uint32_t threads_per_core = 4;
    uint32_t num_cores = 1;
    char *separator;
    uint32_t memory_size = 0x1000000;
    const char *shared_memory_file = NULL;
    struct stat st;

    enum
    {
        MODE_NORMAL,
        MODE_COSIMULATION,
        MODE_GDB_REMOTE_DEBUG
    } mode = MODE_NORMAL;

    while ((option = getopt(argc, argv, "f:d:vm:b:t:p:c:r:s:i:o:")) != -1)
    {
        switch (option)
        {
            case 'v':
                verbose = true;
                break;

            case 'r':
                screen_refresh_rate = parse_num_arg(optarg);
                break;

            case 'f':
                enable_fb_window = true;
                separator = strchr(optarg, 'x');
                if (!separator)
                {
                    fprintf(stderr, "Invalid frame buffer size %s\n", optarg);
                    return 1;
                }

                fb_width = parse_num_arg(optarg);
                fb_height = parse_num_arg(separator + 1);
                break;

            case 'm':
                if (strcmp(optarg, "normal") == 0)
                    mode = MODE_NORMAL;
                else if (strcmp(optarg, "cosim") == 0)
                    mode = MODE_COSIMULATION;
                else if (strcmp(optarg, "gdb") == 0)
                    mode = MODE_GDB_REMOTE_DEBUG;
                else
                {
                    fprintf(stderr, "Unkown execution mode %s\n", optarg);
                    return 1;
                }

                break;

            case 'd':
                // Memory dump, of the form: filename,start,length
                separator = strchr(optarg, ',');
                if (separator == NULL)
                {
                    fprintf(stderr, "bad format for memory dump\n");
                    usage();
                    return 1;
                }

                mem_dump_filename_len = (size_t)(separator - optarg);
                mem_dump_filename = (char*) malloc(mem_dump_filename_len + 1);
                strncpy(mem_dump_filename, optarg, mem_dump_filename_len);
                mem_dump_filename[mem_dump_filename_len] = '\0';
                mem_dump_base = parse_num_arg(separator + 1);

                separator = strchr(separator + 1, ',');
                if (separator == NULL)
                {
                    fprintf(stderr, "bad format for memory dump\n");
                    usage();
                    free(mem_dump_filename);
                    return 1;
                }

                mem_dump_length = parse_num_arg(separator + 1);
                enable_memory_dump = true;
                break;

            case 'b':
                if (open_block_device(optarg) < 0)
                    return 1;

                block_device_open = true;
                break;

            case 'c':
                memory_size = parse_num_arg(optarg);
                break;

            case 't':
                threads_per_core = parse_num_arg(optarg);
                if (threads_per_core < 1 || threads_per_core > 32)
                {
                    fprintf(stderr, "Total threads must be between 1 and 32\n");
                    return 1;
                }

                break;

            case 'p':
                num_cores = parse_num_arg(optarg);
                if (num_cores < 1)
                {
                    // XXX Should there be a maximum?
                    fprintf(stderr, "Total cores must be greater than 1\n");
                    return 1;
                }

                break;

            case 's':
                shared_memory_file = optarg;
                break;

            case 'i':
                recv_interrupt_fd = open(optarg, O_RDWR);
                if (recv_interrupt_fd < 0)
                {
                    perror("main: failed to open receive interrupt pipe");
                    return 1;
                }

                if (fstat(recv_interrupt_fd, &st) < 0)
                {
                    perror("main: stat failed on receive interrupt pipe");
                    return 1;
                }

                if ((st.st_mode & S_IFMT) != S_IFIFO)
                {
                    fprintf(stderr, "%s is not a pipe\n", optarg);
                    return 1;
                }

                break;

            case 'o':
                send_interrupt_fd = open(optarg, O_RDWR);
                if (send_interrupt_fd < 0)
                {
                    perror("main: failed to open send interrupt pipe");
                    return 1;
                }

                if (fstat(send_interrupt_fd, &st) < 0)
                {
                    perror("main: stat failed on send interrupt pipe");
                    return 1;
                }

                if ((st.st_mode & S_IFMT) != S_IFIFO)
                {
                    fprintf(stderr, "%s is not a pipe\n", optarg);
                    return 1;
                }

                break;

            case '?':
                usage();
                return 1;
        }
    }

    if (optind == argc)
    {
        fprintf(stderr, "No image filename specified\n");
        usage();
        return 1;
    }

    // Don't randomize memory for cosimulation mode, because
    // memory is checked against the hardware model to ensure a match

    proc = init_processor(memory_size, num_cores, threads_per_core,
                          mode != MODE_COSIMULATION, shared_memory_file);
    if (proc == NULL)
        return 1;

    if (load_hex_file(proc, argv[optind]) < 0)
    {
        fprintf(stderr, "Error reading image %s\n", argv[optind]);
        return 1;
    }

    init_device(proc);

    if (enable_fb_window)
    {
        if (init_frame_buffer(fb_width, fb_height) < 0)
            return 1;
    }

    switch (mode)
    {
        case MODE_NORMAL:
            if (verbose)
                enable_tracing(proc);

            dbg_set_stop_on_fault(proc, false);
            if (enable_fb_window)
            {
                while (execute_instructions(proc, ALL_THREADS, screen_refresh_rate))
                {
                    update_frame_buffer(proc);
                    poll_fb_window_event();
                    check_interrupt_pipe(proc);
                }
            }
            else
            {
                while (execute_instructions(proc, ALL_THREADS, 1000000))
                    check_interrupt_pipe(proc);
            }

            break;

        case MODE_COSIMULATION:
            dbg_set_stop_on_fault(proc, false);
            if (run_cosimulation(proc, verbose) < 0)
                return 1;	// Failed

            break;

        case MODE_GDB_REMOTE_DEBUG:
            dbg_set_stop_on_fault(proc, true);
            remote_gdb_main_loop(proc, enable_fb_window);
            break;
    }

    if (enable_memory_dump)
        write_memory_to_file(proc, mem_dump_filename, mem_dump_base, mem_dump_length);

    free(mem_dump_filename);

    dump_instruction_stats(proc);
    if (block_device_open)
        close_block_device();

    if (is_stopped_on_fault(proc))
        return 1;

    return 0;
}
