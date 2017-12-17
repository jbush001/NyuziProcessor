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

module test_cam(input clk, input reset);
    localparam NUM_ENTRIES = 8;
    localparam KEY_WIDTH = 32;
    localparam INDEX_WIDTH = $clog2(NUM_ENTRIES);
    localparam KEY0 = 32'h8893e3a2;
    localparam KEY1 = 32'h598b0b6e;
    localparam KEY2 = 32'h2b673373;
    localparam KEY3 = 32'h72c2b435;
    localparam KEY4 = 32'h5774490b;

    logic [KEY_WIDTH - 1:0] lookup_key;
    logic[INDEX_WIDTH - 1:0] lookup_idx;
    logic lookup_hit;
    logic update_en;
    logic [KEY_WIDTH - 1:0] update_key;
    logic [INDEX_WIDTH - 1:0] update_idx;
    logic update_valid;
    int cycle;

    cam #(
        .NUM_ENTRIES(NUM_ENTRIES),
        .KEY_WIDTH(KEY_WIDTH),
        .INDEX_WIDTH(INDEX_WIDTH)
    ) cam(.*);

    always @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            cycle <= 0;
            lookup_key <= '0;
            update_en <= 0;
            update_key <= 0;
            update_idx <= 0;
            update_valid <= 0;
        end
        else
        begin
            cycle <= cycle + 1;
            unique case (cycle)
                // Insert a few entries
                0:
                begin
                    update_en <= 1;
                    update_idx <= 0;
                    update_valid <= 1;
                    update_key <= KEY0;
                end

                1:
                begin
                    update_idx <= 1;
                    update_key <= KEY1;
                end

                2:
                begin
                    update_idx <= 2;
                    update_key <= KEY2;
                end

                3:
                begin
                    update_idx <= 3;
                    update_key <= KEY3;
                end

                // Perform some lookups
                4:
                begin
                    update_en <= 0;
                    lookup_key <= KEY2;
                end

                5:
                begin
                    assert(lookup_hit);
                    assert(lookup_idx == 2);

                    lookup_key <= KEY1;
                end

                6:
                begin
                    assert(lookup_hit);
                    assert(lookup_idx == 1);

                    lookup_key <= KEY4; // Doesn't exist
                end

                // Replace entry 2
                7:
                begin
                    assert(!lookup_hit);
                    update_en <= 1;
                    update_key <= KEY4;
                    update_idx <= 2;
                end

                8:
                begin
                    update_en <= 0;
                    lookup_key <= KEY4;
                end

                9:
                begin
                    // new entry is present
                    assert(lookup_hit);
                    assert(lookup_idx == 2);
                    lookup_key <= KEY2;
                end

                10:
                begin
                    // Old entry is no longer present
                    assert(!lookup_hit);
                end

                // Remove entry 1
                11:
                begin
                    // Note: use existing key to validate previous bug where an assertion
                    // would incorrectly detect a key collision. The key should be ignored
                    // if valid is 0.
                    update_key <= KEY4;
                    update_en <= 1;
                    update_idx <= 1;
                    update_valid <= 0;
                end

                12:
                begin
                    update_en <= 0;
                    lookup_key <= KEY1;
                end

                13:
                begin
                    assert(!lookup_hit);
                    lookup_key <= KEY3;
                end

                14:
                begin
                    assert(lookup_hit);
                    assert(lookup_idx == 3);
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule

