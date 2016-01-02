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

#pragma once

#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2

#define O_RDONLY 1
#define O_BINARY 2

#define R_OK 1
#define W_OK 2

typedef int off_t;
typedef unsigned int useconds_t;

struct stat
{
    off_t st_size;
};

#ifdef __cplusplus
extern "C" {
#endif

int open(const char *path, int mode);
int close(int fd);
int read(int fd, void *buf, unsigned int nbyte);
int write(int fd, const void *buf, unsigned int nbyte);
off_t lseek(int fd, off_t offset, int whence);
int stat(const char *path, struct stat *buf);
int fstat(int fd, struct stat *buf);
int access(const char *pathname, int mode);
int usleep(useconds_t);

#ifdef __cplusplus
}
#endif

