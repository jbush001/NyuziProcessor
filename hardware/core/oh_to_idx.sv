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
// Convert a one-hot signal to a binary index corresponding to the active bit.
// (Binary encoder)
// If DIRECTION is "LSB0", index 0 corresponds to the least significant bit
// If "MSB0", index 0 corresponds to the most significant bit
//

module oh_to_idx
    #(parameter NUM_SIGNALS = 4,
    parameter DIRECTION = "LSB0",
    parameter INDEX_WIDTH = $clog2(NUM_SIGNALS))

    (input[NUM_SIGNALS - 1:0]         one_hot,
    output logic[INDEX_WIDTH - 1:0]   index);

    always_comb
    begin : convert
        index = 0;
        for (int oh_index = 0; oh_index < NUM_SIGNALS; oh_index++)
        begin
            if (one_hot[oh_index])
            begin
                if (DIRECTION == "LSB0")
                    index |= oh_index[INDEX_WIDTH - 1:0];    // Use 'or' to avoid synthesizing priority encoder
                else
                    index |= INDEX_WIDTH'(NUM_SIGNALS - oh_index - 1);
            end
        end
    end
endmodule
