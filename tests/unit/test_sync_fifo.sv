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
    localparam TOTAL_VALUES = 15;

    logic flush_en;
    logic full;
    logic almost_full;
    logic enqueue_en;
    logic [WIDTH - 1:0] value_i;
    logic empty;
    logic almost_empty;
    logic dequeue_en;
    logic[WIDTH - 1:0] value_o;
    enum {
        FILL1,
        EMPTY1,
        PAUSE1,
        EMPTY2,
        PAUSE2,
        EMPTY3,
        FILL2,
        FLUSH,
        DONE
    } state = FILL1;
    int enqueue_index;
    int dequeue_index;
    logic[WIDTH - 1:0] values[TOTAL_VALUES];
    int expected_fifo_count;
    logic[WIDTH - 1:0] expected_value_o;

    sync_fifo #(
        .WIDTH(32),
        .SIZE(FIFO_SIZE),
        .ALMOST_FULL_THRESHOLD(ALMOST_FULL_THRESHOLD),
        .ALMOST_EMPTY_THRESHOLD(ALMOST_EMPTY_THRESHOLD)
    ) sync_fifo(.*);

    always @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            expected_fifo_count <= 0;
            expected_value_o <= 0;
            enqueue_index <= 0;
            dequeue_index <= 0;
            for (int i = 0; i < TOTAL_VALUES; i++)
                values[i] <= $random();
        end
        else
        begin
            // Default values
            flush_en <= 0;
            enqueue_en <= 0;
            dequeue_en <= 0;

            assert(almost_full == expected_fifo_count >= ALMOST_FULL_THRESHOLD);
            assert(almost_empty == expected_fifo_count <= ALMOST_EMPTY_THRESHOLD);
            assert(full == 1'(expected_fifo_count == FIFO_SIZE));
            assert(empty == 1'(expected_fifo_count == 0));
            assert(expected_fifo_count == 0 || value_o == expected_value_o);

            if (flush_en)
                expected_fifo_count <= 0;
            else if (dequeue_en && !enqueue_en)
                expected_fifo_count <= expected_fifo_count - 1;
            else if (enqueue_en && !dequeue_en)
                expected_fifo_count <= expected_fifo_count + 1;

            if (dequeue_en)
            begin
                dequeue_index <= dequeue_index + 1;
                expected_value_o <= values[dequeue_index];
            end

            if (enqueue_en)
            begin
                value_i <= values[enqueue_index];
                enqueue_index <= enqueue_index + 1;
            end

            unique case (state)
                FILL1:
                begin
                    if (expected_fifo_count == FIFO_SIZE - 1)
                        state <= EMPTY1;
                    else
                        enqueue_en <= 1;
                end

                EMPTY1:
                begin
                    if (expected_fifo_count == ALMOST_FULL_THRESHOLD - 1)
                        state <= PAUSE1;
                    else
                        dequeue_en <= 1;
                end

                PAUSE1:
                begin
                    state <= EMPTY2;
                    dequeue_en <= 1;
                    enqueue_en <= 1;
                end

                EMPTY2:
                begin
                    if (expected_fifo_count == ALMOST_EMPTY_THRESHOLD + 1)
                        state <= PAUSE2;
                    else
                        dequeue_en <= 1;
                end

                PAUSE2:
                begin
                    state <= EMPTY3;
                    dequeue_en <= 1;
                    enqueue_en <= 1;
                end

                EMPTY3:
                begin
                    if (expected_fifo_count == 1)
                        state <= FILL2;
                    else
                        dequeue_en <= 1;
                end

                FILL2:
                begin
                    if (expected_fifo_count == 4)
                        state <= FLUSH;
                    else
                        enqueue_en <= 1;
                end

                FLUSH:
                begin
                    flush_en <= 1;
                    state <= DONE;
                end

                DONE:
                begin
                    $display("PASS");
                    $finish;
                end
            endcase

            // XXX test flush
        end
    end
endmodule
