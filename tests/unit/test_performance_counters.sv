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

module test_performance_counters(input clk, input reset);
    localparam NUM_EVENTS = 8;
    localparam NUM_SAMPLES = 8;
    localparam NUM_COUNTERS = 4;    // defined inside performance_counters
    localparam BASE_ADDRESS = 'h128;

    logic[NUM_EVENTS - 1:0] perf_events;
    io_bus_interface io_bus();
    enum {
        SELECT_COUNTER,
        COUNT_EVENTS,
        READ_COUNTERS
    } state;
    int pass;
    int state_counter;

    logic[NUM_EVENTS - 1:0] sample_list[NUM_SAMPLES];
    int expected_counts[NUM_EVENTS];

    performance_counters #(
        .BASE_ADDRESS(BASE_ADDRESS),
        .NUM_EVENTS(NUM_EVENTS)
    ) performance_counters(.*);

    initial
    begin
        // This is a list of performance events, indexed by cycle
        sample_list[0] = 8'b1110_1101;
        sample_list[1] = 8'b1001_1100;
        sample_list[2] = 8'b1000_0101;
        sample_list[3] = 8'b1001_1100;
        sample_list[4] = 8'b0111_1101;
        sample_list[5] = 8'b0000_1101;
        sample_list[6] = 8'b0100_0100;
        sample_list[7] = 8'b1100_1101;

        // Counts for each event (starting from lsb)
        expected_counts[0] = 5;
        expected_counts[1] = 0;
        expected_counts[2] = 8;
        expected_counts[3] = 6;

        // These will be read on second pass, so they the sum of the
        // counts above and the counts of event 4-7
        expected_counts[4] = 8;
        expected_counts[5] = 2;
        expected_counts[6] = 12;
        expected_counts[7] = 11;
    end

    always @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            state <= SELECT_COUNTER;
            state_counter <= 0;
            pass <= 0;
        end
        else
        begin
            // Default values
            io_bus.write_en <= 0;
            io_bus.read_en <= 0;
            perf_events <= '0;

            unique case (state)
                // Write to configuration register to select counters
                SELECT_COUNTER:
                begin
                    if (state_counter == NUM_COUNTERS - 1)
                    begin
                        state_counter <= 0;
                        state <= COUNT_EVENTS;
                    end
                    else
                    begin
                        // Write the event select registers
                        state_counter <= state_counter + 1;
                    end

                    io_bus.write_en <= 1;
                    io_bus.address <= BASE_ADDRESS + state_counter * 4;

                    // Select even counters on first pass, odd on second
                    io_bus.write_data <= state_counter + pass * 4;
                end

                COUNT_EVENTS:
                begin
                    if (state_counter == NUM_SAMPLES - 1)
                    begin
                        state_counter <= 0;
                        state <= READ_COUNTERS;
                    end
                    else
                        state_counter <= state_counter + 1;

                    perf_events <= sample_list[state_counter];
                end

                // Check values of counters to make sure they match
                // expected values.
                READ_COUNTERS:
                begin
                    // The +1 is latency of setting the io bus signals and
                    // getting a response from the module minus one.
                    if (state_counter == NUM_COUNTERS + 1)
                    begin
                        if (pass == 1)
                        begin
                            $display("PASS");
                            $finish;
                        end
                        else
                        begin
                            state_counter <= 0;
                            state <= SELECT_COUNTER;
                            pass <= pass + 1;
                        end
                    end
                    else
                    begin
                        state_counter <= state_counter + 1;
                    end

                    if (state_counter < NUM_COUNTERS)
                    begin
                        io_bus.read_en <= 1;
                        io_bus.address <= BASE_ADDRESS + (NUM_COUNTERS + state_counter) * 4;
                    end

                    // The result shows up one cycle after the rest, so we
                    // start sampling after one has been sent (this also factors
                    // in the delay of registers in this module)
                    if (state_counter > 1)
                        assert(io_bus.read_data == expected_counts[state_counter - 2 + pass * 4]);
                end
            endcase
        end
    end
endmodule
