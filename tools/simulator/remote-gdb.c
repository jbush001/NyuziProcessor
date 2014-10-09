#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <errno.h>
#include "Core.h"

static Core *gCore;
static int clientSocket = -1;

int readByte()
{
	unsigned char ch;
	if (read(clientSocket, &ch, 1) < 1)
	{
		perror("error reading from socket");
		return -1;
	}
	
	return ch;
}

int readPacket(char *packetBuf, int maxLength)
{
	int ch;
	int packetLen;

	// Wait for packet start
	do
	{
		ch = readByte();
		if (ch < 0)
			return -1;
	}
	while (ch != '$');

	// Read body
	packetLen = 0;
	while (1)
	{
		ch = readByte();
		if (ch < 0)
			return -1;
		
		if (ch == '#')
			break;
		
		if (packetLen < maxLength)
			packetBuf[packetLen++] = ch;
	}
	
	// Read checksum and discard
	readByte();
	readByte();
	
	packetBuf[packetLen] = '\0';
	return packetLen;
}

const char *kGenericRegs[] = {
	"fp",
	"sp",
	"ra",
	"pc"
};

void sendPacket(const char *packetBuf)
{
	unsigned char checksum;
	char checksumChars[16];
	
	write(clientSocket, "$", 1);
	write(clientSocket, packetBuf, strlen(packetBuf));
	write(clientSocket, "#", 1);

	checksum = 0;
	for (int i = 0; packetBuf[i]; i++)
		checksum += packetBuf[i];
	
	sprintf(checksumChars, "%02x", checksum);
	write(clientSocket, checksumChars, 2);
	
	printf(">> %s\n", packetBuf);
}

void runUntilInterrupt(Core *core)
{
	fd_set readFds;
	int result;

	FD_ZERO(&readFds);

	while (1)
	{
		runQuantum(core, 1000);
		FD_SET(clientSocket, &readFds);
		result = select(clientSocket + 1, &readFds, NULL, NULL, NULL);
		if ((result < 0 && errno != EINTR) || result == 1)
			break;
	}
}

void remoteGdbMainLoop(Core *core)
{
	int listenSocket;
	struct sockaddr_in address;
	socklen_t addressLength;
	int got;
	char packetBuf[256];
	int i;
	int noAckMode = 0;
	int optval;
	char response[256];
	
	gCore = core;

	listenSocket = socket(PF_INET, SOCK_STREAM, 0);
	if (listenSocket < 0)
	{
		perror("socket");
		return;
	}

	optval = 1;
	setsockopt(listenSocket, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof optval);
	
	address.sin_family = AF_INET;
	address.sin_port = htons(8000);
	address.sin_addr.s_addr = htonl(INADDR_ANY);
	if (bind(listenSocket, (struct sockaddr*) &address, sizeof(address)) < 0)
	{	
		perror("bind");
		return;
	}

	if (listen(listenSocket, 4) < 0)
	{
		perror("bind");
		return;
	}
	
	while (1)
	{
		// Wait for a new client socket
		while (1)
		{
			addressLength = sizeof(address);
			clientSocket = accept(listenSocket, (struct sockaddr*) &address,
				&addressLength);
			if (clientSocket >= 0)
				break;
		}
		
		printf("Got connection from debugger\n");
		noAckMode = 0;

		// Process commands
		while (1)
		{
			got = readPacket(packetBuf, sizeof(packetBuf));
			if (got < 0) 
				break;
			
			if (!noAckMode)
				write(clientSocket, "+", 1);

			printf("<< %s\n", packetBuf);

			switch (packetBuf[0])
			{
				// Set Value
				case 'Q':
					if (strcmp(packetBuf + 1, "StartNoAckMode") == 0)
					{
						noAckMode = 1;
						sendPacket("OK");
					}
					else
						sendPacket("");	// Not supported
					
					break;
					
				// Query
				case 'q':
					if (strcmp(packetBuf + 1, "LaunchSuccess") == 0)
						sendPacket("OK");
					else if (strcmp(packetBuf + 1, "HostInfo") == 0)
						sendPacket("triple:nyuzi;endian:little;ptrsize:4");
					else if (strcmp(packetBuf + 1, "ProcessInfo") == 0)
						sendPacket("pid:1");
					else if (strcmp(packetBuf + 1, "fThreadInfo") == 0)
						sendPacket("m1,2,3,4");
					else if (strcmp(packetBuf + 1, "sThreadInfo") == 0)
						sendPacket("l");
					else if (memcmp(packetBuf + 1, "ThreadStopInfo", 14) == 0)
						sendPacket("T00");
					else if (memcmp(packetBuf + 1, "RegisterInfo", 12) == 0)
					{
						int regId = strtoul(packetBuf + 13, NULL, 16);
						if (regId < 32)
						{
							sprintf(response, "name:s%d;bitsize:32;encoding:uint;format:hex;set:General Purpose Scalar Registers;gcc:%d;dwarf:%d;",
								regId, regId, regId);
								
							if (regId >= 28)
								sprintf(response + strlen(response), "generic:%s;", kGenericRegs[regId - 28]);
						}
						else if (regId < 64)
						{
							sprintf(response, "name:v%d;bitsize:512;encoding:uint;format:vector-uint32;set:General Purpose Vector Registers;gcc:%d;dwarf:%d;",
								regId - 32, regId, regId);
						}
						else
							sprintf(response, "");
						
						sendPacket(response);
					}
					else if (strcmp(packetBuf + 1, "C") == 0)
					{
						sprintf(response, "QC%02x", getCurrentStrand(core) + 1);
						sendPacket(response);
					}
					else
						sendPacket("");	// Not supported
					
					break;
					
				// Set arguments
				case 'A':
					sendPacket("OK");	// Yeah, whatever
					break;
					
					
				// continue
				case 'C':
				case 'c':
					runUntilInterrupt(core);
					sendPacket("T00");
					break;
					
				// Step
				case 's':
				case 'S':
					singleStep(core);
					sendPacket("T00");
					break;
					
				// Pick thread
				case 'H':
					if (packetBuf[1] == 'g')
					{
						sendPacket("OK");
						printf("set thread %d\n", packetBuf[2] - '1');
					}
					else
						sendPacket("");

					break;
					
					
				// read register
				case 'p':
				case 'g':
				{
					int regId = strtoul(packetBuf + 1, NULL, 16);
					int value;
					if (regId < 32)
					{
						value = getScalarRegister(core, regId);
						sprintf(response, "%08x", value);
						sendPacket(response);
					}
					else if (regId < 64)
					{
						int lane;
						
						for (lane = 0; lane < 16; lane++)
						{
							value = getVectorRegister(core, regId, lane);
							sprintf(response + lane * 8, "%08x", value);
						}

						sendPacket(response);
					}
					else
						sendPacket("");
				
					break;
				}
					
				// Multi-character command
				case 'v':
					if (strcmp(packetBuf, "vCont?") == 0)
						sendPacket("vCont;C;c;S;s");
					else if (memcmp(packetBuf, "vCont;", 6) == 0)
					{
						if (packetBuf[6] == 's')
						{
							int threadId = strtoul(packetBuf + 8, NULL, 16);
							setCurrentStrand(core, threadId);
							singleStep(core);
							sendPacket("T00");
						}
						else if (packetBuf[6] == 'c')
						{
							runUntilInterrupt(core);
							
							// XXX stop response
							sendPacket("T00");
						}
					}
					else
						sendPacket("");
					
					break;
					
				// Get last signal
				case '?':
					sprintf(response, "T00");
					sendPacket(response);
					break;
					
				// Unknown
				default:
					sendPacket("");
			}
		}
		
		printf("Disconnected from debugger\n");
		close(clientSocket);
	}
}

