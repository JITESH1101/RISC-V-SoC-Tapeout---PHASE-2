#if { ! [file exists ../rpts ] } { file mkdir ../rpts }
#if { ! [file exists ../work ] } { file mkdir ../work }
# Open place opt design 
# run cts flow for hold fixing (prj1_cts.tcl)
# If more setup violations 
# close block 
# open place_opt 
# run ccd flow (prj1_cts_ccd.tcl)
# Compare the result 

set_host_options -max_cores 4

################sanity_checks##################

check_design -checks pre_clock_tree_stage
remove_routes -global_route
source ./scripts/cts_option.tcl 
clock_opt -to route_clock
 
save_block -as cts_synthesizing_clock_design1_new

source ./scripts/cts_option.tcl 

# Hold cells and settings
set_lib_cell_purpose -exclude hold [get_lib_cells] 
set_lib_cell_purpose -include hold [get_lib_cells "*/DELLN*_HVT */NBUFFX2_HVT */NBUFFX4_HVT */NBUFFX8_HVT"]

set_app_options -list {opt.dft.clock_aware_scan true}
set_app_options -list {clock_opt.hold.effort high}


## Final Checking prior to CTS
####################################

check_clock_trees

clock_opt -from final_opto
save_block -as clock_opt_hold_fix_design1_new

if 0 {
source ./scripts/cts_option.tcl 

report_clock_qor
report_clock_qor -type local_skew
report_clock_qor -type area
report_clock_qor -mode func -corner ss_125c -significant_digits 3
report_clock_qor -type robustness -mode func -corner best -robustness_corner ss_125c
report_clock_timing -type skew -modes func -corners ss_125c -significant_digits 3
report_qor -summary

}


###################Reporting###############################
