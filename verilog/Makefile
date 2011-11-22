
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
			rtl/single_cycle_alu.v \
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
			rtl/pseudo_lru.v \
			rtl/sync_fifo.v \
			rtl/data_cache.v \
			rtl/mem512.v \
			testbench/sim_l1cache.v \
			testbench/sim_l2cache.v \
			testbench/pipeline_sim.v 

DATA_CACHE_TEST_SRCS = rtl/mem512.v \
			rtl/pseudo_lru.v \
			rtl/sync_fifo.v \
			rtl/data_cache.v \
			testbench/l1_data_cache_test.v

sim.vvp: $(PIPELINE_SRCS)
	iverilog -o $@ -Wall -Winfloop -civerilog.cmd $(PIPELINE_SRCS)

data-cache-test.vvp: $(DATA_CACHE_TEST_SRCS)
	iverilog -o $@ -Wall -Winfloop -civerilog.cmd $(DATA_CACHE_TEST_SRCS)

clean:
	rm sim.vvp
