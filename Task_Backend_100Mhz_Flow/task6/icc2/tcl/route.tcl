# Perform pre-route check 
# check_design -checks pre_route_stage


# Antenna violation (by default enabled )
# Cross talk 
# Timing 

# Steps in routing 
	# Global route 
	# Track assignment
	# Detailed routing  

# read Antenna rule file 
source /home/vlsiguru/PHYSICAL_DESIGN/TRAINER1/ICC2/ORCA_TOP/ref/tech/saed32nm_ant_1p9m.tcl 

# Enable cross talk  and timing during Global route  
set_app_options -name route.global.crosstalk_driven -value true
set_app_options -name route.global.timing_driven -value true

# Enable cross talk  and timing during Track assignment 
set_app_options -name route.track.crosstalk_driven -value true
set_app_options -name route.track.timing_driven -value true

#  Enable cross talk  and timing during delailed routing 
set_app_options -name route.detail.timing_driven -value true

# Enable few options with timing analysis  
set_app_options -name time.si_enable_analysis -value true
set_app_options -name time.si_xtalk_composite_aggr_mode -value statistical
set_app_options -name time.all_clocks_propagated -value true
set_app_options -name time.enable_ccs_rcv_cap -value true

# Set dont touch attribute on clock network 
set_dont_touch_network -clock_only [get_ports *clk*]

# Perform all steps of routing 
route_auto -save_after_global_route true -save_after_track_assignment true -save_after_detail_route true

# Give prefix to the cells added during route_opt stage 
set_app_options -name opt.common.user_instance_name_prefix -value route_opt_

# Run routing optimization 
route_opt

# save block 
save_block -as route_opt_done

# Check routes for drc violations 
check_routes 
check_pg_connectivity
check_pg_drc

# Check LVS  
  check_lvs -nets [get_nets -filter "net_type != power && net_type != ground"] 

Shft + r -- Start routing
s -- extend or de-extend 
shft + l -- Cut metal layers 
