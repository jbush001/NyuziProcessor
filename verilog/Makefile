
SIMULATOR_SRCS=	rtl/instruction_fetch_stage.v \
			rtl/strand_select_stage.v \
			rtl/decode_stage.v \
			rtl/execute_stage.v \
			rtl/memory_access_stage.v \
			rtl/writeback_stage.v \
			rtl/pipeline.v \
			rtl/vector_register_file.v \
			rtl/scalar_register_file.v \
			rtl/vector_bypass_unit.v \
			rtl/rollback_controller.v \
			rtl/multi_cycle_vector_alu.v \
			rtl/multi_cycle_scalar_alu.v \
			rtl/single_cycle_vector_alu.v \
			rtl/single_cycle_scalar_alu.v \
			rtl/fp_adder_stage1.v \
			rtl/fp_adder_stage2.v \
			rtl/fp_adder_stage3.v \
			rtl/fp_multiplier_stage1.v \
			rtl/fp_normalize.v \
			rtl/fp_convert.v \
			rtl/integer_multiplier.v \
			rtl/lane_select_mux.v \
			rtl/vector_shuffler.v \
			rtl/fp_recip_stage1.v \
			rtl/fp_recip_stage2.v \
			rtl/fp_recip_stage3.v \
			rtl/reciprocal_rom.v \
			rtl/l1_cache.v \
			rtl/l1_cache_tag.v \
			rtl/cache_lru.v \
			rtl/store_buffer.v \
			rtl/sync_fifo.v \
			rtl/arbiter4.v \
			rtl/arbiter2.v \
			rtl/strand_fsm.v \
			rtl/core.v \
			rtl/load_miss_queue.v \
			rtl/mask_unit.v \
			rtl/pci_arbiter_mux.v \
			rtl/execute_hazard_detect.v \
			rtl/assertion.v \
			rtl/latency_decoder.v \
			rtl/l2_cache.v \
			rtl/l2_cache_arb.v \
			rtl/l2_cache_response.v \
			rtl/l2_cache_smi.v \
			rtl/l2_cache_tag.v \
			rtl/l2_cache_dir.v \
			rtl/l2_cache_read.v \
			rtl/l2_cache_write.v \
			rtl/l2_cache_pending_miss.v \
			rtl/sram_1r1w.v \
			testbench/simulator_top.v \
			testbench/sim_memory.v 

TEST_L2_CACHE_SRCS=rtl/l2_cache.v \
			rtl/l2_cache_arb.v \
			rtl/l2_cache_response.v \
			rtl/l2_cache_smi.v \
			rtl/l2_cache_tag.v \
			rtl/l2_cache_dir.v \
			rtl/l2_cache_read.v \
			rtl/l2_cache_write.v \
			rtl/l2_cache_pending_miss.v \
			testbench/test_l2_cache.v \
			rtl/cache_lru.v \
			rtl/mask_unit.v \
			rtl/sync_fifo.v \
			rtl/assertion.v

IVFLAGS=-Wall -Winfloop -civerilog.cmd -Wno-sensitivity-entire-array -Irtl

sim.vvp: $(SIMULATOR_SRCS) Makefile
	iverilog -o $@ $(IVFLAGS) $(SIMULATOR_SRCS)

# Expands AUTOWIRE/AUTOINST/etc. Requires emacs and verilog-mode module installed.
autos: $(SIMULATOR_SRCS)
	emacs --batch $(SIMULATOR_SRCS) -f verilog-batch-auto -f save-buffer

lint: $(SIMULATOR_SRCS)
	-verilator --lint-only rtl/core.v -Wall -Irtl -Wno-ASSIGNDLY -Wno-WIDTH
	-verilator --lint-only rtl/l2_cache.v -Wall -Irtl -Wno-ASSIGNDLY -Wno-WIDTH

test-l2-cache.vvp: $(TEST_L2_CACHE_SRCS)
	iverilog -o $@ $(IVFLAGS) $(TEST_L2_CACHE_SRCS)

clean:
	rm -f sim.vvp
