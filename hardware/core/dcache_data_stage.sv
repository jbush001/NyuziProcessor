//
// Copyright 2011-2015 Jeff Bush
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

`include "defines.sv"

import defines::*;

//
// Instruction pipeline L1 data cache data stage.
// - Detects cache miss or hit based on tag information fetched from last
//   stage.
// - Reads from cache data storage.
// - Drives signals to previous stage to update LRU
//

module dcache_data_stage(
    input                                     clk,
    input                                     reset,

    // To instruction_decode_stage
    output local_thread_bitmap_t              dd_sync_load_pending,

    // From dcache_tag_stage
    input                                     dt_instruction_valid,
    input decoded_instruction_t               dt_instruction,
    input vector_lane_mask_t                  dt_mask_value,
    input local_thread_idx_t                  dt_thread_idx,
    input l1d_addr_t                          dt_request_vaddr,
    input l1d_addr_t                          dt_request_paddr,
    input                                     dt_tlb_hit,
    input                                     dt_tlb_present,
    input                                     dt_tlb_supervisor,
    input                                     dt_tlb_writable,
    input vector_t                            dt_store_value,
    input subcycle_t                          dt_subcycle,
    input                                     dt_valid[`L1D_WAYS],
    input l1d_tag_t                           dt_tag[`L1D_WAYS],

    // To dcache_tag_stage
    output logic                              dd_update_lru_en,
    output l1d_way_idx_t                      dd_update_lru_way,

    // To io_request_queue
    output logic                              dd_io_write_en,
    output logic                              dd_io_read_en,
    output local_thread_idx_t                 dd_io_thread_idx,
    output scalar_t                           dd_io_addr,
    output scalar_t                           dd_io_write_value,

    // To writeback_stage
    output logic                              dd_instruction_valid,
    output decoded_instruction_t              dd_instruction,
    output vector_lane_mask_t                 dd_lane_mask,
    output local_thread_idx_t                 dd_thread_idx,
    output l1d_addr_t                         dd_request_vaddr,
    output subcycle_t                         dd_subcycle,
    output logic                              dd_rollback_en,
    output scalar_t                           dd_rollback_pc,
    output cache_line_data_t                  dd_load_data,
    output logic                              dd_suspend_thread,
    output logic                              dd_is_io_address,
    output logic                              dd_fault,
    output trap_cause_t                       dd_fault_cause,

    // From control registers
    input logic                               cr_supervisor_en[`THREADS_PER_CORE],

    // To control_registers
    // These signals are unregistered
    output logic                              dd_creg_write_en,
    output logic                              dd_creg_read_en,
    output control_register_t                 dd_creg_index,
    output scalar_t                           dd_creg_write_val,

    // From l1_l2_interface
    input                                     l2i_ddata_update_en,
    input l1d_way_idx_t                       l2i_ddata_update_way,
    input l1d_set_idx_t                       l2i_ddata_update_set,
    input cache_line_data_t                   l2i_ddata_update_data,
    input [`L1D_WAYS - 1:0]                   l2i_dtag_update_en_oh,
    input l1d_set_idx_t                       l2i_dtag_update_set,
    input l1d_tag_t                           l2i_dtag_update_tag,

     // To l1_l2_interface
    output logic                              dd_cache_miss,
    output cache_line_index_t                 dd_cache_miss_addr,
    output local_thread_idx_t                 dd_cache_miss_thread_idx,
    output logic                              dd_cache_miss_sync,
    output logic                              dd_store_en,
    output logic                              dd_flush_en,
    output logic                              dd_membar_en,
    output logic                              dd_iinvalidate_en,
    output logic                              dd_dinvalidate_en,
    output logic[CACHE_LINE_BYTES - 1:0]      dd_store_mask,
    output cache_line_index_t                 dd_store_addr,
    output cache_line_data_t                  dd_store_data,
    output local_thread_idx_t                 dd_store_thread_idx,
    output logic                              dd_store_sync,
    output cache_line_index_t                 dd_store_bypass_addr,
    output local_thread_idx_t                 dd_store_bypass_thread_idx,

    // From writeback_stage
    input logic                               wb_rollback_en,
    input local_thread_idx_t                  wb_rollback_thread_idx,
    input pipeline_sel_t                      wb_rollback_pipeline,

    // To performance_counters
    output logic                              dd_perf_dcache_hit,
    output logic                              dd_perf_dcache_miss,
    output logic                              dd_perf_store,
    output logic                              dd_perf_dtlb_miss);

    logic dcache_access_en;
    logic creg_access_en;
    vector_lane_mask_t word_store_mask;
    logic[3:0] byte_store_mask;
    logic[$clog2(CACHE_LINE_WORDS) - 1:0] cache_lane_idx;
    cache_line_data_t endian_twiddled_data;
    scalar_t lane_store_value;
    logic is_io_address;
    logic[CACHE_LINE_WORDS - 1:0] cache_lane_mask;
    logic[CACHE_LINE_WORDS - 1:0] subcycle_mask;
    logic[`L1D_WAYS - 1:0] way_hit_oh;
    l1d_way_idx_t way_hit_idx;
    logic cache_hit;
    logic dcache_load_en;
    scalar_t dcache_request_addr;
    logic rollback_this_stage;
    logic cache_near_miss;
    logic dcache_store_en;
    logic io_access_en;
    logic is_unaligned;
    logic is_sync;
    logic cache_control_en;
    logic[$clog2(NUM_VECTOR_LANES) - 1:0] scgath_lane;
    logic is_tlb_access;
    logic is_tlb_update;
    logic supervisor_fault;
    logic alignment_fault;
    logic creg_is_privileged;
    logic privilege_op_fault;
    logic write_fault;
    logic tlb_miss;
    logic page_fault;
    logic is_store_fault;

    // Unlike earlier stages, this commits instruction side effects like stores,
    // so it needs to check if there is a rollback (which would be for the
    // instruction issued immediately before this one) and avoid updates if so.
    // rollback_this_stage indicates a rollback is requested from the previous
    // instruction, but it does not get set when this stage requests a rollback.
    assign rollback_this_stage = wb_rollback_en
        && wb_rollback_thread_idx == dt_thread_idx
        && wb_rollback_pipeline == PIPE_MEM;
    assign is_io_address = dt_request_paddr ==? 32'hffff????;
    assign is_sync = dt_instruction.memory_access_type == MEM_SYNC;

    // Determine if this instruction accesses the TLB (and thus will raise a TLB
    // miss if the entry is not present)
    always_comb
    begin
        is_tlb_access = 0;
        if (dt_instruction_valid && !rollback_this_stage)
        begin
            if (dt_instruction.is_memory_access)
                is_tlb_access = dt_instruction.memory_access_type != MEM_CONTROL_REG;
            else if (dt_instruction.is_cache_control)
            begin
                // Only these cache control opertions perform a virtual->physical
                // address translation.
                is_tlb_access = dt_instruction.cache_control_op == CACHE_DFLUSH
                    || dt_instruction.cache_control_op == CACHE_DINVALIDATE;
            end
        end
    end

    // L1 data cache or store buffer access
    assign dcache_access_en = dt_instruction_valid
        && !rollback_this_stage
        && dt_instruction.is_memory_access
        && dt_instruction.memory_access_type != MEM_CONTROL_REG
        && dt_tlb_hit
        && !is_io_address;
    assign dcache_load_en = dcache_access_en && dt_instruction.is_load;
    assign dcache_store_en = dcache_access_en && !dt_instruction.is_load
        && dd_store_mask != 0;
    assign dcache_request_addr = {dt_request_paddr[31:CACHE_LINE_OFFSET_WIDTH],
        {CACHE_LINE_OFFSET_WIDTH{1'b0}}};
    assign cache_lane_idx = dt_request_paddr.offset[CACHE_LINE_OFFSET_WIDTH - 1:2];
    assign dd_store_bypass_addr = dt_request_paddr[31:CACHE_LINE_OFFSET_WIDTH];
    assign dd_store_bypass_thread_idx = dt_thread_idx;
    assign dd_store_addr = dt_request_paddr[31:CACHE_LINE_OFFSET_WIDTH];
    assign dd_store_sync = is_sync;
    assign dd_store_en = dcache_store_en
        && !is_unaligned
        && dt_tlb_writable
        && dt_tlb_present
        && !supervisor_fault;
    assign dd_store_thread_idx = dt_thread_idx;

    // Noncached I/O memory access
    assign io_access_en = dt_instruction_valid
        && !rollback_this_stage
        && dt_instruction.is_memory_access
        && dt_instruction.memory_access_type != MEM_CONTROL_REG
        && dt_tlb_hit
        && dt_tlb_present
        && !supervisor_fault
        && is_io_address;
    assign dd_io_write_en = io_access_en
        && !dt_instruction.is_load
        && dt_tlb_writable;
    assign dd_io_read_en = io_access_en
        && dt_instruction.is_load;
    assign dd_io_write_value = dt_store_value[0];
    assign dd_io_thread_idx = dt_thread_idx;
    assign dd_io_addr = {16'd0, dt_request_paddr[15:0]};

    // Cache control
    assign cache_control_en = dt_instruction_valid
        && !rollback_this_stage
        && dt_instruction.is_cache_control;
    assign dd_flush_en = cache_control_en
        && dt_instruction.cache_control_op == CACHE_DFLUSH
        && !supervisor_fault
        && dt_tlb_present
        && !is_io_address; // XXX should a cache control of IO address raise exception?
    assign dd_iinvalidate_en = cache_control_en
        && dt_instruction.cache_control_op == CACHE_IINVALIDATE
        && !is_io_address;
    assign dd_dinvalidate_en = cache_control_en
        && dt_instruction.cache_control_op == CACHE_DINVALIDATE
        && dt_tlb_hit
        && dt_tlb_present
        && !is_io_address
        && cr_supervisor_en[dt_thread_idx];
    assign dd_membar_en = cache_control_en
        && dt_instruction.cache_control_op == CACHE_MEMBAR;
    assign is_tlb_update = cache_control_en
        && (dt_instruction.cache_control_op == CACHE_DTLB_INSERT
            || dt_instruction.cache_control_op == CACHE_ITLB_INSERT
            || dt_instruction.cache_control_op == CACHE_TLB_INVAL
            || dt_instruction.cache_control_op == CACHE_TLB_INVAL_ALL);

    // Control register access
    assign creg_access_en = dt_instruction_valid
        && !rollback_this_stage
        && dt_instruction.is_memory_access
        && dt_instruction.memory_access_type == MEM_CONTROL_REG;
    assign dd_creg_write_en = creg_access_en && !dt_instruction.is_load
        && cr_supervisor_en[dt_thread_idx];
    assign dd_creg_read_en = creg_access_en && dt_instruction.is_load;
    assign dd_creg_write_val = dt_store_value[0];
    assign dd_creg_index = dt_instruction.creg_index;

    // Performance events
    assign dd_perf_dcache_hit = cache_hit && dcache_load_en;
    assign dd_perf_dcache_miss = !cache_hit && dcache_load_en;
    assign dd_perf_store = dcache_store_en;
    assign dd_perf_dtlb_miss = is_tlb_access && !dt_tlb_hit;

    //
    // Check for cache hit
    //
    genvar way_idx;
    generate
        for (way_idx = 0; way_idx < `L1D_WAYS; way_idx++)
        begin : hit_check_gen
            assign way_hit_oh[way_idx] = dt_request_paddr.tag == dt_tag[way_idx]
                && dt_valid[way_idx];
        end
    endgenerate

    // Treat a synchronized load as a cache miss the first time it occurs, because
    // it needs to send it to the L2 cache to register it.
    assign cache_hit = |way_hit_oh && (!is_sync || dd_sync_load_pending[dt_thread_idx])
        && dt_tlb_hit;

    //
    // Store alignment
    //
    idx_to_oh #(
        .NUM_SIGNALS(CACHE_LINE_WORDS),
        .DIRECTION("LSB0")
    ) idx_to_oh_subcycle(
        .one_hot(subcycle_mask),
        .index(dt_subcycle));

    idx_to_oh #(
        .NUM_SIGNALS(CACHE_LINE_WORDS),
        .DIRECTION("LSB0")
    ) idx_to_oh_cache_lane(
        .one_hot(cache_lane_mask),
        .index(cache_lane_idx));

    always_comb
    begin
        word_store_mask = 0;
        case (dt_instruction.memory_access_type)
            MEM_BLOCK, MEM_BLOCK_M:    // Block vector access
                word_store_mask = dt_mask_value;

            MEM_SCGATH, MEM_SCGATH_M:    // Scatter/Gather access
            begin
                if ((dt_mask_value & subcycle_mask) != 0)
                    word_store_mask = cache_lane_mask;
                else
                    word_store_mask = 0;
            end

            default:    // Scalar access
                word_store_mask = cache_lane_mask;
        endcase
    end

    // Endian swap vector data
    genvar swap_word;
    generate
        for (swap_word = 0; swap_word < CACHE_LINE_BYTES / 4; swap_word++)
        begin : swap_word_gen
            assign endian_twiddled_data[swap_word * 32+:8] = dt_store_value[swap_word][24+:8];
            assign endian_twiddled_data[swap_word * 32 + 8+:8] = dt_store_value[swap_word][16+:8];
            assign endian_twiddled_data[swap_word * 32 + 16+:8] = dt_store_value[swap_word][8+:8];
            assign endian_twiddled_data[swap_word * 32 + 24+:8] = dt_store_value[swap_word][0+:8];
        end
    endgenerate

    assign scgath_lane = ~dt_subcycle;
    assign lane_store_value = dt_store_value[scgath_lane];

    // byte_store_mask and dd_store_data.
    always_comb
    begin
        case (dt_instruction.memory_access_type)
            MEM_B, MEM_BX: // Byte
            begin
                dd_store_data = {CACHE_LINE_WORDS * 4{dt_store_value[0][7:0]}};
                case (dt_request_paddr.offset[1:0])
                    2'd0: byte_store_mask = 4'b1000;
                    2'd1: byte_store_mask = 4'b0100;
                    2'd2: byte_store_mask = 4'b0010;
                    2'd3: byte_store_mask = 4'b0001;
                    default: byte_store_mask = 4'b0000;
                endcase
            end

            MEM_S, MEM_SX: // 16 bits
            begin
                dd_store_data = {CACHE_LINE_WORDS * 2{dt_store_value[0][7:0], dt_store_value[0][15:8]}};
                if (dt_request_paddr.offset[1] == 1'b0)
                    byte_store_mask = 4'b1100;
                else
                    byte_store_mask = 4'b0011;
            end

            MEM_L, MEM_SYNC: // 32 bits
            begin
                byte_store_mask = 4'b1111;
                dd_store_data = {CACHE_LINE_WORDS{dt_store_value[0][7:0], dt_store_value[0][15:8],
                    dt_store_value[0][23:16], dt_store_value[0][31:24]}};
            end

            MEM_SCGATH, MEM_SCGATH_M:
            begin
                byte_store_mask = 4'b1111;
                dd_store_data = {CACHE_LINE_WORDS{lane_store_value[7:0], lane_store_value[15:8],
                    lane_store_value[23:16], lane_store_value[31:24]}};
            end

            default: // Vector
            begin
                byte_store_mask = 4'b1111;
                dd_store_data = endian_twiddled_data;
            end
        endcase
    end

    // Check for unaligned access
    always_comb
    begin
        case (dt_instruction.memory_access_type)
            MEM_S, MEM_SX: is_unaligned = dt_request_paddr.offset[0];
            MEM_L, MEM_SYNC, MEM_SCGATH, MEM_SCGATH_M: is_unaligned = |dt_request_paddr.offset[1:0];
            MEM_BLOCK, MEM_BLOCK_M: is_unaligned = dt_request_paddr.offset != 0;
            default: is_unaligned = 0;
        endcase
    end

    // Generate store mask signals. word_store_mask corresponds to lanes,
    // byte_store_mask corresponds to bytes within a word. byte_store_mask
    // always has all bits set if word_store_mask has more than one bit set:
    // either select some number of words within the cache line for
    // a vector transfer or some bytes within a word for a scalar transfer.
    genvar mask_idx;
    generate
        for (mask_idx = 0; mask_idx < CACHE_LINE_BYTES; mask_idx++)
        begin : store_mask_gen
            assign dd_store_mask[mask_idx] = word_store_mask[
                (CACHE_LINE_BYTES - mask_idx - 1) / 4]
                & byte_store_mask[mask_idx & 3];
        end
    endgenerate

    oh_to_idx #(.NUM_SIGNALS(`L1D_WAYS)) encode_hit_way(
        .one_hot(way_hit_oh),
        .index(way_hit_idx));

    sram_1r1w #(
        .DATA_WIDTH(CACHE_LINE_BITS),
        .SIZE(`L1D_WAYS * `L1D_SETS),
        .READ_DURING_WRITE("NEW_DATA")
    ) l1d_data(
        // Instruction pipeline access.
        .read_en(cache_hit && dcache_load_en),
        .read_addr({way_hit_idx, dt_request_paddr.set_idx}),
        .read_data(dd_load_data),

        // Update from L2 cache interface
        .write_en(l2i_ddata_update_en),
        .write_addr({l2i_ddata_update_way, l2i_ddata_update_set}),
        .write_data(l2i_ddata_update_data),
        .*);

    // cache_near_miss indicates a cache miss is occurring in the cycle this is
    // filling the same line. If this suspends the thread, it will never
    // receive a wakeup. Instead, roll the thread back and let it retry.
    // Do not be set for a synchronized load, even if the data is in the L1
    // cache: it must do a round trip to the L2 cache to latch the address.
    assign cache_near_miss = !cache_hit
        && dt_tlb_hit
        && dcache_load_en
        && |l2i_dtag_update_en_oh
        && l2i_dtag_update_set == dt_request_paddr.set_idx
        && l2i_dtag_update_tag == dt_request_paddr.tag
        && !is_sync;

    assign dd_cache_miss = dcache_load_en
        && !cache_hit
        && dt_tlb_hit
        && !cache_near_miss
        && !is_unaligned;
    assign dd_cache_miss_addr = dcache_request_addr[31:CACHE_LINE_OFFSET_WIDTH];
    assign dd_cache_miss_thread_idx = dt_thread_idx;
    assign dd_cache_miss_sync = is_sync;

    assign dd_update_lru_en = cache_hit && dcache_access_en && !is_unaligned;
    assign dd_update_lru_way = way_hit_idx;

    // Always treat the first synchronized load as a cache miss, even if data is
    // present. This is to register request with L2 cache. The second request will
    // not be a miss if the data is in the cache (there is a window where it could
    // be evicted before the thread can fetch it, in which case it will retry.
    // sync_load_pending tracks if this is the first or second request.
    //
    // Interrupts are different than rollbacks because they can occur in the middle
    // of a synchronized load/store. Detect these and cancel the operation.
    genvar thread_idx;
    generate
        for (thread_idx = 0; thread_idx < `THREADS_PER_CORE; thread_idx++)
        begin : sync_pending_gen
            always_ff @(posedge clk, posedge reset)
            begin
                if (reset)
                    dd_sync_load_pending[thread_idx] <= 0;
                else if (dcache_load_en && is_sync && dt_thread_idx == local_thread_idx_t'(thread_idx))
                begin
                    // Track if this is the first or restarted request.
                    dd_sync_load_pending[thread_idx] <= !dd_sync_load_pending[thread_idx];
                end
            end
        end
    endgenerate

    // Faults
    assign alignment_fault = (dcache_load_en || dcache_store_en) && is_unaligned;
    assign privilege_op_fault = !cr_supervisor_en[dt_thread_idx]
        && (creg_access_en
            || is_tlb_update
            || (cache_control_en && dt_instruction.cache_control_op == CACHE_DINVALIDATE));
    assign write_fault = !dt_tlb_writable
        && (dcache_store_en || (io_access_en && !dt_instruction.is_load))
        && !supervisor_fault
        && dt_tlb_present;
    assign tlb_miss = is_tlb_access && !dt_tlb_hit;
    assign supervisor_fault = dt_tlb_supervisor && !cr_supervisor_en[dt_thread_idx]
        && dt_tlb_present;
    assign page_fault = (dcache_load_en || dcache_store_en) && !dt_tlb_present;
    assign is_store_fault = dt_instruction.is_memory_access
        && !dt_instruction.is_load;

    always_ff @(posedge clk)
    begin
        dd_instruction <= dt_instruction;
        dd_lane_mask <= dt_mask_value;
        dd_thread_idx <= dt_thread_idx;
        dd_request_vaddr <= dt_request_vaddr;
        dd_subcycle <= dt_subcycle;
        dd_rollback_pc <= dt_instruction.pc;
        dd_is_io_address <= is_io_address;

        // Check for TLB miss first, since permission bits are not valid if
        // there is a TLB miss. The order of the remaining items should match
        // that in instruction_decode_stage for consistency.
        if (tlb_miss)
            dd_fault_cause <= {1'b1, is_store_fault, TT_TLB_MISS};
        else if (page_fault)
            dd_fault_cause <= {1'b1, is_store_fault, TT_PAGE_FAULT};
        else if (supervisor_fault)
            dd_fault_cause <= {1'b1, is_store_fault, TT_SUPERVISOR_ACCESS};
        else if (alignment_fault)
            dd_fault_cause <= {1'b1, is_store_fault, TT_UNALIGNED_ACCESS};
        else if (privilege_op_fault)
            dd_fault_cause <= {2'b00, TT_PRIVILEGED_OP};
        else // write fault
            dd_fault_cause <= {2'b11, TT_ILLEGAL_STORE};
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            dd_fault <= '0;
            dd_instruction_valid <= '0;
            dd_rollback_en <= '0;
            dd_suspend_thread <= '0;
            // End of automatics
        end
        else
        begin
            // Make sure data is not present in more than one way.
            assert(!dcache_load_en || $onehot0(way_hit_oh));

            // Make sure this decodes only one type of instruction
            assert($onehot0({dcache_load_en, dcache_store_en, dd_io_write_en, dd_io_read_en,
                dd_flush_en, dd_iinvalidate_en, dd_dinvalidate_en, dd_membar_en,
                dd_creg_write_en, dd_creg_read_en}));

            dd_instruction_valid <= dt_instruction_valid && !rollback_this_stage;

            // Rollback on cache miss
            dd_rollback_en <= dcache_load_en && !cache_hit && dt_tlb_hit;

            // Suspend the thread if there is a cache miss.
            // In the near miss case (described above), don't suspend thread.
            dd_suspend_thread <= dcache_load_en
                && dt_tlb_hit
                && !cache_hit
                && !cache_near_miss
                && !is_unaligned;

            // Fault handling
            dd_fault <= alignment_fault || supervisor_fault || privilege_op_fault
                || write_fault || tlb_miss || page_fault;
        end
    end
endmodule

