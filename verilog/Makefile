
PIPELINE_SRCS=	rtl/instruction_fetch_stage.v \
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
			rtl/l1_data_cache.v \
			rtl/l1_instruction_cache.v \
			rtl/cache_tag_mem.v \
			rtl/cache_lru.v \
			rtl/mem512.v \
			rtl/store_buffer.v \
			rtl/instruction_fifo.v \
			rtl/arbiter4.v \
			rtl/strand_fsm.v \
			rtl/core.v \
			testbench/sim_l1cache.v \
			testbench/sim_l2cache.v \
			testbench/pipeline_sim.v 

DATA_CACHE_TEST_SRCS = rtl/mem512.v \
			rtl/l1_data_cache.v \
			rtl/store_buffer.v \
			rtl/cache_tag_mem.v \
			rtl/cache_lru.v \
			testbench/l1_data_cache_test.v

INSTRUCTION_CACHE_TEST_SRCS = rtl/l1_instruction_cache.v \
			rtl/cache_tag_mem.v \
			rtl/cache_lru.v \
			rtl/lane_select_mux.v \
			testbench/l1_instruction_cache_test.v

STORE_BUFFER_TEST_SRCS = rtl/mem512.v \
	rtl/store_buffer.v \
	testbench/store_buffer_test.v

IVFLAGS=-Wall -Winfloop -civerilog.cmd -Wno-sensitivity-entire-array

sim.vvp: $(PIPELINE_SRCS)
	iverilog -o $@ $(IVFLAGS) $(PIPELINE_SRCS)

data-cache-test.vvp: $(DATA_CACHE_TEST_SRCS)
	iverilog -o $@ $(IVFLAGS) $(DATA_CACHE_TEST_SRCS)

instruction-cache-test.vvp: $(INSTRUCTION_CACHE_TEST_SRCS)
	iverilog -o $@ $(IVFLAGS) $(INSTRUCTION_CACHE_TEST_SRCS)

store-buffer-test.vvp: $(STORE_BUFFER_TEST_SRCS)
	iverilog -o $@ $(IVFLAGS) $(STORE_BUFFER_TEST_SRCS)

clean:
	rm sim.vvp
