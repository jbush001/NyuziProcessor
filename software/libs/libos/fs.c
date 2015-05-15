// 
// Copyright 2015 Jeff Bush
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
// This module exposes the standard filesystem calls read/write/open/close/lseek.
// It uses a very simple read-only filesystem format that is created by 
// tools/mkfs.  It reads the raw data from the sdmmc driver.
//
// THESE ARE NOT THREAD SAFE. I'm assuming only the main thread will call them.
//

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "sdmmc.h"
#include "unistd.h"

// Setting this flag will read from a ramdisk located higher in memory rather
// than the SD device. The serial_loader will transfer the ramdisk data 
// into memory.
//#define ENABLE_RAMDISK 1

#define FS_MAGIC 'spfs'
#define MAX_DESCRIPTORS 32
#define RAMDISK_BASE ((unsigned char*) 0x4000000)

typedef struct FileDescriptor FileDescriptor;
typedef struct DirectoryEntry DirectoryEntry;
typedef struct FsHeader FsHeader;

struct FileDescriptor
{
	int isOpen;
	int fileLength;
	int startOffset;
	int currentOffset;
};

struct DirectoryEntry
{
	unsigned int startOffset;
	unsigned int length;
	char name[32];
};

struct FsHeader
{
	int magic;
	int numDirectoryEntries;
	DirectoryEntry dir[1];
};

static FileDescriptor gFileDescriptors[MAX_DESCRIPTORS];
static int gInitialized;
static FsHeader *gDirectory;

int readBlock(int blockNum, void *ptr)
{
#if ENABLE_RAMDISK
	memcpy(ptr, RAMDISK_BASE + blockNum * BLOCK_SIZE, BLOCK_SIZE);
	return 1;
#else
	return readSdmmcDevice(blockNum, ptr);
#endif
}

static int initFileSystem()
{
	char superBlock[BLOCK_SIZE];
	int numDirectoryBlocks;
	int blockNum;
	FsHeader *header;
	
#if !ENABLE_RAMDISK
	initSdmmcDevice();
#endif
	
	// Read directory
	if (!readBlock(0, superBlock))
		return -1;

	header = (FsHeader*) superBlock;
	if (header->magic != FS_MAGIC)
	{
		printf("bad magic on header\n");
		return -1;
	}
	
	numDirectoryBlocks = ((header->numDirectoryEntries - 1) * sizeof(DirectoryEntry) 
		+ sizeof(FsHeader) + BLOCK_SIZE - 1) / BLOCK_SIZE;
	gDirectory = (FsHeader*) malloc(numDirectoryBlocks * BLOCK_SIZE);
	memcpy(gDirectory, superBlock, BLOCK_SIZE);
	for (blockNum = 1; blockNum < numDirectoryBlocks; blockNum++)
		readBlock(blockNum, ((char*)gDirectory) + BLOCK_SIZE * blockNum);
	
	return 0;
}

static DirectoryEntry *lookupFile(const char *path)
{
	int directoryIndex;

	for (directoryIndex = 0; directoryIndex < gDirectory->numDirectoryEntries; directoryIndex++)
	{
		DirectoryEntry *entry = gDirectory->dir + directoryIndex;
		if (strcmp(entry->name, path) == 0)
			return entry;
	}

	return NULL;
}

int open(const char *path, int mode)
{	
	int fd;
	struct FileDescriptor *fdPtr;
	DirectoryEntry *entry;

	(void) mode;	// mode is ignored
	
	if (!gInitialized)
	{
		if (initFileSystem() < 0)
			return -1;
		
		gInitialized = 1;
	}
	
	for (fd = 0; fd < MAX_DESCRIPTORS; fd++)
	{
		if (!gFileDescriptors[fd].isOpen)
			break;
	}
	
	if (fd == MAX_DESCRIPTORS)
		return -1;	// Too many files open

	fdPtr = &gFileDescriptors[fd];
	
	// Search for file
	entry = lookupFile(path);
	if (entry)
	{
		fdPtr->isOpen = 1;
		fdPtr->fileLength = entry->length;
		fdPtr->startOffset = entry->startOffset;
		fdPtr->currentOffset = 0;
		return fd;
	}
	
	return -1;
}

int close(int fd)
{
	if (fd < 0 || fd >= MAX_DESCRIPTORS)
		return -1;
	
	gFileDescriptors[fd].isOpen = 0;
	return 0;
}

int read(int fd, void *buf, unsigned int nbytes)
{
	int sizeToCopy;
	struct FileDescriptor *fdPtr;
	int sliceLength;
	int totalRead;
	char currentBlock[BLOCK_SIZE];
	int offsetInBlock;
	int blockNumber;

	if (fd < 0 || fd >= MAX_DESCRIPTORS)
		return -1;
	
	fdPtr = &gFileDescriptors[fd];
	if (!fdPtr->isOpen)
		return -1;

	sizeToCopy = fdPtr->fileLength - fdPtr->currentOffset;
	if (sizeToCopy < 0)
		return 0;	// Past end of file
	
	if (nbytes > sizeToCopy)
		nbytes = sizeToCopy;

	offsetInBlock = fdPtr->currentOffset & (BLOCK_SIZE - 1);
	blockNumber = (fdPtr->startOffset + fdPtr->currentOffset) / BLOCK_SIZE;

	totalRead = 0;
	while (totalRead < nbytes)
	{
		readBlock(blockNumber, currentBlock);
		sliceLength = BLOCK_SIZE - offsetInBlock;
		if (sliceLength > nbytes - totalRead)
			sliceLength = nbytes - totalRead;
		
		memcpy((char*) buf + totalRead, currentBlock + offsetInBlock, sliceLength);
		totalRead += sliceLength;
		offsetInBlock = 0;
		blockNumber++;
	}

	fdPtr->currentOffset += nbytes;

	return nbytes;
}

int write(int fd, const void *buf, unsigned int nbyte)
{
	return -1;	// Read-only filesystem
}

off_t lseek(int fd, off_t offset, int whence)
{
	struct FileDescriptor *fdPtr;
	if (fd < 0 || fd >= MAX_DESCRIPTORS)
		return -1;
	
	fdPtr = &gFileDescriptors[fd];
	if (!fdPtr->isOpen)
		return -1;
	
	switch (whence)
	{
		case SEEK_SET:
			fdPtr->currentOffset = offset;
			break;
			
		case SEEK_CUR:
			fdPtr->currentOffset += offset;
			break;
			
		case SEEK_END:
			fdPtr->currentOffset = fdPtr->fileLength - offset;
			break;

		default:
			return -1;
	}

	if (fdPtr->currentOffset < 0)
		fdPtr->currentOffset = 0;

	return fdPtr->currentOffset;
}

int stat(const char *path, struct stat *buf)
{
	DirectoryEntry *entry;
	
	entry = lookupFile(path);
	if (!entry)
		return -1;
	
	buf->st_size = entry->length;
	
	return 0;
}

int fstat(int fd, struct stat *buf)
{
	struct FileDescriptor *fdPtr;
	if (fd < 0 || fd >= MAX_DESCRIPTORS)
		return -1;
	
	fdPtr = &gFileDescriptors[fd];
	if (!fdPtr->isOpen)
		return -1;

	buf->st_size = fdPtr->fileLength;
	
	return 0;
}

int access(const char *path, int mode)
{
	DirectoryEntry *entry;
	
	entry = lookupFile(path);
	if (!entry)
		return -1;

	if (mode & W_OK)
		return -1;	// Read only filesystem

	return 0;
}




