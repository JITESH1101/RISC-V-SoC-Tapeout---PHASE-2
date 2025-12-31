
proc size_cell_proc {net_name} {
	# get Driver cell name 
	set cell_name [get_flat_cells -of_objects [get_pins -filter "direction == out" [all_connected -leaf [get_nets $net_name]]]]
        # To get reference name of a driver cell 
	set cell_ref_name [get_attribute [get_flat_cells $cell_name] ref_name]
	puts "cell ref name is $cell_ref_name"
	# NAND2X0_HVT 
	# To cell_ref_name_pattern and to get patten like a= NAND2X; b=1 2 4 8 16  ; c = _HVT
	if {[regexp -nocase {(.*X)([0-9]+)([a-z_]*)} $cell_ref_name temp a b c]} {
		puts "pattern match with cell name"
	}
	# get_lib_cells NAND2X*_HVT
	get_lib_cells $a*$c
	for {set i 0} {$i < 33} {incr i} {
		if {$i == $b} {
			if {$i==0} {
			set d [expr $i+1]
			# size_cell I_BLENDER_1/U3717 NAND2X1_HVT
			size_cell $cell_name $a$d$c
			set new_ref_name [get_attribute [get_flat_cells $cell_name] ref_name]
			puts "new cell ref name is $new_ref_name" 

			} elseif { ($i == 1) | (($i % 2) == 0)} {
			# current drive strength * 2
			set e [expr $i * 2]
			# size_cell NAND2X4_HVT
			size_cell $cell_name $a$e$c
			set new_ref_name [get_attribute [get_flat_cells $cell_name] ref_name]
			puts "new cell ref name is $new_ref_name" 


			}

		}

	}
}

