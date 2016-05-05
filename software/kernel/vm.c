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

#include "vm.h"
#include "memory_map.h"
#include "spinlock.h"

#define MEMORY_SIZE 0x1000000
#define PA_TO_VA(x) ((unsigned int) (x) + PHYS_MEM_ALIAS)

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

extern unsigned int _end;
extern unsigned int page_dir_addr;
extern unsigned int boot_pages_used;

static unsigned int next_alloc_page;
static spinlock_t pgt_lock;

unsigned int boot_vm_allocate_pages(struct boot_page_setup *bps, int num_pages)
{
    unsigned int pa = bps->next_alloc_page;
    bps->next_alloc_page += PAGE_SIZE * num_pages;
    memset((void*) pa, 0, PAGE_SIZE * num_pages);
    return pa;
}

void boot_vm_map_pages(struct boot_page_setup *bps, unsigned int va, unsigned int pa,
                    unsigned int length, unsigned int flags)
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

void boot_setup_page_tables(void)
{
    // Need a local since we can't access globals
    struct boot_page_setup bps;

    unsigned int kernel_size = PAGE_ALIGN(((unsigned int) &_end) + 0xfff) - KERNEL_BASE;
    bps.next_alloc_page = kernel_size;
    bps.pgdir = (unsigned int*) boot_vm_allocate_pages(&bps, 1);

    // Map kernel
    boot_vm_map_pages(&bps, KERNEL_BASE, 0, kernel_size, PAGE_PRESENT | PAGE_WRITABLE
        | PAGE_EXECUTABLE | PAGE_SUPERVISOR | PAGE_GLOBAL);

    // Map physical memory alias
    boot_vm_map_pages(&bps, PHYS_MEM_ALIAS, 0, MEMORY_SIZE, PAGE_PRESENT | PAGE_WRITABLE
        | PAGE_SUPERVISOR | PAGE_GLOBAL);

    // Map initial kernel stacks
    boot_vm_map_pages(&bps, INITIAL_KERNEL_STACKS, boot_vm_allocate_pages(&bps, 0x10), 0x10000,
        PAGE_PRESENT | PAGE_WRITABLE | PAGE_SUPERVISOR | PAGE_GLOBAL);

    // Map device registers
    boot_vm_map_pages(&bps, DEVICE_REG_BASE, DEVICE_REG_BASE, PAGE_SIZE, PAGE_PRESENT
                   | PAGE_WRITABLE | PAGE_SUPERVISOR | PAGE_GLOBAL);

    // Write the page dir address where start.S can find it to initialize threads.
    // Using address of will return the virtual address that this will be mapped to.
    // However, since MMU is still off, need to convert to the physical address.
    unsigned int *pgptr = (unsigned int*) (((unsigned int) &page_dir_addr) & 0xffffff);
    *pgptr = (unsigned int) bps.pgdir;

    unsigned int *boot_pages_used_ptr = (unsigned int*) (((unsigned int)
        &boot_pages_used) & 0xffffff);
    *boot_pages_used_ptr = (unsigned int) bps.next_alloc_page;
}

// This is called after the MMU has been enabled
void vm_init(void)
{
    next_alloc_page = boot_pages_used;
}

// XXX hack
unsigned int vm_allocate_page(void)
{
    unsigned int pa = next_alloc_page;
    next_alloc_page += PAGE_SIZE;
    return pa;
}

void vm_map_page(unsigned int va, unsigned int pa)
{
    int vpindex = va / PAGE_SIZE;
    int pgdindex = vpindex / 1024;
    int pgtindex = vpindex % 1024;
    unsigned int *pgdir = PA_TO_VA(__builtin_nyuzi_read_control_reg(10));
    unsigned int *pgtbl;

    acquire_spinlock(&pgt_lock);

    if ((pgdir[pgdindex] & PAGE_PRESENT) == 0)
        pgdir[pgdindex] = vm_allocate_page() | PAGE_PRESENT;

    pgtbl = (unsigned int*) PAGE_ALIGN(pgdir[pgdindex]);
    ((unsigned int*)PA_TO_VA(pgtbl))[pgtindex] = pa;
    asm("tlbinval %0" : : "s" (va));

    // XXX does not invalidate on other cores

    release_spinlock(&pgt_lock);
}

