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

//
// sync_fifo has different implementations for different technologies
// (each FPGA has its own IP blocks), so this only validates the simulator
// version.
//

module test_sync_fifo(input clk, input reset);
    localparam WIDTH = 32;
    localparam FIFO_SIZE = 8;
    localparam ALMOST_FULL_THRESHOLD = 6;
    localparam ALMOST_EMPTY_THRESHOLD = 2;
    localparam TOTAL_VALUES = 10;

    logic flush_en;
    logic full;
    logic almost_full;
    logic enqueue_en;
    logic [WIDTH - 1:0] value_i;
    logic empty;
    logic almost_empty;
    logic dequeue_en;
    logic[WIDTH - 1:0] value_o;
    int expected_fifo_count;
    int next_fifo_count;
    enum {
        FILLING,
        EMPTY1,
        PAUSE1,
        EMPTY2,
        PAUSE2,
        EMPTY3
    } state = FILLING;
    int enqueue_index;
    int dequeue_index;
    logic[31:0] values[TOTAL_VALUES];
    logic last_dequeue;

    sync_fifo #(
        .WIDTH(32),
        .SIZE(FIFO_SIZE),
        .ALMOST_FULL_THRESHOLD(ALMOST_FULL_THRESHOLD),
        .ALMOST_EMPTY_THRESHOLD(ALMOST_EMPTY_THRESHOLD)
    ) sync_fifo(.*);

    assign value_i = values[enqueue_index];

    always @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            expected_fifo_count <= 0;
            next_fifo_count <= 0;
            enqueue_index <= 0;
            dequeue_index <= 0;
            last_dequeue <= 0;
            for (int i = 0; i < TOTAL_VALUES; i++)
                values[i] <= $random();
        end
        else
        begin
            // Default values
            flush_en <= 0;
            enqueue_en <= 0;
            dequeue_en <= 0;

            last_dequeue <= 0;
            expected_fifo_count <= next_fifo_count;

            assert(almost_full == expected_fifo_count >= ALMOST_FULL_THRESHOLD);
            assert(almost_empty == expected_fifo_count <= ALMOST_EMPTY_THRESHOLD);
            assert(full == 1'(expected_fifo_count == FIFO_SIZE));
            assert(empty == 1'(expected_fifo_count == 0));
            assert(!last_dequeue || value_o == values[dequeue_index]);

            case (state)
                FILLING:
                begin
                    if (next_fifo_count == FIFO_SIZE)
                        state <= EMPTY1;
                    else
                    begin
                        enqueue_en <= 1;
                        next_fifo_count <= next_fifo_count + 1;
                        enqueue_index <= enqueue_index + 1;
                    end
                end

                EMPTY1:
                begin
                    if (next_fifo_count == ALMOST_FULL_THRESHOLD)
                        state <= PAUSE1;
                    else
                    begin
                        dequeue_en <= 1;
                        next_fifo_count <= next_fifo_count - 1;
                        dequeue_index <= dequeue_index + 1;
                    end
                end

                PAUSE1:
                begin
                    state <= EMPTY2;
                    dequeue_en <= 1;
                    enqueue_en <= 1;
                end

                EMPTY2:
                begin
                    if (next_fifo_count == ALMOST_EMPTY_THRESHOLD)
                        state <= PAUSE2;
                    else
                    begin
                        dequeue_en <= 1;
                        next_fifo_count <= next_fifo_count - 1;
                        dequeue_index <= dequeue_index + 1;
                    end
                end

                PAUSE2:
                begin
                    state <= EMPTY3;
                    dequeue_en <= 1;
                    enqueue_en <= 1;
                end

                EMPTY3:
                begin
                    if (next_fifo_count == 0)
                    begin
                        $display("PASS");
                        $finish;
                    end
                    else
                    begin
                        dequeue_en <= 1;
                        next_fifo_count <= next_fifo_count - 1;
                        dequeue_index <= dequeue_index + 1;
                    end
                end
            endcase
        end
    end
endmodule
