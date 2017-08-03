//
// Copyright 2015 Jeff Bush
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
// This simulates a PS/2 keyboard. It periodically generates scancodes. The
// ps2_controller connects to this to execute tests in simulation.
//

module sim_ps2(
    input               clk,
    input               reset,
    output logic        ps2_clk,
    output logic        ps2_data);

    // This is much faster than the PS/2 controller would run normally,
    // but it makes the test take less time.
    localparam DIVIDER_COUNT = 500;

    int output_counter;
    int divider_countdown;
    logic[7:0] tx_byte;

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            output_counter <= 0;
            ps2_clk <= 1;
            ps2_data <= 1;
            tx_byte <= 0;
            divider_countdown <= DIVIDER_COUNT;
        end
        else if (divider_countdown == 0)
        begin
            divider_countdown <= DIVIDER_COUNT;
            ps2_clk <= !ps2_clk;
            if (!ps2_clk)
            begin
                // Transmit byte on rising edge
                output_counter <= output_counter + 1;
                if (output_counter == 0)
                    ps2_data <= 1'b0;    // start bit
                else if (output_counter <= 8)
                    ps2_data <= tx_byte[output_counter - 1];
                else if (output_counter == 9)
                    ps2_data <= !(^tx_byte);    // parity (odd)
                else if (output_counter == 10)
                begin
                    ps2_data <= 1'b1;        // stop bit
                    output_counter <= 0;
                    tx_byte <= tx_byte + 1;
                end
            end
        end
        else
            divider_countdown <= divider_countdown - 1;
    end
endmodule
