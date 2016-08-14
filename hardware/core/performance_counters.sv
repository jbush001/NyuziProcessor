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
// Collects statistics from various modules used for performance measuring and tuning.
// Counts the number of discrete events in each category.
//

module performance_counters
    #(parameter BASE_ADDRESS = 0,
    parameter NUM_EVENTS = 1)

    (input                           clk,
    input                            reset,
    input[NUM_EVENTS - 1:0]          perf_events,
    io_bus_interface.slave           io_bus);

    localparam NUM_COUNTERS = 4;
    localparam COUNTER_IDX_WIDTH = $clog2(NUM_COUNTERS);
    localparam EVENT_IDX_WIDTH = $clog2(NUM_EVENTS);

    // Address 0 to (NUM_COUNTERS - 1): event select (write)
    // Address NUM_COUNTERS to (NUM_COUNTERS * 2 - 1): event count (read)

    logic[31:0] event_counter[NUM_COUNTERS];
    logic[EVENT_IDX_WIDTH - 1:0] event_select[NUM_COUNTERS];
    logic[31:0] read_addr;
    logic[COUNTER_IDX_WIDTH - 1:0] read_idx;

    assign read_addr = io_bus.address - (BASE_ADDRESS + NUM_COUNTERS * 4);
    assign read_idx = read_addr[2+:COUNTER_IDX_WIDTH];

    always_ff @(posedge clk)
        io_bus.read_data <= event_counter[read_idx];

    always_ff @(posedge clk, posedge reset)
    begin : update
        if (reset)
        begin
            for (int i = 0; i < NUM_COUNTERS; i++)
            begin
                event_counter[i] <= 0;
                event_select[i] <= 0;
            end
        end
        else
        begin
            for (int i = 0; i < NUM_COUNTERS; i++)
            begin
                if (perf_events[event_select[i]])
                    event_counter[i] <= event_counter[i] + 1;

                if (io_bus.write_en && io_bus.address == BASE_ADDRESS + (i * 4))
                    event_select[i] <= io_bus.write_data[EVENT_IDX_WIDTH - 1:0];
            end
        end
    end
endmodule
