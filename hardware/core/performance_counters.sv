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
    #(parameter NUM_EVENTS = 1,
    parameter EVENT_IDX_WIDTH = $clog2(NUM_EVENTS),
    parameter NUM_COUNTERS = 2,
    parameter COUNTER_IDX_WIDTH = $clog2(NUM_COUNTERS))

    (input                                              clk,
    input                                               reset,
    input [NUM_EVENTS - 1:0]                            perf_events,
    input [NUM_COUNTERS - 1:0][EVENT_IDX_WIDTH - 1:0]   perf_event_select,
    output logic[NUM_COUNTERS - 1:0][63:0]              perf_event_count);

    always_ff @(posedge clk, posedge reset)
    begin : update
        if (reset)
        begin
            for (int i = 0; i < NUM_COUNTERS; i++)
                perf_event_count[i] <= 0;
        end
        else
        begin
            for (int i = 0; i < NUM_COUNTERS; i++)
            begin
                if (perf_events[perf_event_select[i]])
                    perf_event_count[i] <= perf_event_count[i] + 1;
            end
        end
    end
endmodule
