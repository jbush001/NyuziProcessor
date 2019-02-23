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

`include "defines.svh"

import defines::*;

//
// Content addressable memory.
// Lookup is async: This asserts lookup_idx and lookup_hit the same cycle
// lookup_key is asserted. It registers the update signals on the edge of clk.
// If an update is performed to the same address as a lookup in the same clock
// cycle, it doesn't flag a match.
//

module cam
    #(parameter NUM_ENTRIES = 2,
    parameter KEY_WIDTH = 32,
    parameter INDEX_WIDTH = $clog2(NUM_ENTRIES))

    (input                           clk,
    input                            reset,

    // Lookup interface
    input [KEY_WIDTH - 1:0]          lookup_key,
    output logic[INDEX_WIDTH - 1:0]  lookup_idx,
    output logic                     lookup_hit,

    // Update interface
    input                            update_en,
    input [KEY_WIDTH - 1:0]          update_key,
    input [INDEX_WIDTH - 1:0]        update_idx,
    input                            update_valid);

    logic[KEY_WIDTH - 1:0] lookup_table[NUM_ENTRIES];
    logic[NUM_ENTRIES - 1:0] entry_valid;
    logic[NUM_ENTRIES - 1:0] hit_oh;

    genvar test_index;
    generate
        for (test_index = 0; test_index < NUM_ENTRIES; test_index++)
        begin : lookup_gen
            assign hit_oh[test_index] = entry_valid[test_index]
                && lookup_table[test_index] == lookup_key;
        end
    endgenerate

    assign lookup_hit = |hit_oh;
    oh_to_idx #(.NUM_SIGNALS(NUM_ENTRIES)) oh_to_idx_hit(
        .one_hot(hit_oh),
        .index(lookup_idx));

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            for (int i = 0; i < NUM_ENTRIES; i++)
                entry_valid[i] <= 1'b0;
        end
        else
        begin
            assert($onehot0(hit_oh));
            if (update_en)
                entry_valid[update_idx] <= update_valid;
        end
    end

    always_ff @(posedge clk)
    begin
        if (update_en)
            lookup_table[update_idx] <= update_key;
    end

`ifdef SIMULATION
    // Check for duplicate entries
    always_ff @(posedge clk, posedge reset)
    begin
        if (!reset && update_en && update_valid)
        begin : test
            for (int i = 0; i < NUM_ENTRIES; i++)
            begin
                if (entry_valid[i] && lookup_table[i] == update_key
                    && INDEX_WIDTH'(i) != update_idx)
                begin
                    $display("%m: added duplicate entry to CAM");
                    $display("  original slot %d new slot %d", i, update_idx);
                    $finish;
                end
            end
        end
    end
`endif

endmodule
