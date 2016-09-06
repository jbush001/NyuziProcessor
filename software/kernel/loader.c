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

#include "elf.h"
#include "fs.h"
#include "libc.h"
#include "loader.h"
#include "thread.h"
#include "vm_cache.h"
#include "vm_page.h"
#include "vm_translation_map.h"

#define MAX_SEGMENTS 10

int load_program(struct process *proc,
                 const char *filename,
                 unsigned int *out_entry)
{
    struct Elf32_Ehdr image_header;
    struct Elf32_Phdr segments[MAX_SEGMENTS];
    struct vm_cache *image_cache;
    struct vm_cache *cow_cache = 0;
    struct vm_cache *area_cache;
    struct vm_area *area;

    struct file_handle *file = open_file(filename);
    if (file == 0)
    {
        kprintf("load_program: couldn't find executable file\n");
        return -1;
    }

    if (read_file(file, 0, &image_header, sizeof(image_header)) < 0)
    {
        kprintf("load_program: couldn't read header\n");
        return -1;
    }

    if (memcmp(image_header.e_ident, ELF_MAGIC, 4) != 0)
    {
        kprintf("load_program: not an elf file\n");
        return -1;
    }

    if (image_header.e_machine != EM_NYUZI)
    {
        kprintf("load_program: incorrect architecture\n");
        return -1;
    }

    if (image_header.e_phnum > MAX_SEGMENTS)
    {
        kprintf("load_program: image has too many segments\n");
        return -1;
    }

    if (image_header.e_phnum == 0)
    {
        kprintf("load_program: image has too few segments\n");
        return -1;
    }

    if (read_file(file, image_header.e_phoff, &segments, image_header.e_phnum
                  * sizeof(struct Elf32_Phdr)) < 0)
    {
        kprintf("load_program: error reading segment table\n");
        return -1;
    }

    image_cache = create_vm_cache(0);
    image_cache->file = file;

    for (int segment_index = 0; segment_index < image_header.e_phnum; segment_index++)
    {
        const struct Elf32_Phdr *segment = &segments[segment_index];
        unsigned int area_flags;

        if ((segment->p_type & PT_LOAD) == 0)
            continue;	// Skip non-loadable segment

        // Ignore empty segments (which are sometimes emitted by the linker)
        if (segment->p_memsz == 0)
            continue;

        kprintf("Loading segment %d offset %08x vaddr %08x file size %08x mem size %08x flags %x\n",
                segment_index, segment->p_offset, segment->p_vaddr, segment->p_filesz,
                segment->p_memsz, segment->p_flags);

        area_flags = 0;
        if (segment->p_flags & PF_W)
        {
            area_flags |= AREA_WRITABLE;

            // Use copy-on-write cache for this area
            if (cow_cache == 0)
                cow_cache = create_vm_cache(image_cache);

            area_cache = cow_cache;
        }
        else
            area_cache = image_cache;   // Shared, read-only

        if (segment->p_flags & PF_X)
            area_flags |= AREA_EXECUTABLE;

        // Map region
        area = create_area(proc->space, segment->p_vaddr, segment->p_memsz,
                           PLACE_EXACT, "program segment", area_flags, area_cache,
                           segment->p_offset);
        if (area == 0)
        {
            kprintf("create area failed, bailing\n");
            // XXX cleanup
            return -1;
        }

        area->cache_length = segment->p_filesz;
    }

    // These were created with a ref held. The new areas/copy caches now hold
    // references. Remove our references so these will go away when those are
    // dead.
    if (image_cache)
        dec_cache_ref(image_cache);

    if (cow_cache)
        dec_cache_ref(cow_cache);

    kprintf("entry point for program is %08x\n", image_header.e_entry);

    *out_entry = image_header.e_entry;
    return 0;
}
