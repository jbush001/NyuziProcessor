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
// This module exposes the standard filesystem calls read, write, open, close,
// lseek. It uses a very simple read-only filesystem format that is created by
// tools/mkfs.  It reads the raw data from the sdmmc driver.
//
// THESE ARE NOT THREAD SAFE. Only one thread should call them.
// These do not perform any caching.
//

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "sdmmc.h"
#include "unistd.h"

#define FS_MAGIC "spfs"
#define MAX_DESCRIPTORS 32
#define RAMDISK_BASE ((unsigned char*) 0x4000000)

struct file_descriptor
{
    int is_open;
    int file_length;
    int start_offset;
    int current_offset;
};

struct directory_entry
{
    unsigned int start_offset;
    unsigned int length;
    char name[32];
};

struct fs_header
{
    char magic[4];
    unsigned int num_directory_entries;
    struct directory_entry dir[1];
};

static struct file_descriptor file_descriptors[MAX_DESCRIPTORS];
static int fs_initialized;
static struct fs_header *fs_directory;
static int use_ramdisk = 0;

int read_block(int block_num, void *ptr)
{
    if (use_ramdisk)
    {
        memcpy(ptr, RAMDISK_BASE + block_num * BLOCK_SIZE, BLOCK_SIZE);
        return BLOCK_SIZE;
    }
    else
        return read_sdmmc_device(block_num, ptr);
}

static int init_file_system(void)
{
    char super_block[BLOCK_SIZE];
    int num_directory_blocks;
    int block_num;
    struct fs_header *header;

    // SDMMC not supported on FPGA currently. Fall back to ramdisk if it fails.
    if (init_sdmmc_device() < 0)
    {
        printf("SDMMC init failed, using ramdisk\n");
        use_ramdisk = 1;
    }

    // Read directory
    if (read_block(0, super_block) <= 0)
    {
        errno = EIO;
        return -1;
    }

    header = (struct fs_header*) super_block;
    if (memcmp(header->magic, FS_MAGIC, 4) != 0)
    {
        printf("Bad filesystem: invalid magic value\n");
        errno = EIO;
        return -1;
    }

    num_directory_blocks = ((header->num_directory_entries - 1) * sizeof(struct directory_entry)
                            + sizeof(struct fs_header) + BLOCK_SIZE - 1) / BLOCK_SIZE;
    fs_directory = (struct fs_header*) malloc(num_directory_blocks * BLOCK_SIZE);
    memcpy(fs_directory, super_block, BLOCK_SIZE);
    for (block_num = 1; block_num < num_directory_blocks; block_num++)
    {
        if (read_block(block_num, ((char*)fs_directory) + BLOCK_SIZE * block_num) <= 0)
        {
            errno = EIO;
            return -1;
        }
    }

    return 0;
}

static struct directory_entry *lookup_file(const char *path)
{
    unsigned int directory_index;

    for (directory_index = 0; directory_index < fs_directory->num_directory_entries; directory_index++)
    {
        struct directory_entry *entry = fs_directory->dir + directory_index;
        if (strcmp(entry->name, path) == 0)
            return entry;
    }

    return NULL;
}

int open(const char *path, int mode)
{
    int fd;
    struct file_descriptor *fd_ptr;
    struct directory_entry *entry;

    (void) mode;	// mode is ignored

    if (!fs_initialized)
    {
        if (init_file_system() < 0)
            return -1;

        fs_initialized = 1;
    }

    for (fd = 0; fd < MAX_DESCRIPTORS; fd++)
    {
        if (!file_descriptors[fd].is_open)
            break;
    }

    if (fd == MAX_DESCRIPTORS)
    {
        // Too many files open
        errno = EMFILE;
        return -1;
    }

    fd_ptr = &file_descriptors[fd];

    // Search for file
    entry = lookup_file(path);
    if (entry)
    {
        fd_ptr->is_open = 1;
        fd_ptr->file_length = entry->length;
        fd_ptr->start_offset = entry->start_offset;
        fd_ptr->current_offset = 0;
        return fd;
    }

    errno = ENOENT;
    return -1;
}

int close(int fd)
{
    if (fd < 0 || fd >= MAX_DESCRIPTORS)
    {
        errno = EBADF;
        return -1;
    }

    file_descriptors[fd].is_open = 0;
    return 0;
}

int read(int fd, void *buf, unsigned int nbytes)
{
    unsigned int size_to_copy;
    struct file_descriptor *fd_ptr;
    unsigned int slice_length;
    unsigned int total_read;
    char current_block[BLOCK_SIZE];
    int offset_in_block;
    int block_number;

    if (fd < 0 || fd >= MAX_DESCRIPTORS)
    {
        errno = EBADF;
        return -1;
    }

    fd_ptr = &file_descriptors[fd];
    if (!fd_ptr->is_open)
    {
        errno = EBADF;
        return -1;
    }

    size_to_copy = fd_ptr->file_length - fd_ptr->current_offset;
    if (size_to_copy <= 0)
        return 0;	// End of file

    if (nbytes > size_to_copy)
        nbytes = size_to_copy;

    offset_in_block = fd_ptr->current_offset & (BLOCK_SIZE - 1);
    block_number = (fd_ptr->start_offset + fd_ptr->current_offset) / BLOCK_SIZE;

    total_read = 0;
    while (total_read < nbytes)
    {
        if (offset_in_block == 0 && (nbytes - total_read) >= BLOCK_SIZE)
        {
            if (read_block(block_number, (char*) buf + total_read) <= 0)
            {
                errno = EIO;
                return -1;
            }

            total_read += BLOCK_SIZE;
            block_number++;
        }
        else
        {
            if (read_block(block_number, current_block) <= 0)
            {
                errno = EIO;
                return -1;
            }

            slice_length = BLOCK_SIZE - offset_in_block;
            if (slice_length > nbytes - total_read)
                slice_length = nbytes - total_read;

            memcpy((char*) buf + total_read, current_block + offset_in_block, slice_length);
            total_read += slice_length;
            offset_in_block = 0;
            block_number++;
        }
    }

    fd_ptr->current_offset += nbytes;

    return nbytes;
}

int write(int fd, const void *buf, unsigned int nbyte)
{
    (void) fd;
    (void) buf;
    (void) nbyte;

    errno = EPERM;
    return -1;	// Read-only filesystem
}

off_t lseek(int fd, off_t offset, int whence)
{
    struct file_descriptor *fd_ptr;
    if (fd < 0 || fd >= MAX_DESCRIPTORS)
    {
        errno = EBADF;
        return -1;
    }

    fd_ptr = &file_descriptors[fd];
    if (!fd_ptr->is_open)
    {
        errno = EBADF;
        return -1;
    }

    switch (whence)
    {
        case SEEK_SET:
            fd_ptr->current_offset = offset;
            break;

        case SEEK_CUR:
            fd_ptr->current_offset += offset;
            break;

        case SEEK_END:
            fd_ptr->current_offset = fd_ptr->file_length - offset;
            break;

        default:
            errno = EINVAL;
            return -1;
    }

    if (fd_ptr->current_offset < 0)
        fd_ptr->current_offset = 0;

    return fd_ptr->current_offset;
}

int stat(const char *path, struct stat *buf)
{
    struct directory_entry *entry;

    entry = lookup_file(path);
    if (!entry)
    {
        errno = ENOENT;
        return -1;
    }

    buf->st_size = entry->length;

    return 0;
}

int fstat(int fd, struct stat *buf)
{
    struct file_descriptor *fd_ptr;
    if (fd < 0 || fd >= MAX_DESCRIPTORS)
    {
        errno = EBADF;
        return -1;
    }

    fd_ptr = &file_descriptors[fd];
    if (!fd_ptr->is_open)
    {
        errno = EBADF;
        return -1;
    }

    buf->st_size = fd_ptr->file_length;

    return 0;
}

int access(const char *path, int mode)
{
    struct directory_entry *entry;

    entry = lookup_file(path);
    if (!entry)
    {
        errno = ENOENT;
        return -1;
    }

    if (mode & W_OK)
    {
        errno = EPERM;
        return -1;	// Read only filesystem
    }

    return 0;
}
