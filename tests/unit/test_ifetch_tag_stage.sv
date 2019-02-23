//
// Copyright 2017 Jeff Bush
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

`include "defines.svh"

import defines::*;

// Not covered:
// - Multiple threads
// - Invalidate cache entry
module test_ifetch_tag_stage(input clk, input reset);
    logic ifd_update_lru_en;
    l1i_way_idx_t ifd_update_lru_way;
    logic ifd_cache_miss;
    logic ifd_near_miss;
    local_thread_idx_t ifd_cache_miss_thread_idx;
    logic ift_instruction_requested;
    l1i_addr_t ift_pc_paddr;
    scalar_t ift_pc_vaddr;
    local_thread_idx_t ift_thread_idx;
    logic ift_tlb_hit;
    logic ift_tlb_present;
    logic ift_tlb_executable;
    logic ift_tlb_supervisor;
    l1i_tag_t ift_tag[`L1I_WAYS];
    logic ift_valid[`L1I_WAYS];
    logic l2i_icache_lru_fill_en;
    l1i_set_idx_t l2i_icache_lru_fill_set;
    logic[`L1I_WAYS - 1:0] l2i_itag_update_en;
    l1i_set_idx_t l2i_itag_update_set;
    l1i_tag_t l2i_itag_update_tag;
    logic l2i_itag_update_valid;
    local_thread_bitmap_t l2i_icache_wake_bitmap;
    l1i_way_idx_t ift_fill_lru;
    logic cr_mmu_en[`THREADS_PER_CORE];
    logic[ASID_WIDTH - 1:0] cr_current_asid[`THREADS_PER_CORE];
    logic dt_invalidate_tlb_en;
    logic dt_invalidate_tlb_all_en;
    logic[ASID_WIDTH - 1:0] dt_update_itlb_asid;
    page_index_t dt_update_itlb_vpage_idx;
    logic dt_update_itlb_en;
    logic dt_update_itlb_supervisor;
    logic dt_update_itlb_global;
    logic dt_update_itlb_present;
    logic dt_update_itlb_executable;
    page_index_t dt_update_itlb_ppage_idx;
    logic wb_rollback_en;
    local_thread_idx_t wb_rollback_thread_idx;
    scalar_t wb_rollback_pc;
    local_thread_bitmap_t ts_fetch_en;
    logic ocd_halt;
    local_thread_idx_t ocd_thread;
    int cycle;

    ifetch_tag_stage ifetch_tag_stage(.*);

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            cycle <= 0;
            ifd_update_lru_way <= '0;
            ifd_cache_miss_thread_idx <= '0;
            l2i_icache_lru_fill_set <= '0;
            l2i_itag_update_set <= '0;
            l2i_itag_update_tag <= '0;
            l2i_itag_update_valid <= '0;
            l2i_icache_wake_bitmap <= '0;
            for (int i = 0; i < `THREADS_PER_CORE; i++)
                cr_mmu_en[i] <= '0;

            for (int i = 0; i < `THREADS_PER_CORE; i++)
                cr_current_asid[i] <= '0;

            dt_update_itlb_asid <= '0;
            dt_update_itlb_vpage_idx <= '0;
            dt_update_itlb_supervisor <= '0;
            dt_update_itlb_global <= '0;
            dt_update_itlb_present <= '0;
            dt_update_itlb_executable <= '0;
            dt_update_itlb_ppage_idx <= '0;
            wb_rollback_thread_idx <= '0;
            wb_rollback_pc <= '0;
            ocd_thread <= '0;
            ocd_halt <= '0;
        end
        else
        begin
            ifd_update_lru_en <= '0;
            l2i_icache_lru_fill_en <= '0;
            l2i_itag_update_en <= '0;
            dt_invalidate_tlb_en <= '0;
            dt_invalidate_tlb_all_en <= '0;
            dt_update_itlb_en <= '0;
            wb_rollback_en <= '0;
            ifd_cache_miss <= '0;
            ifd_near_miss <= '0;

            cycle <= cycle + 1;
            unique0 case (cycle)
                0: ts_fetch_en <= 4'b0001;


                ////////////////////////////////////////////////////////////
                // Simulate icache miss
                ////////////////////////////////////////////////////////////
                1:
                begin
                    ifd_cache_miss <= 1;
                end

                2:
                begin
                    assert(ift_pc_vaddr == 0);
                    assert(ift_pc_paddr == 0);
                    assert(ift_instruction_requested);
                    assert(ift_thread_idx == 0);
                    assert(ift_tlb_hit);

                    // The MMU is disabled, so these will have sane
                    // default values.
                    assert(ift_tlb_hit);
                    assert(ift_tlb_present);
                    assert(ift_tlb_executable);
                    assert(!ift_valid[0]);
                    assert(!ift_valid[1]);
                    assert(!ift_valid[2]);
                    assert(!ift_valid[3]);
                end

                // Ensure the thread is suspended and doesn't request
                // for a few cycles.
                3:  assert(!ift_instruction_requested);
                4:  assert(!ift_instruction_requested);
                5:  assert(!ift_instruction_requested);

                // Fill cache line
                6:
                begin
                    assert(!ift_instruction_requested);
                    l2i_itag_update_en <= 1;
                    l2i_itag_update_set <= 0;
                    l2i_itag_update_tag <= 0;
                    l2i_itag_update_valid <= 1;
                    l2i_icache_wake_bitmap <= 4'b0001;
                end

                7:  assert(!ift_instruction_requested);
                8:  assert(!ift_instruction_requested);

                9:
                begin
                    assert(ift_pc_vaddr == 0);
                    assert(ift_pc_paddr == 0);
                    assert(ift_instruction_requested);
                    assert(ift_thread_idx == 0);
                    assert(ift_tlb_hit);

                    // The MMU is disabled, so these will have sane
                    // default values.
                    assert(ift_tlb_hit);
                    assert(ift_tlb_present);
                    assert(ift_tlb_executable);
                    assert(ift_valid[0]);
                    assert(!ift_valid[1]);
                    assert(!ift_valid[2]);
                    assert(!ift_valid[3]);
                end

                ////////////////////////////////////////////////////////////
                // icache near miss (doesn't block thread)
                ////////////////////////////////////////////////////////////
                10:
                begin
                    assert(ift_pc_vaddr == 4);
                    assert(ift_pc_paddr == 4);
                    assert(ift_instruction_requested);
                    assert(ift_thread_idx == 0);
                    assert(ift_tlb_hit);
                    ifd_near_miss <= 1;
                end

                11:
                begin
                    assert(ift_pc_vaddr == 8);
                    assert(ift_pc_paddr == 8);
                    assert(ift_instruction_requested);
                    assert(ift_thread_idx == 0);
                    assert(ift_tlb_hit);
                end

                12: assert(!ift_instruction_requested);

                13:
                begin
                    // Back to the cycle near miss was asserted
                    assert(ift_pc_vaddr == 8);
                    assert(ift_pc_paddr == 8);
                    assert(ift_instruction_requested);
                    assert(ift_thread_idx == 0);
                    assert(ift_tlb_hit);
                end

                // next instruction
                14:
                begin
                    assert(ift_pc_vaddr == 12);
                    assert(ift_pc_paddr == 12);
                    assert(ift_instruction_requested);
                    assert(ift_thread_idx == 0);
                    assert(ift_tlb_hit);

                    // Enable address translation
                    cr_mmu_en[0] <= 1;
                end

                ////////////////////////////////////////////////////////////
                // TLB miss/fill
                ////////////////////////////////////////////////////////////
                20:
                begin
                    assert(ift_instruction_requested);
                    assert(ift_thread_idx == 0);
                    assert(!ift_tlb_hit);

                    // Simulate rolling back to TLB handler
                    // (this normally would take several cycles, but I'm
                    // simplifying here).
                    wb_rollback_en <= 1;
                    wb_rollback_thread_idx <= 0;
                    wb_rollback_pc <= 'h4000;
                    cr_mmu_en[0] <= 0;
                end

                21: assert(ift_instruction_requested);
                22: assert(!ift_instruction_requested);

                23:
                begin
                    assert(ift_instruction_requested);
                    assert(ift_pc_vaddr == 'h4000);
                    assert(ift_pc_paddr == 'h4000);
                    assert(ift_thread_idx == 0);
                    assert(ift_tlb_hit);    // because MMU is off now

                    // Insert entry into ITLB.
                    dt_update_itlb_en <= 1;
                    dt_update_itlb_present <= 1;
                    dt_update_itlb_executable <= 1;
                    dt_update_itlb_ppage_idx <= 8;
                    dt_update_itlb_vpage_idx <= 0;
                end

                24:
                begin
                    // One more instruction fetched
                    assert(ift_instruction_requested);
                    assert(ift_pc_vaddr == 'h4004);
                    assert(ift_pc_paddr == 'h4004);
                    assert(ift_thread_idx == 0);
                    assert(ift_tlb_hit);
                end

                // When inserting into the TLB, it does not fetch
                // an instruction (because both need to read the TLB).
                // The logic doesn't check whether the MMU is enabled.
                25: assert(!ift_instruction_requested);

                26:
                begin
                    assert(ift_instruction_requested);
                    assert(ift_pc_vaddr == 'h4008);
                    assert(ift_pc_paddr == 'h4008);
                    assert(ift_thread_idx == 0);
                    assert(ift_tlb_hit);

                    // Re-enable MMU and jump back to old code path
                    wb_rollback_en <= 1;
                    wb_rollback_thread_idx <= 0;
                    wb_rollback_pc <= 12;
                    cr_mmu_en[0] <= 1;
                end

                27: assert(ift_instruction_requested); // this would be squashed
                28: assert(!ift_instruction_requested); // dead rollback cycle

                29:
                begin
                    // Ensure we now get a translated address
                    assert(ift_instruction_requested);
                    assert(ift_tlb_hit);
                    assert(ift_pc_vaddr == 'hc);
                    assert(ift_pc_paddr == 'h800c);
                    assert(ift_thread_idx == 0);
                end

                ////////////////////////////////////////////////////////////
                // Invalidate TLB entry. Ensure it is cleared and there
                // is no instruction fetch. (regression test for issue #137:
                // "Kernel no longer runs user space programs")
                ////////////////////////////////////////////////////////////
                40:
                begin
                    // First insert a new entry at a different address than
                    // we are fetching from.
                    dt_update_itlb_en <= 1;
                    dt_update_itlb_present <= 1;
                    dt_update_itlb_executable <= 1;
                    dt_update_itlb_ppage_idx <= 'hc;
                    dt_update_itlb_vpage_idx <= 'hd;
                end

                // Skip two cycles

                // Invalidate this address (PC is still fetching from a
                // different address)
                42:
                begin
                    dt_invalidate_tlb_en <= 1;
                    dt_update_itlb_vpage_idx <= 'hd;
                end

                // Skip two cycles

                // Jump to address we inserted
                44:
                begin
                    wb_rollback_en <= 1;
                    wb_rollback_thread_idx <= 0;
                    wb_rollback_pc <= 'hd000;
                end

                // Wait two cycles after signal is asserted (three total)

                47:
                begin
                    assert(ift_instruction_requested);

                    // Ensure this is no longer translated
                    assert(!ift_tlb_hit);
                    assert(ift_thread_idx == 0);
                    assert(ift_pc_vaddr == 'hd000);
                end

                ////////////////////////////////////////////////////////////
                // Deassert ts_fetch_en for a thread (FIFO full)
                ////////////////////////////////////////////////////////////
                50:
                begin
                    // Roll back to a known address
                    wb_rollback_en <= 1;
                    wb_rollback_thread_idx <= 0;
                    wb_rollback_pc <= 'ha000;
                end

                // Wait three cycles for the rollback to take effect

                53:
                begin
                    assert(ift_pc_vaddr == 'ha000);
                    assert(ift_instruction_requested);
                    ts_fetch_en <= 0;
                end

                54:
                begin
                    assert(ift_instruction_requested);
                    assert(ift_pc_vaddr == 'ha004);
                end

                // wait several cycles to ensure nothing is requested
                55: assert(!ift_instruction_requested);
                56: assert(!ift_instruction_requested);
                57:
                begin
                    assert(!ift_instruction_requested);
                    ts_fetch_en <= 4'b0001;
                end

                58: assert(!ift_instruction_requested);
                59:
                begin
                    // Ensure we resume fetching at the *very next* address
                    assert(ift_instruction_requested);
                    assert(ift_pc_vaddr == 'ha008);
                end

                ////////////////////////////////////////////////////////////
                // Assert OCD halt, ensure no threads are fetched
                ////////////////////////////////////////////////////////////
                60: ocd_halt <= 1;

                // Takes one cycle to take effect
                61: assert(ift_instruction_requested);

                // Ensure it stops issuing new instructions
                62: assert(!ift_instruction_requested);
                63: assert(!ift_instruction_requested);
                64: assert(!ift_instruction_requested);

                65:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
