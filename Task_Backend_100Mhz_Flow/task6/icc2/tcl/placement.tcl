	read_def ./inputs/ORCA_TOP.scandef

	# Without scandef whether we can do the placement 
	# No , But we can use app option to do placement without scandef 
	#set_app_options -name place.coarse.continue_on_missing_scandef -value true

	# Verify scandef
	check_scanchain

	# Verify UPF
	check_mv_design 

	# Set dont_use and dont_touch attributes false on TIE cells 
	set_attribute [get_lib_cells TIE*] -name dont_use -value false
	set_attribute [get_lib_cells TIE*] -name dont_touch -value false

	# Enable advanced legalizer and search and repair option 
	set_app_options -name place.legalize.enable_advanced_legalizer  -value true
	set_app_options -name place.legalize.legalizer_search_and_repair -value true

	# Set max_fanout constraint 
	set_app_options -name opt.common.max_fanout -value 20

	# Set local cell density requirement 
	set_app_options -name place.coarse.max_density -value 0.7

	# Enable route driven extraction (Global routing) 
	set_app_options -name opt.common.enable_rde -value true 

	# Specify max and min routing layer 
	set_ignored_layers -max_routing_layer M6 -min_routing_layer M2
	
	# Set constraints for max and min layers . 
	set_app_options -name route.common.net_max_layer_mode -value hard 
	set_app_options -name route.common.net_min_layer_mode -value allow_pin_connection

	# Make clock ideal 
	foreach_in_collection a [get_scenarios ] {                                                                    
	set_ideal_network [all_fanout -clock_tree -flat ]                                                                        	}

	# Give prefix to the cells added during placement_optimization 
	set_app_options -name opt.common.user_instance_name_prefix -value place_opt_

	# Create coarse placement
	create_placement 

	# legalize placement 
	legalize_placement 
	 
	# Save block 
	save_block -as  coarse_placement_done

	# connect pg nets 
	connect_pg_net
	check_pg_drc 
	check_pg_connectivity

# Up level shifter has 3 voltages (VDD VSS VDDH), Multi height cell 
# down level shifter has 2 voltages (VDD VSS) 

# Analyze the congestion 
	# Methods to reduce congestion 
		# If congestion is in macro channel , Apply soft blockage
			# remove placement
			derive_placement_blockages 
			# create placement
			# leaglize placement

		# If congestion is due to pin density and spread cells , Apply keep-out margin for cells with more pins 
			# select cells where there is more pin density 
			change_selection [get_flat_cells [get_selection ] -filter "number_of_pins > 5"] 
			create_keepout_margin -outer {0.304 0 0.304 0} -type hard [get_selection]
			legalize_placement

		# If congestion is due to cell density , apply partial blockage
		# create_placement -incremental 
	
		# Do congestion driven placement 
		refine_placement -congestion_effort high
	
		# There is no cells in macro channel but still congestion is seen 
		Increase spacing between macros . 

# Create reg to reg path 
group_path -from [all_registers -clock_pins ] -to [all_registers -data_pins ] -weight 1

# Run Place opt command . 
place_opt -from initial_drc -to final_opto
place_opt
save_block -as place_opt_done 

# Do basic checks
check_legality
check_pg_drc 
# Fix violation in gui by changing via dimension 
check_pg_connectivity

# Report_congestion 
report_congestion -rerun_global_router

# Report logical DRVs (max capacitance , max transition , max_fanout )
# max_fanout 
report_net_fanout -threshold 21 [get_nets -filter "net_type != clock"]

# Change scenario
route_global
current_scenario func.ss_125c

# Max_transition.
report_constraints -significant_digits 4 -all_violators -max_transition > ./outputs/reports/mtv.txt

# max_capacitance 
report_constraints -significant_digits 4 -all_violators -max_capacitance > ./outputs/reports/mcv.txt

# Fixing max_transition/max_capacitance 

# 1) Upsize the driver/vt swapping  . (Only if driver is std cells and further drive strength is available) 
# Find the driver cell name of a net 
get_flat_cells -of_objects [get_pins [all_connected I_BLENDER_0/n164 -leaf] -filter "direction == out"]
set dn [get_object_name [get_flat_cells -of_objects [get_pins [all_connected I_BLENDER_0/n164 -leaf] -filter "direction == out"]]]

# Find reference name of driver 
set rn [get_attribute [get_flat_cells $dn] ref_name]

# To get differnt drive strength available 
get_lib_cells NAND2X*_HVT

# upsize cell to higher drive strength 
size_cell $dn NAND2X1_HVT

# Write a TCL proc to upsize driver automatically to next heigher drive strength 

# 2) Insert the buffer . 
# Find driver pin name 
get_pins [all_connected $nm -leaf ] -filter "direction == out"

# insert the buffer to the diver pin 
insert_buffer I_SDRAM_TOP/I_SDRAM_WRITE_FIFO/SD_FIFO_RAM_0/O2[6] NBUFFX8_HVT

# legalize buffer placement
legalize_placement -cells I_SDRAM_TOP/eco_cell

# If fanout is more / load capactance is more 
# 3) load splitting 
# 4) Clonning 

# Time-Analysis (Setup Analysis) 
route_global -reuse_existing_global_route true
# WNS : Worst negative slack : Negative slack in most worst path 
# TNS : Total nagative slack : Sum of all negative slack 

report_timing -delay_type max -transition_time -significant_digits 4 -max_paths 25 > ./outputs/reports/sv.txt

# Apply multicycle path for all scenarios between SYSCLK and SYS_2x_CLK
foreach_in_collection b [get_scenarios ] {                                                                   
 current_scenario $b                                                                                                     
set_multicycle_path -setup 2 -from SYS_CLK -to SYS_2x_CLK                                                                
}


# Fixing (If Delay more )
# Upsize the cell  
# Vt swapping 

# Path grouping 
group_path -from [all_registers -clock_pins ] -to [all_registers -data_pins ] -weight 1
place_opt -final_opto



Task1: fix all max_tran and max_cap.
save_as drv_fixed.









