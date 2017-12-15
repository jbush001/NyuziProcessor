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

module test_idx_to_oh(input clk, input reset);
    localparam NUM_SIGNALS = 8;

    logic[2:0] index;
    logic[NUM_SIGNALS - 1:0] one_hot0;
    logic[NUM_SIGNALS - 1:0] one_hot1;

    idx_to_oh #(
        .NUM_SIGNALS(NUM_SIGNALS),
        .DIRECTION("LSB0")
    ) idx_to_oh0(
        .one_hot(one_hot0),
        .*);

    idx_to_oh #(
        .NUM_SIGNALS(NUM_SIGNALS),
        .DIRECTION("MSB0")
    ) idx_to_oh1(
        .one_hot(one_hot1),
        .*);

    always @(posedge clk, posedge reset)
    begin
        if (reset)
            index <= 0;
        else
        begin
            if (index == 7)
            begin
                $display("PASS");
                $finish;
            end
            else
                index <= index + 1;

            assert(one_hot0 == 1 << index);
            assert(one_hot1 == 8'b10000000 >> index);
        end
    end
endmodule
