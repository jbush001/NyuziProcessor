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
// This utility creates a simple read-only filesystem that is exposed by
// software/libs/libos/fs.c
//

#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define FS_NAME_LEN 32
#define BLOCK_SIZE 512
#define FS_MAGIC "spfs"
#define ROUND_UP(x, y) (((x + y - 1) / y) * y)

struct directory_entry
{
    unsigned int start_offset;
    unsigned int length;
    char name[FS_NAME_LEN];
};

struct fs_header
{
    char magic[4];
    unsigned int num_directory_entries;
    struct directory_entry dir[1];
};

static void normalize_file_name(char out_name[32], const char *full_path);

int main(int argc, const char *argv[])
{
    unsigned int file_index;
    unsigned file_offset;
    unsigned int num_directory_entries = (unsigned int) argc - 2;
    struct fs_header *header;
    FILE *output_fp;
    size_t header_size;

    if (argc < 2)
    {
        fprintf(stderr, "USAGE: %s <output file> <source file1> [<source file2>...]\n", argv[0]);
        return 1;
    }

    output_fp = fopen(argv[1], "wb");
    if (output_fp == NULL)
    {
        perror("error creating output file");
        return 1;
    }

    file_offset = ROUND_UP((num_directory_entries - 1) * sizeof(struct directory_entry)
                          + sizeof(struct fs_header), BLOCK_SIZE);
    printf("first file offset = %u\n", file_offset);
    header_size = sizeof(struct fs_header) + sizeof(struct directory_entry)
        * (num_directory_entries - 1);
    header = (struct fs_header*) malloc(header_size);

    // Build the directory
    for (file_index = 0; file_index < num_directory_entries; file_index++)
    {
        struct stat st;

        if (stat(argv[file_index + 2], &st) < 0)
        {
            fprintf(stderr, "error opening %s\n", argv[file_index + 2]);
            return 1;
        }

        header->dir[file_index].start_offset = file_offset;
        header->dir[file_index].length = (unsigned int) st.st_size;
        normalize_file_name(header->dir[file_index].name, argv[file_index + 2]);
        printf("Adding %s %08x %08x\n", header->dir[file_index].name,
               header->dir[file_index].start_offset,
               header->dir[file_index].length);
        file_offset = ROUND_UP(file_offset + (unsigned int) st.st_size, BLOCK_SIZE);
    }

    memcpy(header->magic, FS_MAGIC, 4);
    header->num_directory_entries = num_directory_entries;

    if (fwrite(header, header_size, 1, output_fp) != 1)
    {
        perror("error writing header");
        return 1;
    }

    // Copy file contents
    for (file_index = 0; file_index < num_directory_entries; file_index++)
    {
        char tmp[0x4000];
        fseek(output_fp, header->dir[file_index].start_offset, SEEK_SET);
        FILE *source_fp = fopen(argv[file_index + 2], "rb");
        unsigned int left_to_copy = header->dir[file_index].length;
        while (left_to_copy > 0)
        {
            unsigned int slice_length = sizeof(tmp);
            if (left_to_copy < slice_length)
                slice_length = left_to_copy;

            if (fread(tmp, slice_length, 1, source_fp) != 1)
            {
                perror("error reading from source file");
                fclose(source_fp);
                return 1;
            }

            if (fwrite(tmp, slice_length, 1, output_fp) != 1)
            {
                perror("error writing to output file");
                fclose(source_fp);
                return 1;
            }

            left_to_copy -= slice_length;
        }

        fclose(source_fp);
    }

    fclose(output_fp);

    return 0;
}

void normalize_file_name(char out_name[32], const char *full_path)
{
    const char *end = full_path + strlen(full_path) - 1;
    const char *begin = end;
    while (begin > full_path && begin[-1] != '/')
        begin--;

    if (end - begin > FS_NAME_LEN - 1)
    {
        // Truncate
        begin = end - (FS_NAME_LEN -1);
    }

    strcpy(out_name, begin);
}
