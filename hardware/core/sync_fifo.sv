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

`include "defines.svh"

import defines::*;

//
// First-in, first-out queue, with synchronous read/write
// - SIZE must be a power of two and greater than or equal to 4.
// - almost_full asserts when there are ALMOST_FULL_THRESHOLD or more entries
//   queued.
// - almost_empty asserts when there are ALMOST_EMPTY_THRESHOLD or fewer
//   entries queued.
// - almost_full is still asserted when full is asserted, as is almost_empty
//   when empty is asserted.
// - flush takes precedence over enqueue/dequeue if it is asserted
//   simultaneously. It is synchronous, unlike reset.
// - It is not legal to assert enqueue when the FIFO is full or dequeue when it
//   is empty (The former is true even if there is a dequeue and enqueue in the
//   same cycle, which wouldn't change the count). Doing this will trigger an
//   error in the simulator and have incorrect behavior in synthesis.
// - dequeue_value will contain the next value to be dequeued even if dequeue_en is
//   not asserted.
//

module sync_fifo
    #(parameter WIDTH = 64,
    parameter SIZE = 4,
    parameter ALMOST_FULL_THRESHOLD = SIZE,
    parameter ALMOST_EMPTY_THRESHOLD = 1)

    (input                       clk,
    input                        reset,
    input                        flush_en,    // flush is synchronous, unlike reset
    output logic                 full,
    output logic                 almost_full,
    input                        enqueue_en,
    input [WIDTH - 1:0]          enqueue_value,
    output logic                 empty,
    output logic                 almost_empty,
    input                        dequeue_en,
    output logic[WIDTH - 1:0]    dequeue_value);

`ifdef VENDOR_ALTERA
    SCFIFO #(
        .almost_empty_value(ALMOST_EMPTY_THRESHOLD + 1),
        .almost_full_value(ALMOST_FULL_THRESHOLD),
        .lpm_numwords(SIZE),
        .lpm_width(WIDTH),
        .lpm_showahead("ON")
    ) scfifo(
        .aclr(reset),
        .almost_empty(almost_empty),
        .almost_full(almost_full),
        .clock(clk),
        .data(enqueue_value),
        .empty(empty),
        .full(full),
        .q(dequeue_value),
        .rdreq(dequeue_en),
        .sclr(flush_en),
        .wrreq(enqueue_en));
`elsif MEMORY_COMPILER
    generate
        `define _GENERATE_FIFO
        `include "srams.inc"
        `undef     _GENERATE_FIFO
    endgenerate
`else
    // Simulation
    localparam ADDR_WIDTH = $clog2(SIZE);

    logic[ADDR_WIDTH - 1:0] head;
    logic[ADDR_WIDTH - 1:0] tail;
    logic[ADDR_WIDTH:0] count;
    logic[WIDTH - 1:0] data[SIZE];

    assign almost_full = count >= (ADDR_WIDTH + 1)'(ALMOST_FULL_THRESHOLD);
    assign almost_empty = count <= (ADDR_WIDTH + 1)'(ALMOST_EMPTY_THRESHOLD);
    assign full = count == SIZE;
    assign empty = count == 0;
    assign dequeue_value = data[head];

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            head <= 0;
            tail <= 0;
            count <= 0;
        end
        else
        begin
            if (flush_en)
            begin
                head <= 0;
                tail <= 0;
                count <= 0;
            end
            else
            begin
                if (enqueue_en)
                begin
                    assert(!full);
                    tail <= tail + 1;
                    data[tail] <= enqueue_value;
                end

                if (dequeue_en)
                begin
                    assert(!empty);
                    head <= head + 1;
                end

                if (enqueue_en && !dequeue_en)
                    count <= count + 1;
                else if (dequeue_en && !enqueue_en)
                    count <= count - 1;
            end
        end
    end

    initial
    begin
        if ($test$plusargs("dumpmems") != 0)
            $display("sync_fifo %d %d", WIDTH, SIZE);
    end
`endif
endmodule
