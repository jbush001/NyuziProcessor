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
// Drives control signals for single data rate (SDR) SDRAM, including
// auto refresh at appropriate intervals. An AXI bus interface initiates
// reads and writes.
// For performance, this lazily keeps rows open after accesses, tracking them
// independently for each bank and closing them only when necessary.
//

module sdram_controller
    #(parameter DATA_WIDTH = 32,
    parameter ROW_ADDR_WIDTH = 12, // 4096 rows
    parameter COL_ADDR_WIDTH = 8, // 256 columns

    // These are expressed in numbers of clocks. Each one is the number
    // of clocks of delay minus one. Compute this by dividing timing
    // specification for the part by the clock interval.
    parameter T_POWERUP = 10000,
    parameter T_ROW_PRECHARGE = 1,
    parameter T_AUTO_REFRESH_CYCLE = 3,
    parameter T_RAS_CAS_DELAY = 1,
    parameter T_REFRESH = 750,
    parameter T_CAS_LATENCY = 1)

    (input                                  clk,
    input                                   reset,

    // Interface to SDRAM
    output logic                            dram_clk,
    output logic                            dram_cke,
    output logic                            dram_cs_n,
    output logic                            dram_ras_n,
    output logic                            dram_cas_n,
    output logic                            dram_we_n,
    output logic[1:0]                       dram_ba,
    output logic[12:0]                      dram_addr,
    inout [DATA_WIDTH - 1:0]                dram_dq,

    // Interface to bus
    axi4_interface.slave                    axi_bus,

    // Performance counter events
    output logic                            perf_dram_page_miss,
    output logic                            perf_dram_page_hit);

    localparam SDRAM_BURST_LENGTH = 8;
    localparam SDRAM_BURST_IDX_WIDTH = $clog2(SDRAM_BURST_LENGTH);
    localparam NUM_BANKS = 4;
    localparam MEMORY_SIZE = (1 << (ROW_ADDR_WIDTH + COL_ADDR_WIDTH)) * NUM_BANKS
        * (DATA_WIDTH / 8);
    localparam INTERNAL_ADDR_WIDTH = ROW_ADDR_WIDTH + COL_ADDR_WIDTH + $clog2(NUM_BANKS);
    localparam SDRAM_ADDR_WIDTH = $size(dram_addr);

    typedef enum {
        STATE_INIT0,
        STATE_INIT1,
        STATE_INIT2,
        STATE_INIT3,
        STATE_IDLE,
        STATE_AUTO_REFRESH0,
        STATE_AUTO_REFRESH1,
        STATE_OPEN_ROW,
        STATE_READ_BURST,
        STATE_WRITE_BURST,
        STATE_CAS_WAIT,
        STATE_POWERUP,
        STATE_CLOSE_ROW
    } burst_state_t;

    typedef enum logic[3:0] {
        CMD_MODE_REGISTER_SET = 4'b0000,
        CMD_AUTO_REFRESH      = 4'b0001,
        CMD_PRECHARGE         = 4'b0010,
        CMD_ACTIVATE          = 4'b0011,
        CMD_WRITE             = 4'b0100,
        CMD_READ              = 4'b0101,
        CMD_NOP               = 4'b1000
    } sdram_cmd_t;

    localparam TIMER_WIDTH = 15;

    // latched addresses and lengths are in terms of DATA_WIDTH transfers, not bytes.
    logic[TIMER_WIDTH - 1:0] refresh_timer_ff;
    logic[TIMER_WIDTH - 1:0] refresh_timer_nxt;
    logic[TIMER_WIDTH - 1:0] timer_ff;
    logic[TIMER_WIDTH - 1:0] timer_nxt;
    sdram_cmd_t command;
    burst_state_t state_ff;
    burst_state_t state_nxt;
    logic[SDRAM_BURST_IDX_WIDTH - 1:0] burst_offset_ff;
    logic[SDRAM_BURST_IDX_WIDTH - 1:0] burst_offset_nxt;
    logic[ROW_ADDR_WIDTH - 1:0] active_row[NUM_BANKS];
    logic bank_active[NUM_BANKS];
    logic output_enable;
    logic[DATA_WIDTH - 1:0] write_data;
    logic[INTERNAL_ADDR_WIDTH - 1:0] write_address;
    logic[7:0] write_length; // Like axi_bus.m_awlen, is num transfers - 1
    logic write_pending;
    logic[INTERNAL_ADDR_WIDTH - 1:0] read_address;
    logic[7:0] read_length;    // Like axi_bus.m_arlen, is num_transfers - 1
    logic read_pending;
    logic lfifo_empty;
    logic sfifo_full;
    logic[$clog2(NUM_BANKS) - 1:0] write_bank;
    logic[COL_ADDR_WIDTH - 1:0] write_column;
    logic[ROW_ADDR_WIDTH - 1:0] write_row;
    logic[$clog2(NUM_BANKS) - 1:0] read_bank;
    logic[COL_ADDR_WIDTH - 1:0] read_column;
    logic[ROW_ADDR_WIDTH - 1:0] read_row;
    logic lfifo_enqueue;
    logic access_is_read_ff;
    logic access_is_read_nxt;

    assign axi_bus.s_arready = !read_pending;
    assign axi_bus.s_awready = !write_pending;
    assign axi_bus.s_rvalid = !lfifo_empty;
    assign axi_bus.s_wready = !sfifo_full;
    assign axi_bus.s_bvalid = !reset;    // Hack: pretend we always have a write result

    // Each fifo can hold an entire SDRAM burst to avoid delays due
    // to the external bus.

    sync_fifo #(.WIDTH(DATA_WIDTH), .SIZE(SDRAM_BURST_LENGTH)) load_fifo(
        .clk(clk),
        .reset(reset),
        .flush_en(1'b0),
        .full(),
        .almost_empty(),
        .almost_full(),
        .empty(lfifo_empty),
        .enqueue_value(dram_dq),
        .enqueue_en(lfifo_enqueue),
        .dequeue_en(axi_bus.m_rready && axi_bus.s_rvalid),
        .dequeue_value(axi_bus.s_rdata));

    sync_fifo #(.WIDTH(DATA_WIDTH), .SIZE(SDRAM_BURST_LENGTH)) store_fifo(
        .clk(clk),
        .reset(reset),
        .flush_en(1'b0),
        .full(sfifo_full),
        .almost_empty(),
        .almost_full(),
        .dequeue_value(write_data),
        .dequeue_en(output_enable),
        .enqueue_value(axi_bus.m_wdata),
        .enqueue_en(axi_bus.s_wready && axi_bus.m_wvalid),
        .empty());

    assign {dram_cs_n, dram_ras_n, dram_cas_n, dram_we_n} = command;
    assign dram_cke = 1;
    assign dram_clk = clk;
    assign {write_row, write_bank, write_column} = write_address;
    assign {read_row, read_bank, read_column} = read_address;

    assign dram_dq = output_enable ? write_data : {DATA_WIDTH{1'hZ}};

    initial
    begin
        // Currently a requirement because narrowing or expanding isn't implemented.
        assert(`AXI_DATA_WIDTH == DATA_WIDTH);
    end

    // Next state logic. When there is a delay between states, timer_ff tracks
    // how many cycles are remaining. state_ff will point to the *next* state
    // during this interval, but the  control signals associated with the state
    // (in the case below) won't be asserted until the timer counts down to zero.
    always_comb
    begin
        // Default values
        output_enable = 0;
        command = CMD_NOP;
        timer_nxt = TIMER_WIDTH'(0);
        burst_offset_nxt = 0;
        state_nxt = state_ff;
        dram_ba = 0;
        dram_addr = 0;
        perf_dram_page_miss = 0;
        perf_dram_page_hit = 0;
        access_is_read_nxt = access_is_read_ff;

        lfifo_enqueue = 0;
        if (refresh_timer_ff != 0)
            refresh_timer_nxt = refresh_timer_ff - TIMER_WIDTH'(1);
        else
            refresh_timer_nxt = TIMER_WIDTH'(0);

        if (timer_ff != 0)
            timer_nxt = timer_ff - TIMER_WIDTH'(1); // Wait for timer to expire
        else
        begin
            // Progress to next state.
            unique case (state_ff)
                STATE_POWERUP:
                begin
                    timer_nxt = TIMER_WIDTH'(T_POWERUP);    // Wait for clock to be stable
                    state_nxt = STATE_INIT0;
                end

                STATE_INIT0:
                begin
                    // Step 1: send precharge all command
                    dram_addr = {SDRAM_ADDR_WIDTH{1'b1}};
                    command = CMD_PRECHARGE;
                    timer_nxt = TIMER_WIDTH'(T_ROW_PRECHARGE);
                    state_nxt = STATE_INIT1;
                end

                STATE_INIT1:
                begin
                    // Step 2: send two auto refresh commands
                    dram_addr = {SDRAM_ADDR_WIDTH{1'b1}};
                    command = CMD_AUTO_REFRESH;
                    timer_nxt = TIMER_WIDTH'(T_AUTO_REFRESH_CYCLE);
                    state_nxt = STATE_INIT2;
                end

                STATE_INIT2:
                begin
                    dram_addr = {SDRAM_ADDR_WIDTH{1'b1}};
                    command = CMD_AUTO_REFRESH;
                    timer_nxt = TIMER_WIDTH'(T_AUTO_REFRESH_CYCLE);
                    state_nxt = STATE_INIT3;
                end

                STATE_INIT3:
                begin
                    // Step 3: set the mode register
                    // CAS latency is hardcoded to 2 clocks
                    command = CMD_MODE_REGISTER_SET;
                    dram_addr = SDRAM_ADDR_WIDTH'('b000_0_00_010_0_011);
                    dram_ba = 2'b00;
                    state_nxt = STATE_IDLE;
                end

                STATE_IDLE:
                begin
                    if (refresh_timer_ff == 0)
                    begin
                        // Need to perform an auto-refresh cycle.  If any rows are open,
                        // precharge all of them now.  Otherwise proceed directly to
                        // refresh.
                        if (bank_active[0] | bank_active[1] | bank_active[2] | bank_active[3])
                            state_nxt = STATE_AUTO_REFRESH0;
                        else
                            state_nxt = STATE_AUTO_REFRESH1;
                    end
                    else if (lfifo_empty && read_pending
                        && (!write_pending || write_address != read_address))
                    begin
                        // Start a read burst. Reads have priority to avoid starving
                        // the VGA controller, but we check above to ensure there isn't
                        // a write already pending for this address (otherwise we will
                        // get stale data).
                        access_is_read_nxt = 1;
                        if (!bank_active[read_bank])
                        begin
                            // Row is not open in this bank, need to pen it.
                            perf_dram_page_miss = 1;
                            state_nxt = STATE_OPEN_ROW;
                        end
                        else if (read_row != active_row[read_bank])
                        begin
                            // Different row is already open in this bank, close it first.
                            perf_dram_page_miss = 1;
                            state_nxt = STATE_CLOSE_ROW;
                        end
                        else
                        begin
                            perf_dram_page_hit = 1;
                            state_nxt = STATE_CAS_WAIT;
                        end
                    end
                    else if (write_pending && sfifo_full
                        && (!read_pending || write_address == read_address))
                    begin
                        // Start a write burst.
                        // Don't start the burst if a read is pending and the FIFO is full.
                        // This is a hack to avoid starving the VGA controller.  However, do
                        // start the write if the read is for data we are about to write
                        // (write_address == read_address above), which avoids a nasty race
                        // condition that corrrupts data.
                        access_is_read_nxt = 0;
                        if (!bank_active[write_bank])
                        begin
                            // Row is not open, do that
                            perf_dram_page_miss = 1;
                            state_nxt = STATE_OPEN_ROW;
                        end
                        else if (write_row != active_row[write_bank])
                        begin
                            // Different row open in this bank, close
                            perf_dram_page_miss = 1;
                            state_nxt = STATE_CLOSE_ROW;
                        end
                        else
                        begin
                            perf_dram_page_hit = 1;
                            state_nxt = STATE_WRITE_BURST;
                        end
                    end
                end

                STATE_CLOSE_ROW:
                begin
                    // Precharge a single bank that has an open row in preparation
                    // for a transfer.
                    dram_addr =  {SDRAM_ADDR_WIDTH{1'b0}};
                    if (access_is_read_ff)
                        dram_ba = read_bank;
                    else
                        dram_ba = write_bank;

                    command = CMD_PRECHARGE;
                    timer_nxt = TIMER_WIDTH'(T_ROW_PRECHARGE);
                    state_nxt = STATE_OPEN_ROW;
                end

                STATE_OPEN_ROW:
                begin
                    if (access_is_read_ff)
                    begin
                        dram_ba = read_bank;
                        dram_addr = SDRAM_ADDR_WIDTH'(read_row);
                        state_nxt = STATE_CAS_WAIT;
                    end
                    else
                    begin
                        dram_ba = write_bank;
                        dram_addr = SDRAM_ADDR_WIDTH'(write_row);
                        state_nxt = STATE_WRITE_BURST;
                    end
                    command = CMD_ACTIVATE;
                    timer_nxt = TIMER_WIDTH'(T_RAS_CAS_DELAY);
                end

                STATE_CAS_WAIT:
                begin
                    command = CMD_READ;
                    dram_addr = SDRAM_ADDR_WIDTH'(read_column);
                    dram_ba = read_bank;
                    timer_nxt = TIMER_WIDTH'(T_CAS_LATENCY);
                    state_nxt = STATE_READ_BURST;
                end

                STATE_READ_BURST:
                begin
                    lfifo_enqueue = 1;
                    burst_offset_nxt = burst_offset_ff + SDRAM_BURST_IDX_WIDTH'(1);
                    if (burst_offset_ff == SDRAM_BURST_IDX_WIDTH'(SDRAM_BURST_LENGTH - 1))
                        state_nxt = STATE_IDLE;
                end

                STATE_WRITE_BURST:
                begin
                    output_enable = 1;
                    if (burst_offset_ff == 0)
                    begin
                        // On first cycle
                        dram_ba = write_bank;
                        dram_addr = SDRAM_ADDR_WIDTH'(write_column);
                        command = CMD_WRITE;
                    end

                    burst_offset_nxt = burst_offset_ff + SDRAM_BURST_IDX_WIDTH'(1);
                    if (burst_offset_ff == SDRAM_BURST_IDX_WIDTH'(SDRAM_BURST_LENGTH - 1))
                        state_nxt = STATE_IDLE;
                end

                STATE_AUTO_REFRESH0:
                begin
                    // Precharge all banks before auto-refresh
                    dram_addr = SDRAM_ADDR_WIDTH'('b0010000000000);    // XXX parameterize
                    command = CMD_PRECHARGE;
                    timer_nxt = TIMER_WIDTH'(T_ROW_PRECHARGE);
                    state_nxt = STATE_AUTO_REFRESH1;
                end

                STATE_AUTO_REFRESH1:
                begin
                    command = CMD_AUTO_REFRESH;
                    timer_nxt = TIMER_WIDTH'(T_AUTO_REFRESH_CYCLE);
                    refresh_timer_nxt = TIMER_WIDTH'(T_REFRESH);
                    state_nxt = STATE_IDLE;
                end

                default:
                    state_nxt = STATE_IDLE;
            endcase
        end
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin : doreset
            for (int i = 0; i < NUM_BANKS; i++)
            begin
                active_row[i] <= 0;
                bank_active[i] <= 0;
            end

            state_ff <= STATE_INIT0;
            refresh_timer_ff <= TIMER_WIDTH'(T_REFRESH);

            access_is_read_ff <= '0;
            burst_offset_ff <= '0;
            read_address <= '0;
            read_length <= '0;
            read_pending <= '0;
            timer_ff <= '0;
            write_address <= '0;
            write_length <= '0;
            write_pending <= '0;
        end
        else
        begin
            //
            // SDRAM control
            //
            state_ff <= state_nxt;
            timer_ff <= timer_nxt;
            burst_offset_ff <= burst_offset_nxt;
            refresh_timer_ff <= refresh_timer_nxt;
            access_is_read_ff <= access_is_read_nxt;
            if (state_ff == STATE_OPEN_ROW)
            begin
                if (access_is_read_ff)
                begin
                    active_row[read_bank] <= read_row;
                    bank_active[read_bank] <= 1;
                end
                else
                begin
                    active_row[write_bank] <= write_row;
                    bank_active[write_bank] <= 1;
                end
            end
            else if (state_ff == STATE_AUTO_REFRESH0)
            begin
                // The precharge all command will close all active banks
                for (int i = 0; i < NUM_BANKS; i++)
                    bank_active[i] <= 0;
            end

            //
            // AXI Bus Interface
            //
            if (write_pending && state_ff == STATE_WRITE_BURST &&
                state_nxt != STATE_WRITE_BURST)
            begin
                // The bus transfer may be longer than the SDRAM burst.
                // Determine if we are done yet.
                write_length <= write_length - 8'(SDRAM_BURST_LENGTH);
                write_address <= write_address + INTERNAL_ADDR_WIDTH'(SDRAM_BURST_LENGTH);
                if (write_length == SDRAM_BURST_LENGTH - 1)
                    write_pending <= 0;
            end
            else if (axi_bus.m_awvalid && !write_pending)
            begin
                // Start a write burst

                // Ensure the the burst is aligned on an SDRAM burst boundary.
                assert(((axi_bus.m_awlen + 1) & (SDRAM_BURST_LENGTH - 1)) == 0);
                assert((axi_bus.m_awaddr & (SDRAM_BURST_LENGTH - 1)) == 0);

`ifdef SIMULATION
                // Make sure memory address is in memory range
                if (axi_bus.m_awaddr >= MEMORY_SIZE)
                begin
                    $display("sdram: write address out of range %x", axi_bus.m_awaddr);
                    $finish;
                end
`endif

                // axi_bus.m_awaddr is in terms of bytes.  Convert to # of transfers.
                write_address <= INTERNAL_ADDR_WIDTH'(axi_bus.m_awaddr[AXI_ADDR_WIDTH - 1:$clog2(DATA_WIDTH / 8)]);
                write_length <= axi_bus.m_awlen;
                write_pending <= 1'b1;
            end

            if (read_pending && state_ff == STATE_READ_BURST &&
                state_nxt != STATE_READ_BURST)
            begin
                read_length <= read_length - 8'(SDRAM_BURST_LENGTH);
                read_address <= read_address + INTERNAL_ADDR_WIDTH'(SDRAM_BURST_LENGTH);
                if (read_length == SDRAM_BURST_LENGTH - 1)
                    read_pending <= 0;
            end
            else if (axi_bus.m_arvalid && !read_pending)
            begin
                // Start a read burst

                // Ensure the the burst is aligned on an SDRAM burst boundary.
                assert(((axi_bus.m_arlen + 1) & (SDRAM_BURST_LENGTH - 1)) == 0);
                assert((axi_bus.m_araddr & (SDRAM_BURST_LENGTH - 1)) == 0);

`ifdef SIMULATION
                // Make sure memory address is in memory range
                if (axi_bus.m_araddr >= MEMORY_SIZE)
                begin
                    $display("sdram: read address out of range %x", axi_bus.m_araddr);
                    $finish;
                end
`endif

                // axi_bus.m_araddr is in terms of bytes.  Convert to # of transfers.
                read_address <= INTERNAL_ADDR_WIDTH'(axi_bus.m_araddr[AXI_ADDR_WIDTH - 1:$clog2(DATA_WIDTH / 8)]);
                read_length <= axi_bus.m_arlen;
                read_pending <= 1'b1;
            end
        end
    end
endmodule
