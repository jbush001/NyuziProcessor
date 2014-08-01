create_clock -name "clk50" -period 20.000ns [get_ports {clk50}]
derive_pll_clocks -create_base_clocks
derive_clocks -period 20.000ns
derive_clock_uncertainty

