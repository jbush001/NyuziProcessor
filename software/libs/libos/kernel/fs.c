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
#include "unistd.h"


int open(const char *path, int mode)
{
    (void) path;
    (void) mode;

    errno = EINVAL;
    return -1;
}

int close(int fd)
{
    (void) fd;

    errno = EBADF;
    return -1;
}

int read(int fd, void *buf, unsigned int nbyte)
{
    (void) fd;
    (void) buf;
    (void) nbyte;

    errno = EBADF;
    return -1;
}

int write(int fd, const void *buf, unsigned int nbyte)
{
    (void) fd;
    (void) buf;
    (void) nbyte;

    errno = EPERM;
    return -1;
}

off_t lseek(int fd, off_t offset, int whence)
{
    (void) fd;
    (void) offset;
    (void) whence;

    errno = EBADF;
    return -1;
}

int stat(const char *path, struct stat *buf)
{
    (void) path;
    (void) buf;

    errno = EINVAL;
    return -1;
}

int fstat(int fd, struct stat *buf)
{
    (void) fd;
    (void) buf;

    errno = EBADF;
    return -1;
}

int access(const char *path, int mode)
{
    (void) path;
    (void) mode;

    errno = EBADF;
    return -1;
}
