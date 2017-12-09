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
// Transfer a signal into a clock domain, avoiding metastability and
// race conditions due to propagation delay.
//

module synchronizer
    #(parameter WIDTH = 1,
    parameter RESET_STATE = 0)

    (input                      clk,
    input                       reset,
    output logic[WIDTH - 1:0]   data_o,
    input [WIDTH - 1:0]         data_i);

    logic[WIDTH - 1:0] sync0;
    logic[WIDTH - 1:0] sync1;

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            sync0 <= WIDTH'(RESET_STATE);
            sync1 <= WIDTH'(RESET_STATE);
            data_o <= WIDTH'(RESET_STATE);
        end
        else
        begin
            sync0 <= data_i;
            sync1 <= sync0;
            data_o <= sync1;
        end
    end
endmodule
