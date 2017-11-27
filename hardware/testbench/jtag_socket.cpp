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
#include <netinet/in.h>
#include <stdio.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include "Vsoc_tb__Dpi.h"
#include "svdpi.h"

//
// This proxies JTAG communications. It receives instructions from an external test
// program over a socket. A Verilog module calls into this with DPI to get
// the next message.
//
// Each socket message is (packed):
//
// uint8_t instructionLength;
// uint32_t instruction;
// uint8_t dataLength;
// uint64_t data;
//
// 14 bytes total
//

namespace
{
const int MESSAGE_LENGTH = 14;

int listenSocket = -1;
int controlSocket = -1;
unsigned char messageBuffer[MESSAGE_LENGTH];
int currentLength;
}

extern int init_jtag_socket(int port)
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

extern int poll_jtag_message(svBitVecVal* instructionLength, svBitVecVal* instruction,
    svBitVecVal* dataLength, svBitVecVal* data)
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
            perror("poll_jtag_message: error setting up control socket (fcntl)");
            return 0;
        }
    }

    got = read(controlSocket, messageBuffer + currentLength,
        sizeof(messageBuffer) - currentLength);
    if (got <= 0)
    {
        if (errno == EWOULDBLOCK)
            return 0;   // No data available

        // Fatal socket error
        perror("poll_jtag_message: control socket error");
        controlSocket = -1;
        return 0;
    }

    currentLength += got;
    if (currentLength < MESSAGE_LENGTH)
        return 0;

    currentLength = 0;

    // XXX assumes a little endian machine
    *instructionLength = messageBuffer[0];
    memcpy(instruction, messageBuffer + 1, 4);
    *dataLength = messageBuffer[5];
    memcpy(data, messageBuffer + 6, 8);

    return 1;
}

extern int send_jtag_response(const svBitVecVal* data)
{
    if (write(controlSocket, data, 8) < 0)
        perror("send_jtag_response: error sending response (send)");

    return 0;
}
