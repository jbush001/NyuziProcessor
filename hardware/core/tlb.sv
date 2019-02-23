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

`include "defines.svh"

import defines::*;

//
// Translation lookaside buffer.
// Caches virtual to physical address translations.
//

module tlb
    #(parameter NUM_ENTRIES = 64,
    parameter NUM_WAYS = 4)

    (input                    clk,
    input                     reset,

    // Command
    // (exe_writable means executable for icache, writable for dcache)
    input                     lookup_en,
    input                     update_en,
    input                     invalidate_en,
    input                     invalidate_all_en,
    input page_index_t        request_vpage_idx,
    input [ASID_WIDTH - 1:0]  request_asid,
    input page_index_t        update_ppage_idx,
    input                     update_present,
    input                     update_exe_writable,
    input                     update_supervisor,
    input                     update_global,

    // Response
    output page_index_t       lookup_ppage_idx,
    output logic              lookup_hit,
    output logic              lookup_present,
    output logic              lookup_exe_writable,
    output logic              lookup_supervisor);

    localparam NUM_SETS = NUM_ENTRIES / NUM_WAYS;
    localparam SET_INDEX_WIDTH = $clog2(NUM_SETS);
    localparam WAY_INDEX_WIDTH = $clog2(NUM_WAYS);

    logic[NUM_WAYS - 1:0] way_hit_oh;
    page_index_t way_ppage_idx[NUM_WAYS];
    logic way_present[NUM_WAYS];
    logic way_exe_writable[NUM_WAYS];
    logic way_supervisor[NUM_WAYS];
    page_index_t request_vpage_idx_latched;
    page_index_t update_ppage_idx_latched;
    logic[SET_INDEX_WIDTH - 1:0] request_set_idx;
    logic[SET_INDEX_WIDTH - 1:0] update_set_idx;
    logic update_en_latched;
    logic update_valid;
    logic invalidate_en_latched;
    logic tlb_read_en;
    logic[NUM_WAYS - 1:0] way_update_oh;
    logic[NUM_WAYS - 1:0] next_way_oh;
    logic update_present_latched;
    logic update_exe_writable_latched;
    logic update_supervisor_latched;
    logic update_global_latched;
    logic[ASID_WIDTH - 1:0] request_asid_latched;

    //
    // Stage 1: lookup
    //
    assign request_set_idx = request_vpage_idx[SET_INDEX_WIDTH - 1:0];
    assign update_set_idx = request_vpage_idx_latched[SET_INDEX_WIDTH - 1:0];
    assign tlb_read_en = lookup_en || update_en || invalidate_en;

    genvar way_idx;
    generate
        for (way_idx = 0; way_idx < NUM_WAYS; way_idx++)
        begin : way_gen
            page_index_t way_vpage_idx;
            logic way_valid;
            logic entry_valid[NUM_SETS];
            logic[ASID_WIDTH - 1:0] way_asid;
            logic way_global;

            sram_1r1w #(
                .SIZE(NUM_SETS),
                .DATA_WIDTH(PAGE_NUM_BITS * 2 + 4 + ASID_WIDTH),
                .READ_DURING_WRITE("NEW_DATA")
            ) tlb_paddr_sram(
                .read_en(tlb_read_en),
                .read_addr(request_set_idx),
                .read_data({way_vpage_idx,
                    way_asid,
                    way_ppage_idx[way_idx],
                    way_present[way_idx],
                    way_exe_writable[way_idx],
                    way_supervisor[way_idx],
                    way_global}),
                .write_en(way_update_oh[way_idx]),
                .write_addr(update_set_idx),
                .write_data({request_vpage_idx_latched,
                    request_asid_latched,
                    update_ppage_idx_latched,
                    update_present_latched,
                    update_exe_writable_latched,
                    update_supervisor_latched,
                    update_global_latched}),
                .*);

            always_ff @(posedge clk, posedge reset)
            begin
                if (reset)
                begin
                    for (int set_idx = 0; set_idx < NUM_SETS; set_idx++)
                        entry_valid[set_idx] <= 0;
                end
                else
                begin
                    if (invalidate_all_en)
                    begin
                        for (int set_idx = 0; set_idx < NUM_SETS; set_idx++)
                            entry_valid[set_idx] <= 0;
                    end
                    else if (way_update_oh[way_idx])
                        entry_valid[update_set_idx] <= update_valid;
                end
            end

            always_ff @(posedge clk)
            begin
                if (!tlb_read_en)
                    way_valid <= 0;
                else if (way_update_oh[way_idx] && update_set_idx == request_set_idx)
                    way_valid <= update_valid;  // Bypass
                else
                    way_valid <= entry_valid[request_set_idx];
            end

            assign way_hit_oh[way_idx] = way_valid
                && way_vpage_idx == request_vpage_idx_latched
                && (way_asid == request_asid_latched || way_global
                    || (update_en_latched && update_global_latched));
        end
    endgenerate

    always_ff @(posedge clk)
    begin
        update_ppage_idx_latched <= update_ppage_idx;
        update_present_latched <= update_present;
        update_exe_writable_latched <= update_exe_writable;
        update_supervisor_latched <= update_supervisor;
        update_global_latched <= update_global;
        request_asid_latched <= request_asid;
        request_vpage_idx_latched <= request_vpage_idx;
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            invalidate_en_latched <= '0;
            update_en_latched <= '0;
            // End of automatics
        end
        else
        begin
            assert($onehot0({lookup_en, update_en, invalidate_en, invalidate_all_en}));
            update_en_latched <= update_en;
            invalidate_en_latched <= invalidate_en;
        end
    end

    //
    // Stage 2: output/update
    //
    assign lookup_hit = |way_hit_oh;
    always_comb
    begin
        // Enabled mux. Use OR to avoid inferring priority encoder.
        lookup_ppage_idx = 0;
        lookup_present = 0;
        lookup_exe_writable = 0;
        lookup_supervisor = 0;
        for (int way = 0; way < NUM_WAYS; way++)
        begin
            if (way_hit_oh[way])
            begin
                lookup_ppage_idx |= way_ppage_idx[way];
                lookup_present |= way_present[way];
                lookup_exe_writable |= way_exe_writable[way];
                lookup_supervisor |= way_supervisor[way];
            end
        end
    end

    always_comb
    begin
        if (update_en_latched || invalidate_en_latched)
        begin
            if (lookup_hit)
                way_update_oh = way_hit_oh;
            else
                way_update_oh = next_way_oh;
        end
        else
            way_update_oh = '0;
    end

    // If there is an invalidate, clear the valid bit
    assign update_valid = update_en_latched;

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            next_way_oh <= NUM_WAYS'(1);
            /*AUTORESET*/
        end
        else
        begin
            // Make sure we don't have duplicate entries in a set
            assert($onehot0(way_hit_oh));
            if (update_en)
            begin
                // Rotate
                next_way_oh <= {next_way_oh[NUM_WAYS - 2:0], next_way_oh[NUM_WAYS - 1]};
            end
        end
    end
endmodule
