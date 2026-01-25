# ============================================================================
# create_project.tcl
# Minimal Vivado project for FIR 129-tap Stereo AXI-Stream
# ============================================================================

set proj_name fir129_stereo
set proj_dir  ./vivado_${proj_name}
set part      xck26-sfvc784-2LV-c

create_project $proj_name $proj_dir -part $part -force

# ----------------------------------------------------------------------------
# Project properties
# ----------------------------------------------------------------------------
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# ----------------------------------------------------------------------------
# RTL sources
# ----------------------------------------------------------------------------
add_files -fileset sources_1 [glob ../rtl/*.v]
set_property top fir_axis_stereo [get_filesets sources_1]

# ----------------------------------------------------------------------------
# Simulation sources
# ----------------------------------------------------------------------------
add_files -fileset sim_1 [glob ../sim/*.sv]
set_property top tb_fir_axis [get_filesets sim_1]

# ----------------------------------------------------------------------------
# Compile order
# ----------------------------------------------------------------------------
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "INFO: FIR129 stereo project created successfully."
