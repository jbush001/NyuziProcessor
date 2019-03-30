//
// Copyright 2017 Jeff Bush
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
#include <errno.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>
#include "svdpi.h"
#include "Vsoc_tb__Dpi.h"

//
// Receives instructions from an external test program over a socket. The JTAG
// simulator Verilog module calls into this with DPI to get the next request.
// Using a zero instruction or data length in the request will skip shifting
// that register.
//
// Each socket request is (packed):
//
// uint8_t instructionLength;   // Number of bits in instruction
// uint32_t instruction;        // Instruction value (aligned to LSB)
// uint8_t dataLength;          // Number of bits in data
// uint64_t data;               // Send data value (aligned to LSB)
//
// 14 bytes total
//
// This will respond to each request with:
//
// uint64_t shiftedData;            // shifted out tdo during data
// uint32_t shiftedInstruction;     // shifted out tdo during instruction
//
//

namespace
{
const int REQUEST_LENGTH = 14;

int listenSocket = -1;
int controlSocket = -1;
unsigned char requestBuffer[REQUEST_LENGTH];
int currentLength;
}

//
// Open a socket that will listen for connections from a test harness
//
extern int open_jtag_socket(int port)
{
    struct sockaddr_in address;
    int optval;

    listenSocket = socket(PF_INET, SOCK_STREAM, 0);
    if (listenSocket < 0)
    {
        perror("init_jtag_socket: error setting up debug socket (socket)");
        return 0;
    }

    // Set so we don't get an error if restarting after a crash.
    optval = 1;
    if (setsockopt(listenSocket, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof(optval)) < 0)
    {
        perror("init_jtag_socket: error setting up debug socket (setsockopt)");
        return 0;
    }

    address.sin_family = AF_INET;
    address.sin_port = htons(port);
    address.sin_addr.s_addr = htonl(INADDR_ANY);
    if (bind(listenSocket, (struct sockaddr*) &address, sizeof(address)) < 0)
    {
        perror("init_jtag_socket: error setting up debug socket (bind)");
        return 0;
    }

    if (listen(listenSocket, 1) < 0)
    {
        perror("init_jtag_socket: error setting up debug socket (listen)");
        return 0;
    }

    if (fcntl(listenSocket, F_SETFL, O_NONBLOCK) < 0)
    {
        perror("init_jtag_socket: error setting up debug socket (fcntl)");
        return 0;
    }

    return 1;
}

//
// Checks the socket for requests. If a socket is not yet open, this will
// check if any connections are pending and accept them if so.
// Returns 1 if the request was pending (as well as filling in the passed
// pointers with the request contents), or 0 if no request is pending.
//
extern int poll_jtag_request(svBitVecVal *instructionLength, svBitVecVal *instruction,
    svBitVecVal *dataLength, svBitVecVal *data)
{
    int got;

    if (controlSocket < 0)
    {
        // listen for a socket
        struct sockaddr_in address;
        socklen_t addressLength = sizeof(address);
        controlSocket = accept(listenSocket, (struct sockaddr*) &address,
                               &addressLength);
        if (controlSocket < 0) {
            if (errno == EWOULDBLOCK)
                return 0;   // No socket available

            perror("JTAG listen socket error");
            return 0;
        }

        if (fcntl(controlSocket, F_SETFL, O_NONBLOCK) < 0)
        {
            perror("poll_jtag_request: error setting up control socket (fcntl)");
            return 0;
        }
    }

    got = read(controlSocket, requestBuffer + currentLength,
        sizeof(requestBuffer) - currentLength);
    if (got <= 0)
    {
        if (errno == EWOULDBLOCK)
            return 0;   // No data available

        // Fatal socket error
        perror("poll_jtag_request: control socket error");
        controlSocket = -1;
        return 0;
    }

    currentLength += got;
    if (currentLength < REQUEST_LENGTH)
        return 0;

    // Have read a complete request
    currentLength = 0;

    // XXX assumes a little endian machine
    *instructionLength = requestBuffer[0];
    memcpy(instruction, requestBuffer + 1, 4);
    *dataLength = requestBuffer[5];
    memcpy(data, requestBuffer + 6, 8);

    return 1;
}

// When the JTAG harness has finished shifting all data bits,
// this sends the value that was shifted out of the device.
extern void send_jtag_response(const svBitVecVal *instruction, const svBitVecVal *data)
{
    char response[12];

    memcpy(response, instruction, 4);
    memcpy(response + 4, data, 8);

    if (write(controlSocket, response, 12) < 0)
        perror("send_jtag_response: error sending response (send)");
}
