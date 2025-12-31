# open the existing library and block/design
# enter into PD folder and open the tool
#
# open the LIBRARY
open_lib ./outputs/works/ORCA_TOP.nlib/

list_blocks 

#open the Block
open_block ORCA_TOP

#access the cells and number of cells in the design
# gives the list of cells in the top module
get_cells

#gives the list of leaf cells in the top module 
get_flat_cells


# to get count of cells in the top module
sizeof_collection [get_cells]
sizeof_collection [get_flat_cells]

#to get list and count of macros

get_flat_cells -filter "is_hard_macro == true"

sizeof_collection [get_flat_cells -filter "is_hard_macro == true"

#to get list of ports and count

get_ports

sizeof_collection [get_ports]

# to get count of input and output ports only
#
sizeof_collection [all_inputs]
sizeof_collection [all_outputs]

# to get collection of std_cells in the design 
get_flat_cells -filter "is_hard_macro==false"
sizeof_collection [get_flat_cells -filter "is_hard_macro==false"]

# to find the height, width and area of the std_cells in the design

get_attribute [get_flat_cells -filter "is_hard_macro==false"] height
get_attribute [get_flat_cells -filter "is_hard_macro==false"] width
get_attribute [get_flat_cells -filter "is_hard_macro==false"] area

#to get height, width, area, ref_name, physical_status and to check whether is macro or std_cell of particular cell I_PCI_TOP/mult_x_32/U475
get_attribute [get_flat_cells I_PCI_TOP/mult_x_32/U475] height
get_attribute [get_flat_cells I_PCI_TOP/mult_x_32/U475] width
get_attribute [get_flat_cells I_PCI_TOP/mult_x_32/U475] area
get_attribute [get_flat_cells I_PCI_TOP/mult_x_32/U475] ref_name
get_attribute [get_flat_cells I_PCI_TOP/mult_x_32/U475] physical_status
get_attribute [get_flat_cells I_PCI_TOP/mult_x_32/U475] is_hard_macro

# to find the total area of cells in the design
set total_area 0
foreach_in_collection a [get_fla
get_flat_cells get_flat_nets  get_flat_pins  
 foreach_in_collection a [get_flat_cells] {
set area_cells [get_attribute [get_flat_cells $a] area]
set total_area [expr $total_area + $area_cells]
}
puts $total_area


# to print the attributes of routing layers information as a table in new file
puts "metal_name\tmin_spacing\tmin_width\tpitch\trouting_direction"
foreach_in_collection m [get_layers -filter "is_routing_layer" M*] {                                                                                     
set msp [get_attribute [get_layers $m] min_spacing] 
set mw [get_attribute [get_layers $m] min_width]    
set pi [get_attribute [get_layers $m] pitch]
set rd [get_attribute [get_layers $m] routing_direction] 
set on [get_object_name $m]             
puts "$on\t\t$msp\t\t$mw\t\t$pi\t\t$rd"      
}


#floorplan initialization
initialize_floorplan -core_offset 5 -core_utilization 0.75 -side_ratio {1 1} -flip_first_row true -use_site_row -site_def unit
#get_attribute [get_core_area] area

# input placement on side 1 except clock inputs
remove_block_pin_constraints
set_block_pin_constraints -sides 1 -allowed_layers M5 -pin_spacing 5 -self -corner_keepout_distance 100
place_pins -ports [remove_from_collection [all_inputs] [get_ports *clk*]]

# output placement on side 3
remove_block_pin_constraints
set_block_pin_constraints -sides 3 -allowed_layers M5 -pin_spacing 5 -self -corner_keepout_distance 100
place_pins -ports [all_outputs]


# clk pin placement on side 2
remove_block_pin_constraints
set_block_pin_constraints -sides 2 -allowed_layers M6 -pin_spacing 5 -self -corner_keepout_distance 100
place_pins -ports [get_ports *clk*]


# read UPF file
#
load_upf ./inputs/ORCA_TOP.upf

connect_pg_net

check_mv_design

save_block

# create voltage area
# 
# get the llx, urx coordinates and increase by the value 5.016
# the site column width is 0.152, 5/0.152=32.89.
# to get exact integer multiples 33*0.152=5.016.

set llx [expr [lindex $pbbox 0 0] + 5.016]

set urx [expr [lindex $pbbox 1 0] + 5.016]

# get the lly, ury coordinates and reduce the value by 5.016
# # the site row height is 1.672, 5/1.672=2.99
#  to get exact integer multiples 3*1.672=5.016
#
set lly [expr [lindex $pbbox 0 1] - 5.016]

set ury [expr [lindex $pbbox 1 1] - 5.016]

# with these coordinates set the voltage area bbox 
#
set va_bbox [list [list $llx $lly] [list $urx $ury]]

# create voltage area with these coordinates and with guard band with horizontal and vertical spacing of 5.016

#
create_voltage_area -power_domains PD_RISC_CORE -region $va_bbox -guard_band {{5.016 5.016}}

# remove the placement blockage created
#
remove_placement_blockages pb_1

# save the block
save_block

# check multivoltage design
#
check_mv_design


# do the macro placement as per the macro placement guidelines
# ensure that there are no criss-cross connections in the macros
# create keepout margin around the macros

create_keepout_margin -type hard -outer {1 1 1 1} [get_flat_cells -filter "is_hard_macro"]


# do the power plan as per the script given
#
#
source ./scripts/powerfinal.tcl

# check the rules
check_pg_drc

# if keepout margin is not applied around macro, minimum width for M1 error will popup in the error log.
# so always apply keepout margin around the macros to avoid this error
#
check_pg_connectivity -check_std_cell_pins none

# check for the errors in the view--> error log
# floating wire violations, floating pin of hard macros errors will be present
# sol for floating wire violations: increase spacing between the macros.
# in guard band of voltage area cut the rows.
# apply the placement blockage and get the bbox and cut the rows.
# get_attribute [get_flat_cells -filter "is_hard_macro"] bbox
# cut_rows -within {bbox coordinates}
# remove the placement blockage
# sol: floating hard macro pins: increase the spacing by seeing the overlap regions of VDD, Vss with macro pins.
# once all the errors are solved, fix the macro placement.
#
## fix the macro placement
#
set_attribute [get_flat_cells -filter "is_hard_macro"] physical_status -value fixed


#physical cell placement
# our library doesn't have boundary cells, so we use DCAP cells as boundary cells.
#
get_lib_cells *DCAP*

set_boundary_cell_rules -left_boundary_cell saed32_hvt|saed32_hvt_std/DCAP_HVT -right_boundary_cell saed32_hvt|saed32_hvt_std/DCAP_HVT -at_va_boundary

compile_boundary_cells

check_boundary_cells


# if you want to remove the cells use this command
# remove_cells [get_flat_cells *boundarycell* -all]
#
#
# insert Tap cells
#
create_tap_cells -lib_cell saed32_hvt|saed32_hvt_std/DCAP_HVT -distance 30 -pattern stagger -skip_fixed_cells

check_legality

connect_pg_net

check_pg_drc

check_pg_connectivity -check_std_cell_pins none




