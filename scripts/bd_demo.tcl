# ============================================================================
# bd_demo.tcl
# Minimal Block Design for FIR129 AXI-Stream (Demo / Visualization Only)
# ============================================================================

set design_name fir129_demo_bd

create_bd_design $design_name
current_bd_design $design_name

# ----------------------------------------------------------------------------
# Clock & Reset ports
# ----------------------------------------------------------------------------
set aclk    [create_bd_port -dir I -type clk aclk]
set aresetn [create_bd_port -dir I -type rst aresetn]
set_property CONFIG.POLARITY ACTIVE_LOW $aresetn

# ----------------------------------------------------------------------------
# FIR AXI-Stream wrapper
# ----------------------------------------------------------------------------
set fir [create_bd_cell -type module -reference fir_axis_wrapper fir_0]

connect_bd_net $aclk    [get_bd_pins fir/aclk]
connect_bd_net $aresetn [get_bd_pins fir/aresetn]

# ----------------------------------------------------------------------------
# AXI-Stream ports
# ----------------------------------------------------------------------------
set s_axis [create_bd_intf_port -mode Slave  -vlnv xilinx.com:interface:axis_rtl:1.0 s_axis]
set m_axis [create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 m_axis]

connect_bd_intf_net $s_axis [get_bd_intf_pins fir/s_axis]
connect_bd_intf_net $m_axis [get_bd_intf_pins fir/m_axis]

validate_bd_design
save_bd_design

puts "INFO: Minimal FIR129 demo block design created."
