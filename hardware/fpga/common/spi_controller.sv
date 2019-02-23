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
// Serial Peripheral Interface (SPI) bus controller
// It is hard coded to act as a master, and to run in "mode 0"
// (shift data out on falling edge, sample on rising, clock idles low)
//

module spi_controller
    #(parameter BASE_ADDRESS = 0)

    (input                      clk,
    input                       reset,
    io_bus_interface.slave      io_bus,

    // SPI interface
    output logic                spi_clk,
    output logic                spi_cs_n,
    input                       spi_miso,
    output logic                spi_mosi);

    localparam TX_REG = BASE_ADDRESS;
    localparam RX_REG = BASE_ADDRESS + 4;
    localparam RX_STATUS_REG = BASE_ADDRESS + 8;
    localparam CONTROL_REG = BASE_ADDRESS + 12;
    localparam DIVISOR_REG = BASE_ADDRESS + 16;

    logic transfer_active;
    logic[2:0] transfer_count;
    logic[7:0] miso_byte;    // Master in slave out
    logic[7:0] mosi_byte;    // Master out slave in
    logic[7:0] divider_countdown;
    logic[7:0] divider_rate;

    always_ff @(posedge reset, posedge clk)
    begin
        if (reset)
        begin
            transfer_active <= 0;
            spi_clk <= 0;
            spi_cs_n <= 1;
            divider_rate <= 1;
            spi_mosi <= 1;
        end
        else
        begin
            if (io_bus.address == RX_REG)
                io_bus.read_data <= scalar_t'(miso_byte);
            else // RX_STATUS_REG
                io_bus.read_data <= scalar_t'(!transfer_active);

            // Control register
            if (io_bus.write_en)
            begin
                if (io_bus.address == CONTROL_REG)
                    spi_cs_n <= io_bus.write_data[0];
                else if (io_bus.address == DIVISOR_REG)
                    divider_rate <= io_bus.write_data[7:0];
            end

            if (transfer_active)
            begin
                if (divider_countdown == 0)
                begin
                    divider_countdown <= divider_rate;
                    spi_clk <= !spi_clk;
                    if (spi_clk)
                    begin
                        // Falling edge
                        if (transfer_count == 0)
                            transfer_active <= 0;
                        else
                        begin
                            transfer_count <= transfer_count - 3'd1;

                            // Shift out a bit
                            {spi_mosi, mosi_byte} <= {mosi_byte, 1'd0};
                        end
                    end
                    else
                    begin
                        // Rising edge
                        miso_byte <= {miso_byte[6:0], spi_miso};
                    end
                end
                else
                    divider_countdown <= divider_countdown - 8'd1;
            end
            else if (io_bus.write_en && io_bus.address == TX_REG)
            begin
                assert(spi_clk == 0);

                // Start new transfer
                transfer_active <= 1;
                transfer_count <= 7;
                divider_countdown <= divider_rate;

                // Set up first bit
                {spi_mosi, mosi_byte} <= {io_bus.write_data[7:0], 1'd0};
            end
            else
                spi_mosi <= 1;  // High when there is no activity
        end
    end
endmodule
