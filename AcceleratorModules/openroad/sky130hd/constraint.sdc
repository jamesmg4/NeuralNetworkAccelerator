current_design MatrixVectorController

# Initial baseline target: 10 ns = 100 MHz.
# Reduce this period in later runs to search for the maximum passing frequency.
set clk_name       core_clock
set clk_port_name  clk
set clk_period     10.0
set io_delay       1.0

set clk_port [get_ports $clk_port_name]
create_clock -name $clk_name -period $clk_period $clk_port

# A virtual clock describes the timing relationship between this block and
# the memories/controllers that will eventually surround it.
set io_clk_name io_$clk_name
create_clock -name $io_clk_name -period $clk_period

set non_clock_inputs [all_inputs -no_clocks]
set timed_inputs [remove_from_collection $non_clock_inputs [get_ports rst_n]]

set_input_delay  $io_delay -clock $io_clk_name $timed_inputs
set_output_delay $io_delay -clock $io_clk_name [all_outputs]

# rst_n is an asynchronous reset, not cycle-by-cycle input data.
set_false_path -from [get_ports rst_n]
