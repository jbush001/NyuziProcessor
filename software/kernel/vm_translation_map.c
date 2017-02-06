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

#include "asm.h"
#include "libc.h"
#include "slab.h"
#include "trap.h"
#include "vm_page.h"
#include "vm_translation_map.h"

#define BOOT_VA_TO_PA(x) (((unsigned int) (x)) & 0xffffff)

//
// boot_vm_allocate_pages, boot_vm_map_pages, and boot_setup_page_tables
// are called when the MMU is disabled, so they run at their physical
// addresses in low memory rather than the proper virtual address that the
// kernel is linked at. Therefore, they can't use non-position-independent
// constructs like global variables and switch statements.
//

// Since we can't use globals, this structure is shared between functions
// to hold common state.
struct boot_page_setup
{
    unsigned int next_alloc_page;
    unsigned int *pgdir;
};

extern unsigned int page_dir_addr;
extern unsigned int boot_pages_used;
static spinlock_t kernel_space_lock;
static unsigned int next_asid;
static struct vm_translation_map kernel_map;
static struct list_node map_list;
MAKE_SLAB(translation_map_slab, struct vm_translation_map)

unsigned int boot_vm_allocate_pages(struct boot_page_setup *bps, unsigned int num_pages)
{
    unsigned int pa = bps->next_alloc_page;
    bps->next_alloc_page += PAGE_SIZE * num_pages;
    memset((void*) pa, 0, PAGE_SIZE * num_pages);
    return pa;
}

void boot_vm_map_pages(struct boot_page_setup *bps, unsigned int va,
                       unsigned int pa, unsigned int length, unsigned int flags)
{
    int ppindex = va / PAGE_SIZE;
    int pgdindex = ppindex / 1024;
    int pgtindex = ppindex % 1024;
    unsigned int *pgtbl;

    while (length > 0)
    {
        // Allocate page table if necessary
        if (bps->pgdir[pgdindex] == 0)
            bps->pgdir[pgdindex] = boot_vm_allocate_pages(bps, 1) | PAGE_PRESENT;

        pgtbl = (unsigned int*) PAGE_ALIGN(bps->pgdir[pgdindex]);

        // Fill in page table entries
        while (length > 0 && pgtindex < 1024)
        {
            pgtbl[pgtindex++] = pa | flags;
            length -= PAGE_SIZE;
            pa += PAGE_SIZE;
        }

        // Advance to next page dir entry
        pgdindex++;
        pgtindex = 0;
    }
}

void boot_setup_page_tables(unsigned int memory_size)
{
    // Need a local since we can't access globals
    struct boot_page_setup bps;

    unsigned int kernel_size = KERNEL_END - KERNEL_BASE;
    bps.next_alloc_page = kernel_size;
    bps.pgdir = (unsigned int*) boot_vm_allocate_pages(&bps, 1);

    // Map kernel
    boot_vm_map_pages(&bps, KERNEL_BASE, 0, kernel_size, PAGE_PRESENT | PAGE_WRITABLE
                      | PAGE_EXECUTABLE | PAGE_SUPERVISOR | PAGE_GLOBAL);

    // Map physical memory alias
    boot_vm_map_pages(&bps, PHYS_MEM_ALIAS, 0, memory_size, PAGE_PRESENT | PAGE_WRITABLE
                      | PAGE_SUPERVISOR | PAGE_GLOBAL);

    // Map initial kernel stacks for all threads
    boot_vm_map_pages(&bps, INITIAL_KERNEL_STACKS, boot_vm_allocate_pages(&bps, 0x10),
                      KERNEL_STACK_SIZE * 4, PAGE_PRESENT | PAGE_WRITABLE
                      | PAGE_SUPERVISOR | PAGE_GLOBAL);

    // Map device registers
    boot_vm_map_pages(&bps, DEVICE_REG_BASE, DEVICE_REG_BASE, 0x10000, PAGE_PRESENT
                      | PAGE_WRITABLE | PAGE_SUPERVISOR | PAGE_GLOBAL);

    // Map preallocated space on the kernel heap for page structures. This
    // needs to be done early in boot because vm_map_page may call into the
    // page allocator to allocate page tables, and that won't work until the
    // page tables are allocated.
    boot_vm_map_pages(&bps, KERNEL_HEAP_BASE, boot_vm_allocate_pages(&bps,
                      PAGE_STRUCTURES_SIZE(memory_size) / PAGE_SIZE),
                      PAGE_STRUCTURES_SIZE(memory_size),
                      PAGE_PRESENT | PAGE_WRITABLE | PAGE_SUPERVISOR | PAGE_GLOBAL);

    // Write the page dir address where start.S can find it to initialize
    // threads. Using address of will return the virtual address that this
    // will be mapped to. However, since MMU is still off, need to convert
    // to the physical address.
    *((unsigned int*) BOOT_VA_TO_PA(&page_dir_addr)) = (unsigned int) bps.pgdir;
    *((unsigned int*) BOOT_VA_TO_PA(&boot_pages_used)) = (unsigned int)
            bps.next_alloc_page / PAGE_SIZE;
}

// This is called after the MMU has been enabled
struct vm_translation_map *vm_translation_map_init(void)
{
    list_init(&map_list);
    kernel_map.page_dir = __builtin_nyuzi_read_control_reg(10);
    return &kernel_map;
}

struct vm_translation_map *create_translation_map(void)
{
    struct vm_translation_map *map;
    int old_flags;

    map = slab_alloc(&translation_map_slab);
    map->page_dir = page_to_pa(vm_allocate_page());

    old_flags = acquire_spinlock_int(&kernel_space_lock);
    // Copy kernel page tables into new page directory
    memcpy((unsigned int*) PA_TO_VA(map->page_dir) + 768,
           (unsigned int*) PA_TO_VA(kernel_map.page_dir) + 768,
           256 * sizeof(unsigned int));

    map->asid = next_asid++;
    map->lock = 0;

    list_add_tail(&map_list, (struct list_node*) map);
    release_spinlock_int(&kernel_space_lock, old_flags);

    return map;
}

void destroy_translation_map(struct vm_translation_map *map)
{
    int i;
    unsigned int *pgdir;
    int old_flags;

    old_flags = acquire_spinlock_int(&kernel_space_lock);
    list_remove_node(map);
    release_spinlock_int(&kernel_space_lock, old_flags);

    // Free user space page tables
    pgdir = (unsigned int*) PA_TO_VA(map->page_dir);
    for (i = 0; i < 768; i++)
    {
        if (pgdir[i] & PAGE_PRESENT)
            dec_page_ref(pa_to_page(PAGE_ALIGN(pgdir[i])));
    }

    dec_page_ref(pa_to_page(map->page_dir));
    slab_free(&translation_map_slab, map);
}

void vm_map_page(struct vm_translation_map *map, unsigned int va, unsigned int pa)
{
    int vpindex = va / PAGE_SIZE;
    int pgdindex = vpindex / 1024;
    int pgtindex = vpindex % 1024;
    unsigned int *pgdir;
    unsigned int *pgtbl;
    struct list_node *other_map;
    unsigned int new_pgt;
    int old_flags;

    if (va >= KERNEL_BASE)
    {
        // Map into kernel space
        old_flags = acquire_spinlock_int(&kernel_space_lock);

        // The page tables for kernel space are shared by all page directories.
        // Check the first page directory to see if this is present. If not,
        // allocate a new one and stick it into all page directories.
        pgdir = (unsigned int*) PA_TO_VA(kernel_map.page_dir);
        if ((pgdir[pgdindex] & PAGE_PRESENT) == 0)
        {
            new_pgt = page_to_pa(vm_allocate_page()) | PAGE_PRESENT;
            list_for_each(&map_list, other_map, struct list_node)
            {
                pgdir = (unsigned int*) PA_TO_VA(((struct vm_translation_map*)other_map)->page_dir);
                pgdir[pgdindex] = new_pgt;
            }
        }

        // Now add entry to the page table
        pgtbl = (unsigned int*) PAGE_ALIGN(pgdir[pgdindex]);
        ((unsigned int*)PA_TO_VA(pgtbl))[pgtindex] = pa;
        __asm__("tlbinval %0" : : "s" (va));

        // XXX need to invalidate on other cores

        release_spinlock_int(&kernel_space_lock, old_flags);
    }
    else
    {
        // Map only into this address space
        old_flags = acquire_spinlock_int(&map->lock);
        pgdir = (unsigned int*) PA_TO_VA(map->page_dir);
        if ((pgdir[pgdindex] & PAGE_PRESENT) == 0)
            pgdir[pgdindex] = page_to_pa(vm_allocate_page()) | PAGE_PRESENT;

        pgtbl = (unsigned int*) PAGE_ALIGN(pgdir[pgdindex]);
        ((unsigned int*)PA_TO_VA(pgtbl))[pgtindex] = pa;
        __asm__("tlbinval %0" : : "s" (va));

        // XXX need to invalidate on other cores

        release_spinlock_int(&map->lock, old_flags);
    }
}

unsigned int query_translation_map(struct vm_translation_map *map, unsigned int va)
{
    int vpindex = va / PAGE_SIZE;
    int pgdindex = vpindex / 1024;
    int pgtindex = vpindex % 1024;
    unsigned int *pgdir;
    unsigned int *pgtbl;
    int old_flags;
    unsigned int ptentry;

    if (va >= KERNEL_BASE)
    {
        // Check kernel space
        old_flags = acquire_spinlock_int(&kernel_space_lock);

        // The page tables for kernel space are shared by all page directories.
        // Check the first page directory to see if this is present.
        pgdir = (unsigned int*) PA_TO_VA(kernel_map.page_dir);
        if ((pgdir[pgdindex] & PAGE_PRESENT) == 0)
            ptentry = 0;
        else
        {
            pgtbl = (unsigned int*) PAGE_ALIGN(pgdir[pgdindex]);
            ptentry = ((unsigned int*)PA_TO_VA(pgtbl))[pgtindex];
        }

        release_spinlock_int(&kernel_space_lock, old_flags);
    }
    else
    {
        // Check this user space
        old_flags = acquire_spinlock_int(&map->lock);
        pgdir = (unsigned int*) PA_TO_VA(map->page_dir);
        if ((pgdir[pgdindex] & PAGE_PRESENT) == 0)
            ptentry = 0;
        else
        {
            pgtbl = (unsigned int*) PAGE_ALIGN(pgdir[pgdindex]);
            ptentry = ((unsigned int*)PA_TO_VA(pgtbl))[pgtindex];
        }

        release_spinlock_int(&map->lock, old_flags);
    }

    return ptentry;
}

void switch_to_translation_map(struct vm_translation_map *map)
{
    // XXX if there are more maps that ASIDs and this map doesn't have an
    // ASID assigned, this must be able to steal it.

    __builtin_nyuzi_write_control_reg(CR_PAGE_DIR_BASE, map->page_dir);
    __builtin_nyuzi_write_control_reg(CR_CURRENT_ASID, map->asid);
}

