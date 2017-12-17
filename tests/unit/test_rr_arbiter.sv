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

module test_rr_arbiter(input clk, input reset);
    localparam NUM_REQUESTERS = 4;

    logic[NUM_REQUESTERS - 1:0] request;
    logic update_lru;
    logic[NUM_REQUESTERS - 1:0] grant_oh;
    int cycle;

    rr_arbiter #(.NUM_REQUESTERS(4)) rr_arbiter(.*);

    always @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            cycle <= 0;
            request <= 0;
            update_lru <= 0;
        end
        else
        begin
            cycle <= cycle + 1;
            unique case (cycle)
                // Make all inputs request
                0:
                begin
                    request <= 4'b1111;
                    update_lru <= 1;
                end

                // Test that it cycles through all bits
                1:  assert(grant_oh == 4'b0001);
                2:  assert(grant_oh == 4'b0010);
                3:  assert(grant_oh == 4'b0100);
                4:  assert(grant_oh == 4'b1000);
                5:
                begin
                    assert(grant_oh == 4'b0001);
                    update_lru <= 0;
                end

                // Update LRU cleared, ensure it doesn't update
                6: assert(grant_oh == 4'b0010);
                7: assert(grant_oh == 4'b0010);
                8: assert(grant_oh == 4'b0010);
                9:
                begin
                    assert(grant_oh == 4'b0010);

                    update_lru <= 1;
                    request <= 4'b0101;
                end

                // Test with two bits set
                10: assert(grant_oh == 4'b0100);
                11: assert(grant_oh == 4'b0001);
                12: assert(grant_oh == 4'b0100);
                13:
                begin
                    assert(grant_oh == 4'b0001);
                    request <= 4'b1010;
                end

                14: assert(grant_oh == 4'b0010);
                15: assert(grant_oh == 4'b1000);
                16:
                begin
                    assert(grant_oh == 4'b0010);
                    request <= 4'b0100;
                end

                // One bit set
                17: assert(grant_oh == 4'b0100);
                18: assert(grant_oh == 4'b0100);

                19:
                begin
                    assert(grant_oh == 4'b0100);
                    request <= 4'b0000;
                end

                // No requestors
                20: assert(grant_oh == 4'b0000);
                21: assert(grant_oh == 4'b0000);

                22:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase
        end
    end
endmodule
