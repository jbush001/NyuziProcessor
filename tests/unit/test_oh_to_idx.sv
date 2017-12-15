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

module test_oh_to_idx(input clk, input reset);
    localparam NUM_SIGNALS = 8;

    logic[2:0] index0;
    logic[2:0] index1;
    logic[NUM_SIGNALS - 1:0] one_hot;
    int counter;

    oh_to_idx #(
        .NUM_SIGNALS(NUM_SIGNALS),
        .DIRECTION("LSB0")
    ) oh_to_idx0(
        .index(index0),
        .*);

    oh_to_idx #(
        .NUM_SIGNALS(NUM_SIGNALS),
        .DIRECTION("MSB0")
    ) oh_to_idx1(
        .index(index1),
        .*);

    always @(posedge clk, posedge reset)
    begin
        if (reset)
            counter <= 0;
        else
        begin
            if (counter == 8)
            begin
                $display("PASS");
                $finish;
            end

            one_hot <= 1 << counter;
            counter <= counter + 1;
            if (counter > 0)
            begin
                assert(index0 == 3'(counter - 1));
                assert(index1 == 3'(8 - counter));
            end
        end
    end
endmodule
