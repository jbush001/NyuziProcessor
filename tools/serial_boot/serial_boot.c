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
// This checks for transfer errors, but does not attempt to recover or
// retransmit. If it fails, the user can reset the board and try again.
// Errors are very rare in my experience.
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

#define RAMDISK_BASE 0x4000000
#define BLOCK_SIZE 1024
#define PROGRESS_BAR_WIDTH 40

int openSerialPort(const char *path)
{
    int serialFd;

    serialFd = open(path, O_RDWR | O_NOCTTY);
    if (serialFd < 0)
    {
        perror("couldn't open serial port");
        return -1;
    }

    // Clear out any junk that may already be buffered in the
    // serial driver (otherwise the ping sequence may fail)
    tcflush(serialFd, TCIOFLUSH);

    return serialFd;
}

int setLocalSerialSpeed(int serialFd, speed_t bitsPerSecond)
{
    struct termios serialopts;

    memset(&serialopts, 0, sizeof(serialopts));
    serialopts.c_cflag = CS8 | CLOCAL | CREAD;
    cfsetspeed(&serialopts, bitsPerSecond);
    if (tcsetattr(serialFd, TCSANOW, &serialopts) != 0)
    {
        perror("Unable to initialize serial port");
        return -1;
    }

    return 0;
}

// Returns 1 if the byte was read successfully, 0 if a timeout
// or other error occurred.
int readSerialByte(int serialFd, unsigned char *ch, int timeoutMs)
{
    fd_set set;
    struct timeval tv;
    int readyFds;

    FD_ZERO(&set);
    FD_SET(serialFd, &set);

    tv.tv_sec = timeoutMs / 1000;
    tv.tv_usec = (timeoutMs % 1000) * 1000;

    do
    {
        readyFds = select(FD_SETSIZE, &set, NULL, NULL, &tv);
    }
    while (readyFds < 0 && errno == EINTR);

    if (readyFds == 0)
        return 0;

    if (read(serialFd, ch, 1) != 1)
    {
        perror("read");
        return 0;
    }

    return 1;
}

int readSerialLong(int serialFd, unsigned int *out, int timeout)
{
    unsigned int result = 0;
    unsigned char ch;
    int i;

    for (i = 0; i < 4; i++)
    {
        if (!readSerialByte(serialFd, &ch, timeout))
            return 0;

        result = (result >> 8) | ((unsigned int) ch << 24);
    }

    *out = result;
    return 1;
}

int writeSerialByte(int serialFd, unsigned int ch)
{
    if (write(serialFd, &ch, 1) != 1)
    {
        perror("write");
        return 0;
    }

    return 1;
}

int writeSerialLong(int serialFd, unsigned int value)
{
    unsigned char out[4] =
    {
        value & 0xff,
        (value >> 8) & 0xff,
        (value >> 16) & 0xff,
        (value >> 24) & 0xff
    };

    if (write(serialFd, out, 4) != 4)
    {
        perror("write");
        return 0;
    }

    return 1;
}

int setRemoteSerialSpeed(int serialFd, speed_t bitsPerSecond)
{
    unsigned char ch;

    if (!writeSerialByte(serialFd, SET_SPEED_REQ))
        return 0;

    if (!writeSerialLong(serialFd, (unsigned int) bitsPerSecond))
        return 0;

    if (!readSerialByte(serialFd, &ch, 15000))
    {
        fprintf(stderr, "\nTimed out waitng for set serial speed response\n");
        return 0;
    }
    else if (ch != SET_SPEED_ACK)
    {
        fprintf(stderr, "\nDid not get ack for set serial speed, got %02x instead\n", ch);
        return 0;
    }

    return 1;
}


int fillMemory(int serialFd, unsigned int address, const unsigned char *buffer, unsigned int length)
{
    unsigned int targetChecksum;
    unsigned int localChecksum;
    unsigned char ch;
    unsigned int i;

    if (!writeSerialByte(serialFd, LOAD_MEMORY_REQ))
        return 0;

    if (!writeSerialLong(serialFd, address))
        return 0;

    if (!writeSerialLong(serialFd, length))
        return 0;

    if (write(serialFd, buffer, length) != length)
    {
        fprintf(stderr, "\nError writing to serial port\n");
        return 0;
    }

    // wait for ack
    if (!readSerialByte(serialFd, &ch, 15000))
    {
        fprintf(stderr, "\n%08x Timed out waiting for load memory response\n", address);
        return 0;
    }
    else if (ch != LOAD_MEMORY_ACK)
    {
        fprintf(stderr, "\n%08x Did not get ack for load memory, got %02x instead\n", address, ch);
        return 0;
    }

    // Compute FNV-1a hash
    localChecksum = 2166136261;
    for (i = 0; i < length; i++)
        localChecksum = (localChecksum ^ buffer[i]) * 16777619;

    if (!readSerialLong(serialFd, &targetChecksum, 5000))
    {
        fprintf(stderr, "\n%08x Timed out reading checksum\n", address);
        return 0;
    }

    if (targetChecksum != localChecksum)
    {
        fprintf(stderr, "\n%08x checksum mismatch want %08x got %08x\n",
                address, localChecksum, targetChecksum);
        return 0;
    }

    return 1;
}

int fixConnection(int serialFd)
{
    unsigned char ch = 0;
    int charsRead = 0;
    // Clear out any waiting BAD_COMMAND bytes
    // May grab an extra byte
    while (readSerialByte(serialFd, &ch, 250) && ch == BAD_COMMAND)
    {
        charsRead++;
    }
    printf("%d BAD_COMMAND bytes seen, last was %02x\n", charsRead, ch);
    // Send pings until the processor responds
    // This can help if the processor is expecting data from us
    int pingSeen = 0;
    int retry = 0;
    while (1)
    {
        if(readSerialByte(serialFd, &ch, 25))
        {
            if (pingSeen)
                // Once you've seen one ping, ignore the rest
                continue;
            else if (ch == PING_ACK)
            {
                printf("Ping return seen.\n");
                pingSeen = 1;
            }
            else
            {
                printf("byte read: %02x\n", ch);
            }
        }
        else
        {
            // If there's no more data, and we've seen one ping,
            // we're done here.
            if (pingSeen)
            {
                return 1;
            }
        }
        if(!pingSeen)
        {
            retry++;
            if(!writeSerialByte(serialFd, PING_REQ))
            {
                return 0;
            }
        }
        if (retry > 40)
        {
            printf("Cannot fix connection, no ping from board recieved.\n");
            printf("Try resetting the board (KEY0) and rerunning.\n");
            return 0;
        }
    }
}

int clearMemory(int serialFd, unsigned int address, unsigned int length)
{
    unsigned char ch;

    if (!writeSerialByte(serialFd, CLEAR_MEMORY_REQ))
        return 0;

    if (!writeSerialLong(serialFd, address))
        return 0;

    if (!writeSerialLong(serialFd, length))
        return 0;

    // wait for ack
    if (!readSerialByte(serialFd, &ch, 15000) || ch != CLEAR_MEMORY_ACK)
    {
        fprintf(stderr, "\n%08x Did not get ack for clear memory\n", address);
        return 0;
    }

    return 1;
}

int pingTarget(int serialFd)
{
    int retry;
    unsigned char ch;

    printf("ping target");

    int targetReady = 0;
    for (retry = 0; retry < 20; retry++)
    {
        printf(".");
        fflush(stdout);
        writeSerialByte(serialFd, PING_REQ);
        if (readSerialByte(serialFd, &ch, 250) && ch == PING_ACK)
        {
            targetReady = 1;
            break;
        }
    }

    if (!targetReady)
    {
        printf("target is not responding\n");
        return 0;
    }

    printf("\n");

    return 1;
}

int sendExecuteCommand(int serialFd)
{
    unsigned char ch;

    writeSerialByte(serialFd, EXECUTE_REQ);
    if (!readSerialByte(serialFd, &ch, 15000) || ch != EXECUTE_ACK)
    {
        fprintf(stderr, "Target returned error starting execution\n");
        return 0;
    }

    return 1;
}

void doConsoleMode(int serialFd)
{
    fd_set set;
    int readyFds;
    char readBuffer[256];
    ssize_t got;

    while (1)
    {
        FD_ZERO(&set);
        FD_SET(serialFd, &set);
        FD_SET(STDIN_FILENO, &set);	// stdin

        do
        {
            readyFds = select(FD_SETSIZE, &set, NULL, NULL, NULL);
        }
        while (readyFds < 0 && errno == EINTR);

        if (FD_ISSET(serialFd, &set))
        {
            // Serial -> Terminal
            got = read(serialFd, readBuffer, sizeof(readBuffer));
            if (got <= 0)
            {
                perror("read");
                return;
            }

            if (write(STDIN_FILENO, readBuffer, (unsigned int) got) < got)
            {
                perror("write");
                return;
            }
        }

        if (FD_ISSET(STDIN_FILENO, &set))
        {
            // Terminal -> Serial
            got = read(STDIN_FILENO, readBuffer, sizeof(readBuffer));
            if (got <= 0)
            {
                perror("read");
                return;
            }

            if (write(serialFd, readBuffer, (unsigned int) got) != got)
            {
                perror("write");
                return;
            }
        }
    }
}

int readHexFile(const char *filename, unsigned char **outPtr, unsigned int *outLength)
{
    FILE *inputFile;
    char line[16];
    unsigned int offset = 0;
    unsigned char *data;
    unsigned int fileLength;

    inputFile = fopen(filename, "r");
    if (!inputFile)
    {
        perror("Error opening input file\n");
        return 0;
    }

    fseek(inputFile, 0, SEEK_END);
    fileLength = (unsigned int) ftell(inputFile);
    fseek(inputFile, 0, SEEK_SET);

    // This may overestimate the size a bit, which is fine.
    data = malloc(fileLength / 2);
    while (fgets(line, sizeof(line), inputFile))
    {
        unsigned int value = (unsigned int) strtoul(line, NULL, 16);
        data[offset++] = (value >> 24) & 0xff;
        data[offset++] = (value >> 16) & 0xff;
        data[offset++] = (value >> 8) & 0xff;
        data[offset++] = value & 0xff;
    }

    *outPtr = data;
    *outLength = offset;
    fclose(inputFile);

    return 1;
}

int readBinaryFile(const char *filename, unsigned char **outPtr, unsigned int *outLength)
{
    FILE *inputFile;
    unsigned char *data;
    unsigned int fileLength;

    inputFile = fopen(filename, "r");
    if (!inputFile)
    {
        perror("Error opening input file");
        return 0;
    }

    fseek(inputFile, 0, SEEK_END);
    fileLength = (unsigned int) ftell(inputFile);
    fseek(inputFile, 0, SEEK_SET);

    data = malloc(fileLength);
    if (fread(data, fileLength, 1, inputFile) != 1)
    {
        perror("Error reading file");
        return 0;
    }

    *outPtr = data;
    *outLength = fileLength;
    fclose(inputFile);

    return 1;
}

void printProgressBar(unsigned int current, unsigned int total)
{
    unsigned int numTicks = current * PROGRESS_BAR_WIDTH / total;
    unsigned int i;

    printf("\rLoading [");
    for (i = 0; i < numTicks; i++)
        printf("=");

    for (; i < PROGRESS_BAR_WIDTH; i++)
        printf(" ");

    printf("] (%d%%)", current * 100 / total);
    fflush(stdout);
}

static int isEmpty(unsigned char *data, unsigned int length)
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

int sendFile(int serialFd, unsigned int address, unsigned char *data, unsigned int dataLength)
{
    unsigned int offset = 0;

    printProgressBar(0, dataLength);
    while (offset < dataLength)
    {
        int copiedCorrectly = 1;
        unsigned int thisSlice = dataLength - offset;
        if (thisSlice > BLOCK_SIZE)
            thisSlice = BLOCK_SIZE;

        if (isEmpty(data + offset, thisSlice))
        {
            if (!clearMemory(serialFd, address + offset, thisSlice))
                return 0;
        }
        else
        {
            if (!fillMemory(serialFd, address + offset, data + offset, thisSlice))
            {
                copiedCorrectly = 0;
                if (!fixConnection(serialFd))
                {
                    return 0;
                }
            }
        }
        if (copiedCorrectly)
        {
            offset += thisSlice;
        }
        printProgressBar(offset, dataLength);
    }

    return 1;
}

int main(int argc, const char *argv[])
{
    unsigned char *programData;
    unsigned int programLength;
    unsigned char *ramdiskData = NULL;
    unsigned int ramdiskLength = 0;
    int serialFd;

    if (argc < 3)
    {
        fprintf(stderr, "USAGE:\n    serialBoot <serial port name> <hex file> [<ramdisk image>]\n");
        return 1;
    }

    if (!readHexFile(argv[2], &programData, &programLength))
        return 1;

    if (argc == 4)
    {
        // Load binary ramdisk image
        if (!readBinaryFile(argv[3], &ramdiskData, &ramdiskLength))
            return 1;
    }

    serialFd = openSerialPort(argv[1]);
    if (serialFd < 0)
        return 1;

    // Set default speed
    if (setLocalSerialSpeed(serialFd, 115200) < 0)
        return 1;

    if (!pingTarget(serialFd))
        return 1;

    // Crank up speed
    if (!setRemoteSerialSpeed(serialFd, 921600))
        return 1;

    if (setLocalSerialSpeed(serialFd, 921600) < 0)
        return 1;

    printf("Program is %d bytes\n", programLength);
    if (!sendFile(serialFd, 0, programData, programLength))
        return 1;

    if (ramdiskData)
    {
        printf("\nRamdisk is %d bytes\n", ramdiskLength);
        if (!sendFile(serialFd, RAMDISK_BASE, ramdiskData, ramdiskLength))
            return 1;
    }

    if (!sendExecuteCommand(serialFd))
        return 1;

    printf("\nProgram running, entering console mode\n");

    doConsoleMode(serialFd);

    return 0;
}
