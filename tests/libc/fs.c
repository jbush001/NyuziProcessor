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

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define CHECK(cond) if (!(cond)) { printf("TEST FAILED: %s:%d: %s\n", __FILE__, __LINE__, \
	#cond); abort(); }

const char *kExpectString = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";

int main(int argc, const char *argv[])
{
    int fd;
    int result;
    char tmp[32];

    fd = open("fstest.txt", 0);
    CHECK(fd >= 0);

    // Full read
    result = read(fd, tmp, 32);
    CHECK(result == 32);
    CHECK(memcmp(tmp, kExpectString, 32) == 0);

    // Short read
    result = read(fd, tmp, 32);
    CHECK(result == 30);
    CHECK(memcmp(tmp, kExpectString + 32, 30) == 0);

    // Seek and read
    CHECK(lseek(fd, 7, SEEK_SET) == 7);
    result = read(fd, tmp, 8);
    CHECK(result == 8);
    CHECK(memcmp(tmp, kExpectString + 7, 8) == 0);

    // Close
    result = close(fd);
    CHECK(result == 0);

    // Make sure FD is closed
    result = read(fd, tmp, 32);
    CHECK(result == -1);
    CHECK(errno == EBADF);

    // Missing file
    fd = open("foo.txt", 0);
    CHECK(fd == -1);
    CHECK(errno == ENOENT);

    // Bad file descriptor
    result = read(7, tmp, 32);
    CHECK(result == -1);
    CHECK(errno == EBADF);

    // Invalid file descriptor
    result = read(-2, tmp, 32);
    CHECK(result == -1);
    CHECK(errno == EBADF);

    // Bad file descriptor on close
    result = close(-1);
    CHECK(result == -1);
    CHECK(errno == EBADF);

    // Valid access
    CHECK(access("fstest.txt", R_OK) == 0);

    // Invalid permissions
    CHECK(access("fstest.txt", W_OK) == -1);
    CHECK(errno == EPERM);

    // Missing file
    CHECK(access("baz.txt", R_OK) == -1);
    CHECK(errno == ENOENT);

    printf("PASS\n");
    return 0;
}
