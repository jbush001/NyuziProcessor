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

#include "libc.h"
#include "slab.h"
#include "vm_area_map.h"
#include "vm_page.h"

MAKE_SLAB(area_slab, struct vm_area);

static struct vm_area *alloc_area(unsigned int low_address, unsigned int size)
{
    struct vm_area *area = slab_alloc(&area_slab);
    area->low_address = low_address;
    area->high_address = low_address + size - 1;
    return area;
}

static struct vm_area *search_up(struct vm_area_map *map, unsigned int address,
                                 unsigned int size)
{
    struct vm_area *next_area;
    unsigned int hole_start = map->low_address;

    if (address + size > map->high_address)
        return 0;

    if (address < map->low_address)
        address = map->low_address;

    address = PAGE_ALIGN(address);

    // Empty list?
    if (list_is_empty(&map->area_list))
    {
        return (struct vm_area*) list_add_tail(&map->area_list,
                                               alloc_area(address, size));
    }

    // If address is higher than the beginning of the region,
    // need to skip areas that are before it.
    next_area = list_peek_head(&map->area_list, struct vm_area);
    while (next_area && next_area->low_address < address)
    {
        hole_start = next_area->high_address + 1;
        next_area = list_next(&map->area_list, next_area, struct vm_area);
    }

    // Adjust hole start if necessary
    if (hole_start < address)
        hole_start = address;

    // Search for a hole that can fit this region
    while (next_area)
    {
        if (next_area->low_address - hole_start >= size)
            return (struct vm_area*) list_add_before(next_area, alloc_area(hole_start, size));

        hole_start = next_area->high_address + 1;
        next_area = (struct vm_area*) list_next(&map->area_list, next_area, struct list_node);
    }

    // Insert at end?
    if (map->high_address - hole_start + 1 >= size)
        return (struct vm_area*) list_add_tail(&map->area_list, alloc_area(hole_start, size));

    // No space, sorry
    return 0;
}

static struct vm_area *search_down(struct vm_area_map *map, unsigned int address,
                                   unsigned int size)
{
    struct vm_area *prev_area = list_peek_tail(&map->area_list, struct vm_area);
    unsigned int hole_end = map->high_address;

    if (address - size < map->low_address)
        return 0;

    if (address > map->high_address)
        address = map->high_address;

    address = PAGE_ALIGN(address + 1) - 1;

    // Empty list?
    if (list_is_empty(&map->area_list))
        return (struct vm_area*) list_add_tail(&map->area_list, alloc_area(address - size + 1, size));

    // If address is lower than the end of the region,
    // need to skip areas that are after it.
    while (prev_area && prev_area->high_address > address)
    {
        hole_end = prev_area->low_address - 1;
        prev_area = list_prev(&map->area_list, prev_area, struct vm_area);
    }

    // Adjust hole end if necessary
    if (hole_end > address)
        hole_end = address;

    // Search for a hole that can fit this region
    while (prev_area)
    {
        if (hole_end - prev_area->high_address + 1 >= size)
            return (struct vm_area*) list_add_after(prev_area, alloc_area(hole_end - size + 1, size));

        hole_end = prev_area->low_address - 1;
        prev_area = list_prev(&map->area_list, prev_area, struct vm_area);
    }

    // Insert at beginning?
    if (hole_end - map->low_address + 1 >= size)
        return (struct vm_area*) list_add_head(&map->area_list, alloc_area(hole_end - size + 1, size));

    // No space, sorry
    return 0;
}

static struct vm_area *insert_fixed(struct vm_area_map *map, unsigned int address,
                                    unsigned int size)
{
    struct vm_area *next_area;
    unsigned int hole_start = map->low_address;

    if (address < map->low_address || address + size - 1 > map->high_address
        || address + size - 1 < address)
        return 0;

    // Empty list?
    if (list_is_empty(&map->area_list))
        return (struct vm_area*) list_add_tail(&map->area_list, alloc_area(address, size));

    // Search list
    list_for_each(&map->area_list, next_area, struct vm_area)
    {
        if (hole_start > address)
            return 0;   // Address range is covered

        if (hole_start <= address && next_area->low_address >= address + size - 1)
            return (struct vm_area*) list_add_before(next_area, alloc_area(address, size));

        hole_start = next_area->high_address;
    }

    // Insert at end?
    if (hole_start <= address)
        return (struct vm_area*) list_add_tail(&map->area_list, alloc_area(address, size));

    // No space, sorry
    return 0;
}

void init_area_map(struct vm_area_map *map, unsigned int low_address,
                   unsigned int high_address)
{
    map->low_address = PAGE_ALIGN(low_address);
    map->high_address = PAGE_ALIGN(high_address + 1) - 1;
    list_init(&map->area_list);
}

struct vm_area *create_vm_area(struct vm_area_map *map, unsigned int address,
                               unsigned int size, enum placement place,
                               const char *name, unsigned int flags)
{
    struct vm_area *area = 0;

    size = PAGE_ALIGN(size + PAGE_SIZE - 1);
    switch (place)
    {
        case PLACE_EXACT:
            area = insert_fixed(map, address, size);
            break;

        case PLACE_SEARCH_DOWN:
            area = search_down(map, address, size);
            break;

        case PLACE_SEARCH_UP:
            area = search_up(map, address, size);
            break;
    }

    if (area)
    {
        strlcpy(area->name, name, 32);
        area->flags = flags;
        area->cache = 0;
        area->cache_offset = 0;
        area->cache_length = 0;
    }

    return area;
}

void destroy_vm_area(struct vm_area *area)
{
    list_remove_node(area);
    slab_free(&area_slab, area);
}

struct vm_area *first_area(struct vm_area_map *map)
{
    return list_peek_head(&map->area_list, struct vm_area);
}

const struct vm_area *lookup_area(const struct vm_area_map *map,
                                  unsigned int address)
{
    const struct vm_area *area;

    list_for_each(&map->area_list, area, struct vm_area)
    {
        if (address >= area->low_address && address <= area->high_address)
            return area;
    }

    return 0;
}

void dump_area_map(const struct vm_area_map *map)
{
    struct vm_area *area;

    kprintf("Name                 Start    End      Flags\n");
    list_for_each(&map->area_list, area, struct vm_area)
    {
        kprintf("%20s %08x %08x %c%c%c\n", area->name, area->low_address,
                area->high_address, (area->flags & AREA_WIRED) ? 'p' : '-',
                (area->flags & AREA_WRITABLE) ? 'w' : '-',
                (area->flags & AREA_EXECUTABLE) ? 'x' : '-');
    }
}


#ifdef TEST_AREA_MAP

static int randseed = 1;

static int rand(void)
{
    randseed = randseed * 1103515245 + 12345;
    return randseed & 0x7fffffff;
}

#define NUM_TEST_AREAS 128

static int count_areas(const struct vm_area_map *map)
{
    struct vm_area *area;
    int count = 0;

    list_for_each(&map->area_list, area, struct vm_area)
        count++;

    return count;
}

static void sanity_check_map(struct vm_area_map *map)
{
    struct vm_area *area;

    // If this is empty, ensure both pointers are correct
    assert((map->area_list.prev == &map->area_list)
        == (map->area_list.next == &map->area_list));

    list_for_each(&map->area_list, area, struct vm_area)
    {
        assert(area->low_address < area->high_address);
        assert((area->low_address & (PAGE_SIZE - 1)) == 0);
        assert((area->high_address & (PAGE_SIZE - 1)) == (PAGE_SIZE - 1));
        assert (area->list_entry.next->prev == &area->list_entry);
        assert (area->list_entry.prev->next == &area->list_entry);
    }
}

#define TEST_MAP_LOW 0x10000000
#define TEST_MAP_HIGH 0xbfffffff

void test_area_map(void)
{
    struct vm_area_map map;
    struct vm_area *areas[NUM_TEST_AREAS];
    int i;
    int expect_count = 0;
    int slot;
    unsigned int size;
    unsigned int address;
    enum placement place;

    kprintf("running area map test\n");

    init_area_map(&map, TEST_MAP_LOW, TEST_MAP_HIGH);

    //
    // Ensure areas properly abut. There is a gap of one page between areas 0
    // and 2. Insert an area between them by searching. Then create another
    // area and ensure it is below all the others
    //
    areas[0] = create_vm_area(&map, 0x30000000, 0x1000, PLACE_SEARCH_UP, "area0", 0);
    areas[1] = create_vm_area(&map, 0x30002000, 0x1000, PLACE_EXACT, "area1", 0);
    areas[2] = create_vm_area(&map, 0x30000000, 0x1000, PLACE_SEARCH_UP, "area2", 0);
    areas[3] = create_vm_area(&map, 0x30000000, 0x1000, PLACE_SEARCH_UP, "area3", 0);
    assert(count_areas(&map) == 4);
    sanity_check_map(&map);
    assert(areas[2]->low_address == 0x30001000);
    assert(areas[2]->high_address == 0x30001fff);
    assert(areas[3]->low_address == 0x30003000);
    assert(areas[3]->high_address == 0x30003fff);

    // Same as above, except searching down.
    areas[4] = create_vm_area(&map, 0x30000000, 0x1000, PLACE_SEARCH_DOWN, "area4", 0);
    areas[5] = create_vm_area(&map, 0x2fffd000, 0x1000, PLACE_EXACT, "area5", 0);
    areas[6] = create_vm_area(&map, 0x30000000, 0x1000, PLACE_SEARCH_DOWN, "area6", 0);
    areas[7] = create_vm_area(&map, 0x30000000, 0x1000, PLACE_SEARCH_DOWN, "area7", 0);
    assert(count_areas(&map) == 8);
    sanity_check_map(&map);
    assert(areas[6]->low_address = 0x2fffe000);
    assert(areas[6]->high_address == 0x2fffefff);
    assert(areas[7]->low_address == 0x2fffc000);
    assert(areas[7]->high_address == 0x2fffcfff);

    for (i = 0; i < 8; i++)
    {
        destroy_vm_area(areas[i]);
        areas[i] = 0;
    }

    sanity_check_map(&map);

    // Random positive tests. Create and delete a bunch of areas by searching.
    // These should all succeed. This will ensure the newly created areas
    // match the constraints and that the map is internally consistent.
    //
    for (i = 0; i < NUM_TEST_AREAS; i++)
        areas[i] = 0;

    for (i = 0; i < 100000; i++)
    {
        slot = rand() % NUM_TEST_AREAS;
        if (areas[slot] != 0)
        {
            expect_count--;
            destroy_vm_area(areas[slot]);
        }

        expect_count++;
        size = 0x1000 * (rand() % 7 + 1);
        place = rand() % 2 + 1;
        if (place == PLACE_SEARCH_DOWN)
            address = 0x10000000 * (rand() % 0xd + 2) - 1;
        else
            address = 0x10000000 * (rand() % 8);

        areas[slot] = create_vm_area(&map, address, size, place, "area", 0);
        assert(areas[slot] != 0);
        assert(areas[slot]->high_address - areas[slot]->low_address + 1 == size);
        if (place == PLACE_SEARCH_DOWN)
        {
            assert(areas[slot]->high_address <= address);
        }
        else
        {
            assert(areas[slot]->low_address >= address);
        }

        assert(areas[slot]->low_address >= TEST_MAP_LOW);
        assert(areas[slot]->high_address <= TEST_MAP_HIGH);

        assert(count_areas(&map) == expect_count);
        sanity_check_map(&map);

        // Periodically completely empty map
        if ((i % 10000) == 9999)
        {
            for (slot = 0; slot < NUM_TEST_AREAS; slot++)
            {
                if (areas[slot] != 0)
                {
                    destroy_vm_area(areas[slot]);
                    areas[slot] = 0;
                }
            }
            expect_count = 0;
        }
    }

    // Test if the starting search address is outside map limits, which will
    // make it impossible to find an area.
    assert(create_vm_area(&map, TEST_MAP_LOW, 0x1000, PLACE_SEARCH_DOWN, "", 0)
           == 0);
    assert(create_vm_area(&map, TEST_MAP_HIGH, 0x1000, PLACE_SEARCH_UP, "", 0)
           == 0);

    // Try to create an area when there is already in area taking available
    // space
    areas[0] = create_vm_area(&map, 0xffffffff, 0x8000, PLACE_SEARCH_DOWN, "", 0);
    assert(create_vm_area(&map, areas[0]->low_address - 0x1000, 0x2000,
                          PLACE_SEARCH_UP, "", 0) == 0);
    destroy_vm_area(areas[0]);

    areas[0] = create_vm_area(&map, 0, 0x8000, PLACE_SEARCH_UP, "", 0);
    assert(create_vm_area(&map, areas[0]->high_address + 0x1000, 0x2000,
                          PLACE_SEARCH_DOWN, "", 0) == 0);
    destroy_vm_area(areas[0]);

    // Create a few fixed areas for next tests
    areas[0] = create_vm_area(&map, 0x30000000, 0x2000, PLACE_EXACT, "", 0);
    assert(areas[0] != 0);
    assert(areas[0]->low_address == 0x30000000);
    assert(areas[0]->high_address == 0x30001fff);

    areas[1] = create_vm_area(&map, 0x30003000, 0x2000, PLACE_EXACT, "", 0);
    assert(areas[1] != 0);
    assert(areas[1]->low_address == 0x30003000);
    assert(areas[1]->high_address == 0x30004fff);
    sanity_check_map(&map);

    // Try to create fixed areas that collide with existing ones. Ensure
    // this fails (hit all overlap cases)
    assert(create_vm_area(&map, 0x30000000 - 0x1000, 0x2000, PLACE_EXACT, "", 0) == 0);
    assert(create_vm_area(&map, 0x30001000, 0x2000, PLACE_EXACT, "", 0) == 0);
    assert(create_vm_area(&map, 0x30002000, 0x2000, PLACE_EXACT, "", 0) == 0);
    assert(create_vm_area(&map, 0x30004000, 0x2000, PLACE_EXACT, "", 0) == 0);
    sanity_check_map(&map);

    // now create an area in the middle of the two that exactly fits.
    // Ensure this is successful.
    areas[2] = create_vm_area(&map, 0x30002000, 0x1000, PLACE_EXACT, "", 0);
    assert(areas[2] != 0);
    assert(areas[2]->low_address == 0x30002000);
    assert(areas[2]->high_address == 0x30002fff);
    sanity_check_map(&map);

    for (i = 0; i < 3; i++)
    {
        destroy_vm_area(areas[i]);
        areas[i] = 0;
    }

    //
    // Area lookup tests
    //
    assert(lookup_area(&map, 0xfff) == 0);  // Empty map

    areas[1] = create_vm_area(&map, 0x30003000, 0x2000, PLACE_EXACT, "", 0);
    sanity_check_map(&map);
    areas[0] = create_vm_area(&map, 0x30001000, 0x2000, PLACE_EXACT, "", 0);
    sanity_check_map(&map);
    areas[2] = create_vm_area(&map, 0x30006000, 0x1000, PLACE_EXACT, "", 0);
    sanity_check_map(&map);
    areas[3] = create_vm_area(&map, 0x30009000, 0x5000, PLACE_EXACT, "", 0);
    sanity_check_map(&map);

    assert(lookup_area(&map, 0x30000fff) == 0);
    assert(lookup_area(&map, 0x30001000) == areas[0]);
    assert(lookup_area(&map, 0x30002fff) == areas[0]);
    assert(lookup_area(&map, 0x30003000) == areas[1]);
    assert(lookup_area(&map, 0x30004fff) == areas[1]);
    assert(lookup_area(&map, 0x30005000) == 0);
    assert(lookup_area(&map, 0x30005fff) == 0);
    assert(lookup_area(&map, 0x30006000) == areas[2]);
    assert(lookup_area(&map, 0x30006fff) == areas[2]);
    assert(lookup_area(&map, 0x30007000) == 0);
    assert(lookup_area(&map, 0x30008fff) == 0);
    assert(lookup_area(&map, 0x30009000) == areas[3]);
    assert(lookup_area(&map, 0x3000deee) == areas[3]);
    assert(lookup_area(&map, 0x3000e000) == 0);
    assert(lookup_area(&map, 0xffffffff) == 0);

    for (i = 0; i < 4; i++)
    {
        destroy_vm_area(areas[i]);
        areas[i] = 0;
    }

    // Ensure we detect (and fail) a wrapping region
    init_area_map(&map, 0xc0000000, 0xffffffff);
    assert(create_vm_area(&map, 0xc0000000, 0xd0000000, PLACE_EXACT, "kernel", 0) == 0);

    // Check for overflow in the memory area
    create_vm_area(&map, 0xc0000000, 0x10000000, PLACE_EXACT, "kernel", 0);
    create_vm_area(&map, 0xffff0000, 0x10000, PLACE_EXACT, "device registers", 0);
    dump_area_map(&map);
    sanity_check_map(&map);

    kprintf("all tests passed\n");
}

#endif
