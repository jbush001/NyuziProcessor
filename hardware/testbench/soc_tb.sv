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
// Top module for simulating a system on chip, which includes the Nyuzi
// core and peripherals like an SDRAM controller, virtual MMC storage
// device, etc.
//

module soc_tb(
    input       clk,
    input       reset);

    localparam MEM_SIZE = 'h1000000;
    localparam NUM_PERIPHERALS = 6;

    int total_cycles;
    string filename;
    bit state_dump_en;
    int state_dump_fd;
    int finish_cycles;
    bit profile_en;
    int profile_fd;
    axi4_interface axi_bus_s[1:0]();
    axi4_interface axi_bus_m[1:0]();
    scalar_t loopback_uart_read_data;
    logic loopback_uart_tx;
    logic loopback_uart_rx;
    logic loopback_uart_mask;
    logic sd_cs_n;
    logic sd_di;
    logic sd_sclk;
    io_bus_interface peripheral_io_bus[NUM_PERIPHERALS - 1:0]();
    io_bus_interface nyuzi_io_bus();
    jtag_interface host_jtag();
    jtag_interface target_jtag();
    logic data_shift_val;
    scalar_t peripheral_read_data[NUM_PERIPHERALS];
`ifdef VCS
    enum logic[$clog2(NUM_PERIPHERALS) - 1:0] {
        IO_ONES = 0,
        IO_LOOPBACK_UART = 1,
        IO_PS2 = 2,
        IO_SDCARD = 3,
        IO_TIMER = 4,
        IO_VGA = 5
    } io_bus_source;
`else
    enum logic[$clog2(NUM_PERIPHERALS) - 1:0] {
        IO_ONES,
        IO_LOOPBACK_UART,
        IO_PS2,
        IO_SDCARD,
        IO_TIMER,
        IO_VGA
    } io_bus_source;

`endif // !`ifdef VCS
    int cosim_timer_interval;
    int cosim_interrupt_delay;
    logic cosim_interrupt;
    logic uart_rx_interrupt;
    logic ps2_rx_interrupt;

    localparam SDRAM_DATA_WIDTH = 32; // declare before use
    wire [SDRAM_DATA_WIDTH-1:0] dram_dq; // inout fix: change from logic to wire to comply with commercial simulator and SystemVerilog standard
    logic processor_halt;

    /* verilator lint_off UNDRIVEN */
    logic frame_interrupt;
    /* verilator lint_on UNDRIVEN */

    /*AUTOLOGIC*/
    // Beginning of automatic wires (for undeclared instantiated-module outputs)
    logic [12:0]        dram_addr;              // From sdram_controller of sdram_controller.v
    logic [1:0]         dram_ba;                // From sdram_controller of sdram_controller.v
    logic               dram_cas_n;             // From sdram_controller of sdram_controller.v
    logic               dram_cke;               // From sdram_controller of sdram_controller.v
    logic               dram_clk;               // From sdram_controller of sdram_controller.v
    logic               dram_cs_n;              // From sdram_controller of sdram_controller.v
    logic               dram_ras_n;             // From sdram_controller of sdram_controller.v
    logic               dram_we_n;              // From sdram_controller of sdram_controller.v
    logic               perf_dram_page_hit;     // From sdram_controller of sdram_controller.v
    logic               perf_dram_page_miss;    // From sdram_controller of sdram_controller.v
    logic               ps2_clk;                // From sim_ps2 of sim_ps2.v
    logic               ps2_data;               // From sim_ps2 of sim_ps2.v
    logic               sd_do;                  // From sim_sdmmc of sim_sdmmc.v
    logic               timer_interrupt;        // From timer of timer.v
    logic [7:0]         vga_b;                  // From vga_controller of vga_controller.v
    logic               vga_blank_n;            // From vga_controller of vga_controller.v
    logic               vga_clk;                // From vga_controller of vga_controller.v
    logic [7:0]         vga_g;                  // From vga_controller of vga_controller.v
    logic               vga_hs;                 // From vga_controller of vga_controller.v
    logic [7:0]         vga_r;                  // From vga_controller of vga_controller.v
    logic               vga_sync_n;             // From vga_controller of vga_controller.v
    logic               vga_vs;                 // From vga_controller of vga_controller.v
    // End of automatics

    `define CORE0 nyuzi.core_gen[0].core

`ifdef SIMULATE_BOOT_ROM
    // This will simulate with the boot ROM to test that it is generating
    // the proper memory transactions, but the bootrom doesn't work correctly
    // in the simulation environment, so it won't do anything else.
    localparam RESET_PC = 32'hfffee000;

    axi_rom #(.FILENAME("../software/bootrom/boot.hex")) boot_rom(
        .axi_bus(axi_bus_s[1]),
        .clk(clk),
        .reset(reset));
`else
    localparam RESET_PC = 32'h00000000;

    assign axi_bus_s[1].s_wready = 0;
    assign axi_bus_s[1].s_arready = 0;
    assign axi_bus_s[1].s_rvalid = 0;
`endif

    nyuzi #(.RESET_PC(RESET_PC)) nyuzi(
        .axi_bus(axi_bus_m[0]),
        .io_bus(nyuzi_io_bus),
        .interrupt_req({11'd0,
            frame_interrupt,
            ps2_rx_interrupt,
            uart_rx_interrupt,
            timer_interrupt,
            cosim_interrupt}),
        .jtag(target_jtag),
        .*);

    assign processor_halt = nyuzi.thread_en == '0;

    axi_protocol_checker axi_protocol_checker(
        .axi_bus(axi_bus_m[0]));

    //
    // AXI buses/memory subsystem
    //

    axi_interconnect axi_interconnect(
        .axi_bus_s(axi_bus_s),
        .axi_bus_m(axi_bus_m),
        .*);

    localparam SDRAM_NUM_BANKS = 4;
    localparam SDRAM_ROW_ADDR_WIDTH = 12;
    localparam SDRAM_COL_ADDR_WIDTH = $clog2(MEM_SIZE / ((1 << SDRAM_ROW_ADDR_WIDTH)
        * SDRAM_NUM_BANKS * (SDRAM_DATA_WIDTH / 8)));

    sdram_controller #(
        .DATA_WIDTH(SDRAM_DATA_WIDTH),
        .ROW_ADDR_WIDTH(SDRAM_ROW_ADDR_WIDTH),
        .COL_ADDR_WIDTH(SDRAM_COL_ADDR_WIDTH),
        .T_REFRESH(750),
        .T_POWERUP(5)
    ) sdram_controller(
        .axi_bus(axi_bus_s[0]),
        .*);

    sim_sdram #(
        .DATA_WIDTH(SDRAM_DATA_WIDTH),
        .ROW_ADDR_WIDTH(SDRAM_ROW_ADDR_WIDTH),
        .COL_ADDR_WIDTH(SDRAM_COL_ADDR_WIDTH),
        .MAX_REFRESH_INTERVAL(800)
    ) memory(.*);

    //
    // Peripherals
    //

    assign loopback_uart_rx = loopback_uart_tx & loopback_uart_mask;
    uart #(.BASE_ADDRESS('h140)) loopback_uart(
        .io_bus(peripheral_io_bus[IO_LOOPBACK_UART]),
        .rx_interrupt(uart_rx_interrupt),
        .uart_tx(loopback_uart_tx),
        .uart_rx(loopback_uart_rx),
        .*);

    sim_sdmmc sim_sdmmc(.*);

    spi_controller #(.BASE_ADDRESS('hc0)) spi_controller(
        .io_bus(peripheral_io_bus[IO_SDCARD]),
        .spi_clk(sd_sclk),
        .spi_cs_n(sd_cs_n),
        .spi_miso(sd_do),
        .spi_mosi(sd_di),
        .*);

    sim_ps2 sim_ps2(.*);

    ps2_controller #(.BASE_ADDRESS('h80)) ps2_controller(
        .io_bus(peripheral_io_bus[IO_PS2]),
        .rx_interrupt(ps2_rx_interrupt),
        .*);

    timer #(.BASE_ADDRESS('h240)) timer(
        .io_bus(peripheral_io_bus[IO_TIMER]),
        .*);

`ifdef VERILATOR
    sim_jtag sim_jtag(
        .jtag(host_jtag),
        .*);

    assign host_jtag.tdi = target_jtag.tdo;
    assign target_jtag.tdi = host_jtag.tdo;
    assign target_jtag.tck = host_jtag.tck;
    assign target_jtag.trst_n = host_jtag.trst_n;
    assign target_jtag.tms = host_jtag.tms;
`else
    target_jtag.tdi = 0;
    target_jtag.tck = 0;
    target_jtag.trst = 0;
    target_jtag.tms = 0;
`endif

`ifdef SIMULATE_VGA
   // There is no automated test for VGA currently, so I test as follows:
   // - Modify the makefile to add --trace-depth 1 to VERILATOR_OPTIONS
   // - Rebuild hardware: DUMP_WAVEFORM=1 make
   // - Run one of the apps (like mandelbrot) for maybe 20 seconds, ctrl-C to stop
   // - Look the resulting waveform in GtkWave to check that the timings are correct.
   vga_controller #(.BASE_ADDRESS('h180))
   vga_controller(
                  .io_bus(peripheral_io_bus[IO_VGA]),
                  .axi_bus(axi_bus_m[1]),
                  .*);
`else // !`ifdef SIMULATE_VGA
    // The s1 interface is not connected to anything in this configuration.
    assign axi_bus_m[1].m_awvalid = 0;
    assign axi_bus_m[1].m_wvalid = 0;
    assign axi_bus_m[1].m_arvalid = 0;
    assign axi_bus_m[1].m_rready = 0;
    assign axi_bus_m[1].m_bready = 0;
`endif // !`ifdef SIMULATE_VGA

    assign peripheral_io_bus[IO_ONES].read_data = 32'hffffffff;

    assign nyuzi_io_bus.read_data = peripheral_read_data[io_bus_source];

    genvar io_idx;
    generate
        for (io_idx = 0; io_idx < NUM_PERIPHERALS; io_idx++)
        begin : io_gen
            assign peripheral_io_bus[io_idx].write_en = nyuzi_io_bus.write_en;
            assign peripheral_io_bus[io_idx].read_en = nyuzi_io_bus.read_en;
            assign peripheral_io_bus[io_idx].address = nyuzi_io_bus.address;
            assign peripheral_io_bus[io_idx].write_data = nyuzi_io_bus.write_data;
            assign peripheral_read_data[io_idx] = peripheral_io_bus[io_idx].read_data;
        end
    endgenerate

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            cosim_interrupt_delay <= 0;
            cosim_interrupt <= 0;
        end
        else if (cosim_interrupt_delay == 0)
        begin
            cosim_interrupt_delay <= cosim_timer_interval;
            cosim_interrupt <= 1;
        end
        else
        begin
            cosim_interrupt_delay <= cosim_interrupt_delay - 1;
            cosim_interrupt <= 0;
        end
    end

    // Device registers
    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            loopback_uart_mask <= 1;
            cosim_timer_interval <= 1000;
        end
        else
        begin
            if (nyuzi_io_bus.write_en)
            begin
                case (nyuzi_io_bus.address)
                    // Serial output
                    'h48:
                    begin
                        $write("%c", nyuzi_io_bus.write_data[7:0]);
                        $fflush(1);
                    end

                    // Loopback UART: force framing error
                    'h1c: loopback_uart_mask <= nyuzi_io_bus.write_data[0];

                    // Set timer interval
                    'h20: cosim_timer_interval <= nyuzi_io_bus.write_data;
                endcase
            end

            if (nyuzi_io_bus.read_en)
            begin
                casez (nyuzi_io_bus.address[15:0])
                    // Hack for cosimulation tests
                    'h04,
                    'h08,
                    'h40: // Serial status
                        io_bus_source <= IO_ONES;

                    // PS2
                    'h8?: io_bus_source <= IO_PS2;

                    // SPI (SD card)
                    'hc?: io_bus_source <= IO_SDCARD;

                    // Loopback UART
                    'h14?: io_bus_source <= IO_LOOPBACK_UART;

                    default: io_bus_source <= IO_ONES;  // XXX Might want random source
                endcase
            end
        end
    end

    trace_logger trace_logger(
        .wb_writeback_en(`CORE0.wb_writeback_en),
        .wb_writeback_vector(`CORE0.wb_writeback_vector),
        .wb_writeback_reg(`CORE0.wb_writeback_reg),
        .wb_writeback_value(`CORE0.wb_writeback_value),
        .wb_writeback_mask(`CORE0.wb_writeback_mask),
        .wb_writeback_thread_idx(`CORE0.wb_writeback_thread_idx),
        .wb_rollback_thread_idx(`CORE0.wb_rollback_thread_idx),
        .fx5_instruction_pc(`CORE0.fx5_instruction.pc),
        .ix_instruction_valid(`CORE0.ix_instruction_valid),
        .ix_instruction_pc(`CORE0.ix_instruction.pc),
        .ix_instruction_has_trap(`CORE0.ix_instruction.has_trap),
        .ix_instruction_trap_cause(`CORE0.ix_instruction.trap_cause),
        .dd_instruction_valid(`CORE0.dd_instruction_valid),
        .dd_instruction_pc(`CORE0.dd_instruction.pc),
        .dd_store_en(`CORE0.dd_store_en),
        .dd_store_mask(`CORE0.dd_store_mask),
        .dd_store_data(`CORE0.dd_store_data),
        .dd_instruction_memory_access_type(`CORE0.dd_instruction.memory_access_type),
        .dd_instruction_load(`CORE0.dd_instruction.load),
        .dt_instruction_pc(`CORE0.dt_instruction.pc),
        .dt_thread_idx(`CORE0.dt_thread_idx),
        .dt_request_virt_addr(`CORE0.dt_request_vaddr),
        .sq_rollback_en(`CORE0.sq_rollback_en),
        .sq_store_sync_success(`CORE0.sq_store_sync_success),
        .wb_trap_pc(`CORE0.wb_trap_pc),
        .*);

    task flush_l2_line;
        input l2_tag_t tag;
        input l2_set_idx_t set;
        input l2_way_idx_t way;
    begin
        for (int line_offset = 0; line_offset < CACHE_LINE_WORDS; line_offset++)
        begin
            memory.sdram_data[(int'(tag) * `L2_SETS + int'(set)) * CACHE_LINE_WORDS + line_offset] =
                int'(nyuzi.l2_cache.l2_cache_read_stage.sram_l2_data.data[{way, set}]
                 >> ((CACHE_LINE_WORDS - 1 - line_offset) * 32));
        end
    end
    endtask

    // Manually copy lines from the L2 cache back to memory so we can
    // validate it there.
    `define L2_TAG_WAY nyuzi.l2_cache.l2_cache_tag_stage.way_tags_gen

    task flush_l2_cache;
    begin
        for (int set = 0; set < `L2_SETS; set++)
        begin
            // XXX these need to be manually commented out when changing
            // the number of L2 ways, since (per IEEE 1800-2012) an
            // instance select must be a constant expression.
            if (`L2_TAG_WAY[0].line_valid[set])
                flush_l2_line(`L2_TAG_WAY[0].sram_tags.data[set], l2_set_idx_t'(set), l2_way_idx_t'(0));

            if (`L2_TAG_WAY[1].line_valid[set])
                flush_l2_line(`L2_TAG_WAY[1].sram_tags.data[set], l2_set_idx_t'(set), l2_way_idx_t'(1));

            if (`L2_TAG_WAY[2].line_valid[set])
                flush_l2_line(`L2_TAG_WAY[2].sram_tags.data[set], l2_set_idx_t'(set), l2_way_idx_t'(2));

            if (`L2_TAG_WAY[3].line_valid[set])
                flush_l2_line(`L2_TAG_WAY[3].sram_tags.data[set], l2_set_idx_t'(set), l2_way_idx_t'(3));

            if (`L2_TAG_WAY[4].line_valid[set])
                flush_l2_line(`L2_TAG_WAY[4].sram_tags.data[set], l2_set_idx_t'(set), l2_way_idx_t'(4));

            if (`L2_TAG_WAY[5].line_valid[set])
                flush_l2_line(`L2_TAG_WAY[5].sram_tags.data[set], l2_set_idx_t'(set), l2_way_idx_t'(5));

            if (`L2_TAG_WAY[6].line_valid[set])
                flush_l2_line(`L2_TAG_WAY[6].sram_tags.data[set], l2_set_idx_t'(set), l2_way_idx_t'(6));

            if (`L2_TAG_WAY[7].line_valid[set])
                flush_l2_line(`L2_TAG_WAY[7].sram_tags.data[set], l2_set_idx_t'(set), l2_way_idx_t'(7));
        end
    end
    endtask

    initial
    begin
        $display("cores %0d|threads per core %0d|l1i$ %0dk %0d ways|l1d$ %0dk %0d ways|l2$ %0dk %0d ways|itlb %0d entries|dtlb %0d entries",
            `NUM_CORES, `THREADS_PER_CORE,
            `L1I_WAYS * `L1I_SETS * CACHE_LINE_BYTES / 1024, `L1I_WAYS,
            `L1D_WAYS * `L1D_SETS * CACHE_LINE_BYTES / 1024, `L1D_WAYS,
            `L2_WAYS * `L2_SETS * CACHE_LINE_BYTES / 1024, `L2_WAYS,
            `ITLB_ENTRIES, `DTLB_ENTRIES);

        if ($test$plusargs("statetrace") != 0)
        begin
            state_dump_en = 1;
            state_dump_fd = $fopen("statetrace.txt", "w");
        end
        else
            state_dump_en = 0;

        if ($value$plusargs("profile=%s", filename) != 0)
        begin
            profile_en = 1;
            profile_fd = $fopen(filename, "w");
        end
        else
            profile_en = 0;

        for (int i = 0; i < MEM_SIZE; i++)
            memory.sdram_data[i] = 0;

        if ($value$plusargs("bin=%s", filename) != 0)
            $readmemh(filename, memory.sdram_data);
        else
        begin
            $display("No memory image file specified with +bin");
            $finish;
        end
    end

    final
    begin
        int mem_dump_start;
        int mem_dump_length;
        int dump_fp;

        $display("ran for %0d cycles", total_cycles);
        if ($value$plusargs("memdumpbase=%x", mem_dump_start) != 0
            && $value$plusargs("memdumplen=%x", mem_dump_length) != 0
            && $value$plusargs("memdumpfile=%s", filename) != 0)
        begin
            if ($test$plusargs("autoflushl2") != 0)
                flush_l2_cache;

            dump_fp = $fopen(filename, "wb");
            for (int i = 0; i < mem_dump_length; i += 4)
            begin
`ifdef VERILATOR
                // -verilator doesn't support fwrite with the %c modifier, so
                // emit code directly in the generated C files to call fputc.
                $c("fputc(", memory.sdram_data[(mem_dump_start + i) / 4][31:24], ", VL_CVT_I_FP(", dump_fp, "));");
                $c("fputc(", memory.sdram_data[(mem_dump_start + i) / 4][23:16], ", VL_CVT_I_FP(", dump_fp, "));");
                $c("fputc(", memory.sdram_data[(mem_dump_start + i) / 4][15:8], ", VL_CVT_I_FP(", dump_fp, "));");
                $c("fputc(", memory.sdram_data[(mem_dump_start + i) / 4][7:0], ", VL_CVT_I_FP(", dump_fp, "));");
`else
                $fwrite(dump_fp,"%c%c%c%c",
                        memory.sdram_data[(mem_dump_start + i) / 4][31:24],
                        memory.sdram_data[(mem_dump_start + i) / 4][23:16],
                        memory.sdram_data[(mem_dump_start + i) / 4][15:8],
                        memory.sdram_data[(mem_dump_start + i) / 4][7:0]);
`endif // !`ifdef VERILATOR
            end

            $fclose(dump_fp);
        end

        if (state_dump_en)
            $fclose(state_dump_fd);

        if (profile_en)
            $fclose(profile_fd);

        // Do this last so emulator doesn't kill us with SIGPIPE during cosimulation.
        if (processor_halt)
            $display("***HALTED***");
    end

    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            finish_cycles <= '0;
            total_cycles <= '0;
        end
        else
        begin
            if (processor_halt)
            begin
                // Run some number of cycles after halt is triggered to flush pending
                // instructions, L2 cache transactions, and the trace reorder queue.
                if (finish_cycles == 0)
                    finish_cycles <= 2000;
                else if (finish_cycles == 1)
                    $finish;
                else
                    finish_cycles <= finish_cycles - 1;
            end
            else
                total_cycles <= total_cycles + 1;    // Don't count cycles after halt

            if (state_dump_en)
            begin
                for (int i = 0; i < `THREADS_PER_CORE; i++)
                begin
                    if (i != 0)
                        $fwrite(state_dump_fd, ",");

                    $fwrite(state_dump_fd, "%d", `CORE0.thread_select_stage.thread_state[i]);
                end

                $fwrite(state_dump_fd, "\n");
            end

            // Randomly sample a program counter for a thread and output to profile file
            if (profile_en && ($random() & 63) == 0)
                $fwrite(profile_fd, "%x\n", `CORE0.ifetch_tag_stage.next_program_counter[$random() % `THREADS_PER_CORE]);
        end
    end
endmodule
