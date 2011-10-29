
SOURCES=	rtl/instruction_fetch_stage.v \
			rtl/strand_select_stage.v \
			rtl/decode_stage.v \
			rtl/execute_stage.v \
			rtl/memory_access_stage.v \
			rtl/writeback_stage.v \
			rtl/pipeline.v \
			rtl/vector_register_file.v \
			rtl/scalar_register_file.v \
			rtl/single_cycle_alu.v \
			rtl/vector_bypass_unit.v \
			rtl/rollback_controller.v \
			testbench/sim_cache.v \
			testbench/pipeline_sim.v 

sim.vvp: $(SOURCES)
	iverilog -o sim.vvp $(SOURCES)

clean:
	rm sim.vvp
