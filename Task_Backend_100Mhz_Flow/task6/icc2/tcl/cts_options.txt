#source ./inputs/sdc_constraints/mcmm_ORCA_TOP.tcl

# Specify cells to be used during CTS 
# Specify NDR 
# Specify Timing Constraints 
# Specify design Constraints 

######################################################
#############          running CTS         ###########
######################################################
#runs clock tree synthesis and optimization
connect_pg_net -verbose

#common_optimization_settings_icc.tcl
set timing_enable_multiple_clocks_per_reg true
set_auto_disable_drc_nets -constant false

####################################
## CTS Cell Selection
####################################
# Gives alternate library cell for cells in clock path
# Cells in clock path " Buff Inv CG (ff and andgate) basic gates/gates , Mux , LS"  
derive_clock_cell_references -output cts_leq_set.tcl 

# Cell can be during optimization 
set CTS_CELLS [get_lib_cells "*/NBUFF*LVT */NBUFF*RVT */INVX*_LVT */INVX*_RVT */*DFF*"]
set_dont_touch $CTS_CELLS false
set_lib_cell_purpose -exclude cts [get_lib_cells] 
set_lib_cell_purpose -include cts $CTS_CELLS
source ./scripts/cts_include_refs.tcl

report_lib_cells -objects [get_lib_cells ] -columns {name:20 valid_purposes dont_touch}

####################################
## CTS NDRs
####################################
#
# NDR depends on Cross talk and Electromigration (Double width Double spacing) 
set_ignored_layers -max_routing_layer M6
set_ignored_layers -min_routing_layer M1


remove_routing_rules -all 
create_routing_rule iccrm_clock_double_spacing -default_reference_rule -multiplier_spacing 2 -taper_distance 0.4 -driver_taper_distance 0.4
set_clock_routing_rules -rules iccrm_clock_double_spacing -min_routing_layer M4 -max_routing_layer M5
report_routing_rules -verbose
report_clock_routing_rules

######Timing and DRC Setup
####################################

######Ensure that driving cells are specified on all clock ports
set enable_recovery_removal_arcs true

foreach_in_collection scen [all_scenarios] {
	current_scenario $scen
	set_clock_uncertainty 0.05 -setup [all_clocks]
	set_clock_uncertainty 0.02 -hold [all_clocks]
}

report_ports -verbose [get_ports *clk] 

foreach_in_collection scen [all_scenarios] {
   current_scenario $scen
   set_driving_cell -lib_cell NBUFFX16_RVT [get_ports *clk]
}

#Set a max transition for the clocks in func mode only
current_mode func
set_max_transition 0.15 -clock_path [get_clocks] -corners [all_corners]

####################################
## Clock Tree Targets
####################################

set_clock_tree_options -target_skew 0.05 -corners [get_corners ss_125c]
set_clock_tree_options -target_skew 0.05 -corners [get_corners ss_m40c]
set_clock_tree_options -target_skew 0.02 -corners [get_corners ff_m40c]
set_clock_tree_options -target_skew 0.02 -corners [get_corners ff_125c]

####################################
## Clock Tree Balance Points

foreach_in_collection mode [all_modes] {
   current_mode $mode
   set_clock_balance_points \
      -consider_for_balancing true \
      -balance_points [get_pins "I_SDRAM_TOP/I_SDRAM_IF/sd_mux_*/S0"]
}

	
####################################
## Dont Touch Cells

set_dont_touch [get_cells "I_SDRAM_TOP/I_SDRAM_IF/sd_mux_*"]
report_dont_touch I_SDRAM_TOP/I_SDRAM_IF/sd_mux_*

set_dont_touch [get_cells "I_CLOCKING/sys_clk_in_reg"]
report_dont_touch I_CLOCKING/sys_clk_in_reg


############################################
##app options
set_app_options -name time.remove_clock_reconvergence_pessimism -value true

set_app_option -name opt.common.user_instance_name_prefix -value clock_opt_data_
set_app_option -name cts.common.user_instance_name_prefix -value clock_opt_clock_

