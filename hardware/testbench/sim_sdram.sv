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
// Simulates single data rate SDRAM. The size of this memory is
// the num rows * num columns * 4 banks * 4 bytes (bus width)
//

//`define SDRAM_DEBUG

module sim_sdram
    #(parameter DATA_WIDTH = 32,
    parameter ROW_ADDR_WIDTH = 12, // 4096 rows
    parameter COL_ADDR_WIDTH = 8, // 256 columns
    parameter MAX_REFRESH_INTERVAL = 800)

    (input                      dram_clk,
    input                       dram_cke,
    input                       dram_cs_n,
    input                       dram_ras_n,
    input                       dram_cas_n,
    input                       dram_we_n,      // Write enable
    input[1:0]                  dram_ba,        // Bank select
    input[12:0]                 dram_addr,
    inout[DATA_WIDTH - 1:0]     dram_dq);

    localparam NUM_BANKS = 4;
    localparam MEM_SIZE = (1 << ROW_ADDR_WIDTH) * (1 << COL_ADDR_WIDTH) * NUM_BANKS;

    logic[9:0] mode_register_ff;
    logic[NUM_BANKS - 1:0] bank_active;
    logic[NUM_BANKS - 1:0] bank_cas_delay[0:3];
    logic[ROW_ADDR_WIDTH - 1:0] bank_active_row[0:NUM_BANKS - 1];
    logic[DATA_WIDTH - 1:0] sdram_data[0:MEM_SIZE - 1] /*verilator public*/;
    logic[15:0] refresh_delay;

    // Current burst info
    logic burst_w; // If true, is a write burst.  Otherwise, read burst
    logic burst_active;
    logic[3:0] burst_count_ff;    // How many transfers have occurred
    logic[1:0] burst_bank;
    logic burst_auto_precharge;
    logic[10:0] burst_column_address;
    logic[3:0] burst_read_delay_count;
    logic cke_ff;
    logic initialized;
    logic[3:0] burst_length;
    logic burst_interleaved;
    logic[COL_ADDR_WIDTH - 1:0] burst_address_offset;
    logic[$clog2(MEM_SIZE) - 1:0] burst_address;
    logic[DATA_WIDTH - 1:0] output_reg;
    logic[2:0] cas_delay;
    logic cmd_en;
    logic cmd_load_mode;
    logic cmd_auto_refresh;
    logic cmd_precharge;
    logic cmd_activate;
    logic cmd_write_burst;
    logic cmd_read_burst;

    initial
    begin
        for (int i = 0; i < NUM_BANKS; i++)
            bank_active_row[i] = 0;

        mode_register_ff = 0;
        bank_active = 0;
        refresh_delay = 0;
        burst_w = '0;
        burst_active = 0;
        burst_count_ff = 0;
        burst_bank = '0;
        burst_auto_precharge = '0;
        burst_column_address = '0;
        burst_read_delay_count = '0;
        cke_ff = 0;
        initialized = 0;
    end

    assign cas_delay = mode_register_ff[6:4];

    always_ff @(posedge dram_clk)
        cke_ff <= dram_cke;

    // Decode command
    assign cmd_en = cke_ff && !dram_cs_n;
    assign cmd_load_mode = cmd_en && !dram_ras_n && !dram_cas_n && !dram_we_n;
    assign cmd_auto_refresh = cmd_en && !dram_ras_n && !dram_cas_n && dram_we_n;
    assign cmd_precharge = cmd_en && !dram_ras_n && dram_cas_n && !dram_we_n;
    assign cmd_activate = cmd_en && !dram_ras_n && dram_cas_n && dram_we_n;
    assign cmd_write_burst = cmd_en && dram_ras_n && !dram_cas_n && !dram_we_n;
    assign cmd_read_burst = cmd_en && dram_ras_n && !dram_cas_n && dram_we_n;

    // Burst count
    always_ff @(posedge dram_clk)
    begin
        if (cmd_write_burst)
            burst_count_ff <= 1;    // Count the first transfer, which has already occurred
        else if (cmd_read_burst)
            burst_count_ff <= 0;
        else if (burst_active && cke_ff && (burst_w || burst_read_delay_count === 0))
            burst_count_ff <= burst_count_ff + 1;
    end

    // Bank active
    always @(posedge dram_clk) // fix for multiple drivers on bank_active: initial statement not compatible with always_ff according to SystemVerilog standard
    begin
        if (cmd_precharge)
        begin
            if (dram_addr[10])
            begin
`ifdef SDRAM_DEBUG
                $display("precharge all");
`endif
                bank_active <= 4'b0;        // precharge all rows
            end
            else
            begin
`ifdef SDRAM_DEBUG
                $display("precharge bank %d", dram_ba);
`endif
                bank_active[dram_ba] <= 1'b0;    // precharge
            end

            initialized <= 1;
        end
        else if (cmd_activate)
        begin
            // Check for attempt to activate bank that is already active
            assert(!bank_active[dram_ba]);

`ifdef SDRAM_DEBUG
            $display("bank %d activated row %d", dram_ba, dram_addr[ROW_ADDR_WIDTH - 1:0]);
`endif
            bank_active[dram_ba] <= 1'b1;
            bank_active_row[dram_ba] <= dram_addr[ROW_ADDR_WIDTH - 1:0];
        end
        else if (burst_count_ff == burst_length - 1 && burst_active && cke_ff
            && burst_auto_precharge)
            bank_active[burst_bank] <= 1'b0;    // Auto-precharge
    end

    // Mode register
    always_ff @(posedge dram_clk)
    begin
        if (cmd_load_mode)
        begin
`ifdef SDRAM_DEBUG
            $display("latching mode %x", dram_addr[9:0]);
`endif
            mode_register_ff <= dram_addr[9:0];
        end
    end

    // Burst read delay count
    always_ff @(posedge dram_clk)
    begin
        if (cmd_read_burst)
            burst_read_delay_count <= cas_delay - 1; // Note: there is one extra cycle of latency in read
        else if (burst_active && cke_ff && ~burst_w)
        begin
            if (burst_read_delay_count > 0)
                burst_read_delay_count <= burst_read_delay_count - 1;
        end
    end

    // Burst active
    always_ff @(posedge dram_clk)
    begin
        if (cmd_write_burst || cmd_read_burst)
            burst_active <= 1'b1;
        else if (burst_count_ff >= burst_length - 1 && burst_active)
            burst_active <= 1'b0; // Burst is complete
    end

    always_ff @(posedge dram_clk)
    begin
        if (cmd_write_burst || cmd_read_burst)
        begin
            // Bank must be active to start burst
            assert(bank_active[dram_ba]);

            // Ensure CAS latency is respected.
            assert(bank_cas_delay[dram_ba] == 0);

`ifdef SDRAM_DEBUG
            $display("start %s transfer bank %d row %d column %d",
                cmd_write_burst ? "write" : "read", dram_ba,
                bank_active_row[dram_ba], dram_addr[COL_ADDR_WIDTH - 1:0]);
`endif
            burst_w <= cmd_write_burst;
            burst_bank <= dram_ba;
            burst_auto_precharge <= dram_addr[10];
            burst_column_address <= $size(burst_column_address)'(dram_addr[COL_ADDR_WIDTH - 1:0]);
        end
        else if (cmd_auto_refresh)
        begin
            // Do not auto refresh with open rows
            assert(bank_active == 0);
`ifdef SDRAM_DEBUG
            $display("auto refresh");
`endif
        end
    end

    // Check that we're being refreshed frequently enough
    always_ff @(posedge dram_clk)
    begin
        // Fail if not refreshed
        assert(refresh_delay < MAX_REFRESH_INTERVAL);
        if (cmd_auto_refresh)
            refresh_delay <= 0;
        else if (initialized)
            refresh_delay <= refresh_delay + 1;
    end


    // RAM write
    always @(posedge dram_clk) // fix for multiple drivers on sdram_data -- other driver is in soc_tb
    begin
        if (burst_active && cke_ff && burst_w)
            sdram_data[burst_address] <= dram_dq;    // Write
        else if (cmd_write_burst)
            sdram_data[{bank_active_row[dram_ba], dram_ba, dram_addr[COL_ADDR_WIDTH - 1:0]}] <= dram_dq;    // Latch first word

`ifndef VERILATOR
        // Check if data is still high-z. This doesn't work on verilator, because
        // it doesn't support Z or X.
        if ((burst_active && cke_ff && burst_w) || cmd_write_burst)
        begin
            if ((dram_dq ^ dram_dq) !== 0)
            begin
                // Z or X value.
                $display("%m: write value is %d", dram_dq);
                $finish;
            end
        end
`endif

`ifdef SDRAM_DEBUG
    if ((burst_active && cke_ff && burst_w) || cmd_write_burst)
        $display(" write %08x", dram_dq);
    else if (burst_active && !burst_w && !cmd_write_burst)
        $display(" read %08x", dram_dq);
`endif
    end

    // RAM read
    assign output_reg = sdram_data[burst_address];
    assign dram_dq = (burst_w || cmd_write_burst) ? {DATA_WIDTH{1'hZ}} : output_reg;

    // Make sure client is respecting CAS latency.
    always_ff @(posedge dram_clk)
    begin
        if (cmd_activate)
            bank_cas_delay[dram_ba] <= cas_delay - 2;

        for (int bank = 0; bank < NUM_BANKS; bank++)
        begin
            if (bank_cas_delay[bank] > 0 && (dram_ba != $clog2(NUM_BANKS)'(bank) || ~cmd_activate))
                bank_cas_delay[bank] <= bank_cas_delay[bank] - 1;
        end
    end

    //
    // Burst count logic
    //
    assign burst_length = 1 << mode_register_ff[2:0];
    assign burst_interleaved = mode_register_ff[3];
    assign burst_address_offset = burst_interleaved
        ? COL_ADDR_WIDTH'(burst_column_address) ^ COL_ADDR_WIDTH'(burst_count_ff)
        : COL_ADDR_WIDTH'(burst_column_address) + COL_ADDR_WIDTH'(burst_count_ff);
    assign burst_address = {bank_active_row[burst_bank], burst_bank, burst_address_offset};
endmodule
