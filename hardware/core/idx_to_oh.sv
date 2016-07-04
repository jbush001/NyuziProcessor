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

//
// Convert a binary index to a one hot signal (Binary encoder)
// If DIRECTION is "LSB0", index 0 is the least significant bit
// If "MSB0", index 0 is the most significant bit
//

module idx_to_oh
    #(parameter NUM_SIGNALS = 4,
    parameter DIRECTION = "LSB0",
    parameter INDEX_WIDTH = $clog2(NUM_SIGNALS))

    (output logic[NUM_SIGNALS - 1:0]       one_hot,
    input [INDEX_WIDTH - 1:0]              index);

    always_comb
    begin : convert
        one_hot = 0;
        if (DIRECTION == "LSB0")
            one_hot[index] = 1'b1;
        else
            one_hot[~index] = 1'b1;
    end
endmodule

