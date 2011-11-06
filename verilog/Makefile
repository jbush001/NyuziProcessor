
SOURCES=	rtl/instruction_fetch_stage.v \
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
			rtl/fp_multiplier_stage2.v \
			rtl/fp_multiplier_stage3.v \
			rtl/fp_normalize.v \
			testbench/sim_cache.v \
			testbench/pipeline_sim.v 

sim.vvp: $(SOURCES)
	iverilog -o sim.vvp -Irtl $(SOURCES)

clean:
	rm sim.vvp
