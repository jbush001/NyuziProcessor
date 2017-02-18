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
// Serial transmit logic
//

module uart_transmit
    #(parameter DIVISOR_WIDTH = 16)
    (input                        clk,
    input                         reset,
    input[DIVISOR_WIDTH - 1:0]    clocks_per_bit,
    input                         tx_en,
    output logic                  tx_ready,
    input[7:0]                    tx_char,
    output logic                  uart_tx);

    localparam START_BIT = 1'b0;
    localparam STOP_BIT = 1'b1;

    logic[9:0] tx_shift;
    logic[3:0] shift_count;
    logic[DIVISOR_WIDTH - 1:0] next_edge_clocks;
    logic transmit_active;

    assign transmit_active = shift_count != 0;
    assign uart_tx = transmit_active ? tx_shift[0] : 1'b1;
    assign tx_ready = !transmit_active;

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            next_edge_clocks <= '0;
            shift_count <= '0;
            tx_shift <= '0;
            // End of automatics
        end
        else
        begin
            if (transmit_active)
            begin
                if (next_edge_clocks == 0)
                begin
                    shift_count <= shift_count - 4'd1;
                    tx_shift <= {1'b0, tx_shift[9:1]};
                    next_edge_clocks <= clocks_per_bit;
                end
                else
                    next_edge_clocks <= next_edge_clocks - DIVISOR_WIDTH'(1);
            end
            else if (tx_en)
            begin
                shift_count <= 4'd10;
                tx_shift <= {STOP_BIT, tx_char, START_BIT};
                next_edge_clocks <= clocks_per_bit;
            end
        end
    end
endmodule
