//
// Copyright 2016 Jeff Bush
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

#include <stdio.h>
#include <string.h>

// Wrappers keep LLVM from creating inline versions of these automatically

int get_sign(int value)
{
    if (value < 0)
        return -1;
    else if (value > 0)
        return 1;

    return 0;
}

int __attribute__((noinline)) noinline_strcmp(const char *str1, const char *str2)
{
    return strcmp(str1, str2);
}

int __attribute__((noinline)) noinline_memcmp(const void *a, const void *b, size_t length)
{
    return memcmp(a, b, length);
}

int __attribute__((noinline)) noinline_strcasecmp(const char *str1, const char *str2)
{
    return strcasecmp(str1, str2);
}

int __attribute__((noinline)) noinline_strncasecmp(const char *str1, const char *str2,
    size_t length)
{
    return strncasecmp(str1, str2, length);
}

int __attribute__((noinline)) noinline_strncmp(const char *str1, const char *str2,
    size_t len)
{
    return strncmp(str1, str2, len);
}

size_t __attribute__((noinline)) noinline_strlen(const char *str)
{
    return strlen(str);
}

char __attribute__((noinline)) *noinline_strcpy(char *dest, const char *src)
{
    return strcpy(dest, src);
}

char __attribute__((noinline)) *noinline_strncpy(char *dest, const char *src,
    size_t length)
{
    return strncpy(dest, src, length);
}

char __attribute__((noinline)) *noinline_strchr(const char *string, int c)
{
    return strchr(string, c);
}

void __attribute__((noinline)) *noinline_memchr(const void *string, int c, size_t n)
{
    return memchr(string, c, n);
}

char __attribute__((noinline)) *noinline_strcat(char *c, const char *s)
{
    return strcat(c, s);
}

int main()
{
    char dest[64];

    printf("1.1 %d\n", get_sign(noinline_strcmp("foo", "foot")));   // CHECK: 1.1 -1
    printf("1.2 %d\n", get_sign(noinline_strcmp("foo", "fpo")));    // CHECK: 1.2 -1
    printf("1.3 %d\n", get_sign(noinline_strcmp("foo", "foo")));    // CHECK: 1.3 0
    printf("1.4 %d\n", get_sign(noinline_strcmp("foot", "foo")));   // CHECK: 1.4 1
    printf("1.5 %d\n", get_sign(noinline_strcmp("fpo", "foo")));    // CHECK: 1.5 1

    printf("2.1 %d\n", get_sign(noinline_memcmp("aaa", "aab", 3)));    // CHECK: 2.1 -1
    printf("2.2 %d\n", get_sign(noinline_memcmp("aab", "aaa", 3)));    // CHECK: 2.2 1
    printf("2.3 %d\n", get_sign(noinline_memcmp("aaa", "aaa", 3)));    // CHECK: 2.3 0

    printf("3.1 %d\n", get_sign(noinline_strcasecmp("foo", "foot")));   // CHECK: 3.1 -1
    printf("3.2 %d\n", get_sign(noinline_strcasecmp("foo", "fpo")));    // CHECK: 3.2 -1
    printf("3.3 %d\n", get_sign(noinline_strcasecmp("foo", "foo")));    // CHECK: 3.3 0
    printf("3.4 %d\n", get_sign(noinline_strcasecmp("Foo", "foo")));    // CHECK: 3.4 0
    printf("3.5 %d\n", get_sign(noinline_strcasecmp("foot", "foo")));   // CHECK: 3.5 1
    printf("3.6 %d\n", get_sign(noinline_strcasecmp("fpo", "foo")));    // CHECK: 3.6 1

    printf("4.1 %d\n", get_sign(noinline_strncasecmp("foo", "foot", 4)));   // CHECK: 4.1 -1
    printf("4.2 %d\n", get_sign(noinline_strncasecmp("foo", "fpo", 4)));    // CHECK: 4.2 -1
    printf("4.3 %d\n", get_sign(noinline_strncasecmp("foo", "foo", 4)));    // CHECK: 4.3 0
    printf("4.4 %d\n", get_sign(noinline_strncasecmp("Foo", "foo", 4)));    // CHECK: 4.4 0
    printf("4.5 %d\n", get_sign(noinline_strncasecmp("Foot", "foo", 3)));   // CHECK: 4.5 0
    printf("4.6 %d\n", get_sign(noinline_strncasecmp("foot", "foo", 4)));   // CHECK: 4.6 1
    printf("4.7 %d\n", get_sign(noinline_strncasecmp("fpo", "foo", 4)));    // CHECK: 4.7 1

    printf("5.1 %d\n", get_sign(noinline_strncmp("foo", "foot", 4)));   // CHECK: 5.1 -1
    printf("5.2 %d\n", get_sign(noinline_strncmp("foo", "fpo", 4)));    // CHECK: 5.2 -1
    printf("5.3 %d\n", get_sign(noinline_strncmp("foo", "foo", 4)));    // CHECK: 5.3 0
    printf("5.4 %d\n", get_sign(noinline_strncmp("foot", "foo", 3)));   // CHECK: 5.4 0
    printf("5.5 %d\n", get_sign(noinline_strncmp("foot", "foo", 4)));   // CHECK: 5.5 1
    printf("5.6 %d\n", get_sign(noinline_strncmp("fpo", "foo", 4)));    // CHECK: 5.6 1

    printf("6.1 %d\n", noinline_strlen(""));        // CHECK: 6.1 0
    printf("6.2 %d\n", noinline_strlen("a"));       // CHECK: 6.2 1
    printf("6.3 %d\n", noinline_strlen("ab"));      // CHECK: 6.3 2
    printf("6.4 %d\n", noinline_strlen("abcdefg")); // CHECK: 6.4 7

    noinline_strcpy(dest, "jasdfha");
    printf("7.1 \"%s\"\n", dest);   // CHECK: 7.1 "jasdfha"

    // This string is shorter. Ensure it null terminates properly.
    noinline_strcpy(dest, "zyx");
    printf("7.2 \"%s\"\n", dest);   // CHECK: 7.2 "zyx"

    noinline_strncpy(dest, "poiuytrewq", 16);
    printf("8.1 \"%s\"\n", dest);   // CHECK: 8.1 "poiuytrewq"

    // Copy over top of previous string.
    // Check that this doesn't null terminate and only copies 4 characters
    noinline_strncpy(dest, "lkjhgfdsa", 4);
    printf("8.2 \"%s\"\n", dest);   // CHECK: 8.2 "lkjhytrewq"

    const char *search_str = "abcdefg";
    printf("9.1 %d\n", noinline_strchr(search_str, 'a') - search_str); // CHECK: 9.1 0
    printf("9.2 %d\n", noinline_strchr(search_str, 'c') - search_str); // CHECK: 9.2 2
    printf("9.3 %d\n", noinline_strchr(search_str, 'g') - search_str); // CHECK: 9.3 6
    printf("9.4 %d\n", noinline_strchr(search_str, 'h')); // CHECK: 9.4 0

    printf("10.1 %d\n", (char*) noinline_memchr(search_str, 'a', 7) - search_str); // CHECK: 10.1 0
    printf("10.2 %d\n", (char*) noinline_memchr(search_str, 'c', 7) - search_str); // CHECK: 10.2 2
    printf("10.3 %d\n", (char*) noinline_memchr(search_str, 'g', 7) - search_str); // CHECK: 10.3 6
    printf("10.4 %d\n", (char*) noinline_memchr(search_str, 'h', 7)); // CHECK: 10.4 0
    printf("10.5 %d\n", (char*) noinline_memchr(search_str, 'd', 3)); // CHECK: 10.5 0

    dest[0] = '\0';
    noinline_strcat(dest, "abc");
    printf("11.1 %s\n", dest);  // CHECK: 11.1 abc

    noinline_strcat(dest, "def");
    printf("11.2 %s\n", dest);  // CHECK: 11.2 abcdef

    noinline_strcat(dest, "ghi");
    printf("11.3 %s\n", dest);  // CHECK: 11.3 abcdefghi
}
