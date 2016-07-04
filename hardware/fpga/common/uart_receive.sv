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
// Serial receive logic
//

module uart_receive
    #(parameter DIVISOR_WIDTH = 16)
    (input                        clk,
    input                         reset,
    input[DIVISOR_WIDTH - 1:0]    clocks_per_bit,
    input                         uart_rx,
    output[7:0]                   rx_char,
    output logic                  rx_char_valid,
    output logic                  rx_frame_error);

    typedef enum {
        STATE_WAIT_START,
        STATE_READ_CHARACTER,
        STATE_STOP_BITS
    } receive_state_t;

    receive_state_t state_ff;
    receive_state_t state_nxt;
    logic[DIVISOR_WIDTH - 1:0] sample_count_ff;
    logic[DIVISOR_WIDTH - 1:0] sample_count_nxt;
    logic[7:0] shift_register;
    logic[3:0] bit_count_ff;
    logic[3:0] bit_count_nxt;
    logic do_shift;
    logic rx_sync;

    assign rx_char = shift_register;

    // If it's out of sync, rx_sync is 0 from a new start bit.
    // Sampling it at the end may be sufficient to indicate frame error.
    assign rx_frame_error = !rx_sync;

    synchronizer #(.RESET_STATE(1)) rx_synchronizer(
        .clk(clk),
        .reset(reset),
        .data_i(uart_rx),
        .data_o(rx_sync));

    always_comb
    begin
        bit_count_nxt = bit_count_ff;
        state_nxt = state_ff;
        sample_count_nxt = sample_count_ff;
        rx_char_valid = 0;
        do_shift = 0;

        unique case (state_ff)
            STATE_WAIT_START:
            begin
                if (!rx_sync)
                begin
                    state_nxt = STATE_READ_CHARACTER;
                    // We are at the beginning of the start bit. Next
                    // sample point is in middle of first data bit.
                    // Set divider to 1.5 times bit duration.
                    sample_count_nxt = clocks_per_bit + {1'b0, clocks_per_bit[DIVISOR_WIDTH - 1:1]};
                end
            end

            STATE_READ_CHARACTER:
            begin
                if (sample_count_ff == 0)
                begin
                    sample_count_nxt = clocks_per_bit;
                    do_shift = 1;
                    if (bit_count_ff == 7)
                    begin
                        state_nxt = STATE_STOP_BITS;
                        bit_count_nxt = 0;
                    end
                    else
                        bit_count_nxt = bit_count_ff + 4'd1;
                end
                else
                    sample_count_nxt = sample_count_ff - DIVISOR_WIDTH'(1);
            end

            STATE_STOP_BITS:
            begin
                if (sample_count_ff == 0)
                begin
                    state_nxt = STATE_WAIT_START;
                    rx_char_valid = 1;
                end
                else
                    sample_count_nxt = sample_count_ff - DIVISOR_WIDTH'(1);
            end
        endcase
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            state_ff <= STATE_WAIT_START;
            /*AUTORESET*/
            // Beginning of autoreset for uninitialized flops
            bit_count_ff <= '0;
            sample_count_ff <= '0;
            shift_register <= '0;
            // End of automatics
        end
        else
        begin
            state_ff <= state_nxt;
            sample_count_ff <= sample_count_nxt;
            bit_count_ff <= bit_count_nxt;
            if (do_shift)
                shift_register <= {rx_sync, shift_register[7:1]};
        end
    end
endmodule

