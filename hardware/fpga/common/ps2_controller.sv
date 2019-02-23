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

`include "defines.svh"

import defines::*;

//
// PS/2 keyboard or mouse controller. Only supports receiving.
//

module ps2_controller
    #(parameter BASE_ADDRESS = 0)

    (input                      clk,
    input                       reset,
    io_bus_interface.slave      io_bus,
    output logic                rx_interrupt,

    // PS/2 Interface
    input                       ps2_clk,
    input                       ps2_data);

    localparam STATUS_REG = BASE_ADDRESS;
    localparam DATA_REG = BASE_ADDRESS + 4;
    localparam FIFO_LENGTH = 16;

    typedef enum logic[1:0] {
        STATE_WAIT_START,
        STATE_READ_CHARACTER,
        STATE_READ_PARITY,
        STATE_READ_STOP_BIT
    } receive_state_t;

    logic ps2_clk_sync;
    logic ps2_data_sync;
    logic ps2_clk_prev;
    receive_state_t state_ff;
    logic[2:0] bit_count;
    logic[7:0] receive_byte;
    logic[7:0] dequeue_data;
    logic read_fifo_empty;
    logic fifo_almost_full;
    logic enqueue_en;

    assign rx_interrupt = !read_fifo_empty;

    synchronizer #(.WIDTH(2), .RESET_STATE(2'b11)) input_synchronizer(
        .data_i({ps2_clk, ps2_data}),
        .data_o({ps2_clk_sync, ps2_data_sync}),
        .*);

    // If the FIFO hits the almost full threshold, we dequeue an entry (dropping the oldest
    // character). Use the almost full threshold instead of full because the Altera specs
    // say it is not allowed to enqueue into a full FIFO. Although it seems like this should
    // be legal if read is also asserted, I'm being conservative.
    sync_fifo #(.WIDTH(8), .SIZE(FIFO_LENGTH), .ALMOST_FULL_THRESHOLD(FIFO_LENGTH - 1)) input_fifo(
        .flush_en(0),
        .full(),
        .almost_full(fifo_almost_full),
        .enqueue_en(enqueue_en),
        .enqueue_value(receive_byte),
        .empty(read_fifo_empty),
        .almost_empty(),
        .dequeue_en((io_bus.read_en && io_bus.address == DATA_REG && !read_fifo_empty) || fifo_almost_full),
        .dequeue_value(dequeue_data),
        .*);

    always @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            ps2_clk_prev <= 1;
            state_ff <= STATE_WAIT_START;
            bit_count <= 0;
            enqueue_en <= 0;
        end
        else
        begin
            if (io_bus.address == STATUS_REG)
                io_bus.read_data <= scalar_t'(!read_fifo_empty);
            else
                io_bus.read_data <= scalar_t'(dequeue_data);

            ps2_clk_prev <= ps2_clk_sync;
            enqueue_en <= 0;
            if (ps2_clk_sync == 0 && ps2_clk_prev == 1)
            begin
                // Valid data on the falling edge
                case (state_ff)
                    STATE_WAIT_START:
                    begin
                        if (ps2_data_sync == 0)
                        begin
                            state_ff <= STATE_READ_CHARACTER;
                            bit_count <= 0;
                        end
                    end

                    STATE_READ_CHARACTER:
                    begin
                        bit_count <= bit_count + 3'd1;
                        if (bit_count == 7)
                            state_ff <= STATE_READ_PARITY;

                        receive_byte <= {ps2_data_sync, receive_byte[7:1]};
                    end

                    STATE_READ_PARITY:
                    begin
                        // XXX not checking parity

                        state_ff <= STATE_READ_STOP_BIT;
                    end

                    STATE_READ_STOP_BIT:
                    begin
                        // XXX not checking that stop bit is high

                        state_ff <= STATE_WAIT_START;
                        enqueue_en <= 1;
                    end
                endcase
            end
        end
    end
endmodule
