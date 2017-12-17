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

`include "defines.sv"

import defines::*;

module test_tlb(input clk, input reset);
    localparam VPAGE1 = 20'hfffff;
    localparam VPAGE2 = 20'h00000;
    localparam VPAGE3 = 20'h4557b;
    localparam VPAGE4 = 20'hc8d94;
    localparam VPAGE5 = 20'hef065;

    localparam PPAGE1 = 20'hf30f2;
    localparam PPAGE2 = 20'hd87a6;
    localparam PPAGE3 = 20'hd32eb;
    localparam PPAGE4 = 20'hcc2ba;
    localparam PPAGE5 = 20'h72682;
    localparam PPAGE6 = 20'h366ac;

    logic lookup_en;
    logic update_en;
    logic invalidate_en;
    logic invalidate_all_en;
    page_index_t request_vpage_idx;
    logic [ASID_WIDTH - 1:0] request_asid;
    page_index_t update_ppage_idx;
    logic update_present;
    logic update_exe_writable;
    logic update_supervisor;
    logic update_global;
    page_index_t lookup_ppage_idx;
    logic lookup_hit;
    logic lookup_present;
    logic lookup_exe_writable;
    logic lookup_supervisor;
    int cycle;

    tlb #(.NUM_ENTRIES(16)) tlb(.*);

    // The is using non-blocking assignments, so the response will not occur on the
    // next cycle, the request does. The response will occur 2 cycles later, so there
    // needs to be an extra clock between this call and reading the result.
    task lookup_page(input page_index_t vpageidx, input logic [ASID_WIDTH - 1:0] asid);
        lookup_en <= 1;
        invalidate_en <= 0;
        invalidate_all_en <= 0;
        update_en <= 0;
        request_vpage_idx <= vpageidx;
        request_asid <= asid;
    endtask

    task update_page(input page_index_t vpageidx, input page_index_t ppageidx,
        input logic [ASID_WIDTH - 1:0] asid, logic present, logic global, logic writable,
        logic supervisor);

        update_en <= 1;
        request_vpage_idx <= vpageidx;
        request_asid <= asid;
        update_ppage_idx <= ppageidx;
        update_present <= present;
        update_exe_writable <= writable;
        update_supervisor <= supervisor;
        update_global <= global;
    endtask

    always @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            cycle <= 0;
            lookup_en <= 0;
            update_en <= 0;
            invalidate_en <= 0;
            invalidate_all_en <= 0;
            request_vpage_idx <= 0;
            request_asid <= 0;
            update_ppage_idx <= 0;
            update_present <= 0;
            update_exe_writable <= 0;
            update_supervisor <= 0;
            update_global <= 0;
        end
        else
        begin
            // Default values. If nothing asserts the value, revert to 0.
            lookup_en <= 0;
            update_en <= 0;
            invalidate_en <= 0;
            invalidate_all_en <= 0;

            cycle <= cycle + 1;
            unique0 case (cycle)
                // Insert entries into table
                0: update_page(VPAGE1, PPAGE1, 0, 1, 0, 1, 1);
                1: update_page(VPAGE2, PPAGE2, 0, 0, 0, 0, 0);
                2: update_page(VPAGE3, PPAGE3, 0, 1, 0, 1, 0);

                // Insert page with different ASID, but same address as another
                // XXX assuming here this entry won't evict the previous one,
                // which is possible in some cases based on randomized
                // replacement algorithm
                3: update_page(VPAGE2, PPAGE4, 1, 1, 0, 1, 0);

                // Insert global page
                4: update_page(VPAGE4, PPAGE5, 0, 1, 1, 0, 1);

                // Look up existing entries
                5: lookup_page(VPAGE1, 0);
                6: lookup_en <= 0;  // wait a cycle for result
                7:
                begin
                    assert(lookup_hit);
                    assert(lookup_ppage_idx == PPAGE1);
                    assert(lookup_present);
                    assert(lookup_exe_writable);
                    assert(lookup_supervisor);

                    lookup_page(VPAGE2, 0);
                end

                // skip 8
                9:
                begin
                    assert(lookup_hit);
                    assert(lookup_ppage_idx == PPAGE2);
                    assert(!lookup_present);
                    assert(!lookup_exe_writable);
                    assert(!lookup_supervisor);

                    lookup_page(VPAGE3, 0);
                end

                // skip 10
                11:
                begin
                    assert(lookup_hit);
                    assert(lookup_ppage_idx == PPAGE3);
                    assert(lookup_present);
                    assert(lookup_exe_writable);
                    assert(!lookup_supervisor);

                    // Lookup page in other ASID
                    lookup_page(VPAGE2, 1);
                end

                // skip 12
                13:
                begin
                    assert(lookup_hit);
                    assert(lookup_ppage_idx == PPAGE4);
                    assert(lookup_present);
                    assert(lookup_exe_writable);
                    assert(!lookup_supervisor);

                    // this is the global page
                    lookup_page(VPAGE4, 0);
                end

                // skip 14
                15:
                begin
                    assert(lookup_hit);
                    assert(lookup_ppage_idx == PPAGE5);
                    assert(lookup_present);
                    assert(!lookup_exe_writable);
                    assert(lookup_supervisor);

                    // Lookup the global page in the other ASID
                    lookup_page(VPAGE4, 1);
                end

                // skip 16
                17:
                begin
                    assert(lookup_hit);
                    assert(lookup_ppage_idx == PPAGE5);
                    assert(lookup_present);
                    assert(!lookup_exe_writable);
                    assert(lookup_supervisor);

                    // negative tests, still in ASID 1, look up first three pages
                    // should not appear because they are in a different ASID.
                    lookup_page(VPAGE1, 1);
                end

                // skip 18
                19:
                begin
                    assert(!lookup_hit);
                    lookup_page(VPAGE3, 1);
                end

                // skip 20
                21:
                begin
                    assert(!lookup_hit);

                    // This page is non-existant
                    lookup_page(VPAGE5, 0);
                end

                // skip 22
                23:
                begin
                    assert(!lookup_hit);

                    // Replace an existing entry
                    update_page(VPAGE2, PPAGE6, 0, 1, 0, 1, 1);
                end

                24:
                begin
                    // Look up the entry we just replaced to ensure it has
                    // been updated
                    lookup_page(VPAGE2, 0);
                end

                // skip 25
                26:
                begin
                    assert(lookup_hit);
                    assert(lookup_ppage_idx == PPAGE6);
                    assert(lookup_present);
                    assert(lookup_exe_writable);
                    assert(lookup_supervisor);

                    // Invalidate one entry.
                    invalidate_en <= 1;
                    request_vpage_idx <= VPAGE3;
                end

                // Check for the page we just invalidated
                27: lookup_page(VPAGE3, 0);
                // skip 28
                29:
                begin
                    // page should now be gone
                    assert(!lookup_hit);

                    // Make sure other pages are still present
                    lookup_page(VPAGE2, 0);
                end

                // skip 30
                31:
                begin
                    assert(lookup_hit);
                    assert(lookup_ppage_idx == PPAGE6);
                    assert(lookup_present);
                    assert(lookup_exe_writable);
                    assert(lookup_supervisor);

                    // Invalidate all.
                    invalidate_all_en <= 1;
                end

                // Searching for all pages, ensure they've been blown away
                32:
                begin
                    invalidate_all_en <= 0;
                    lookup_page(VPAGE2, 0);
                end

                // skip 32
                33:
                begin
                    assert(!lookup_hit);
                    lookup_page(VPAGE3, 0);
                end

                // skip 34
                35:
                begin
                    assert(!lookup_hit);
                    lookup_page(VPAGE4, 0);
                end

                // skip 38
                37:
                begin
                    assert(!lookup_hit);
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
