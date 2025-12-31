# To import the design, we need to load the library files (.tf, .lib, .lef) and input files (.v, .sdc, .scandef, .upf).
# since synopsys canot read the library files, we need to convert them to .ndm files using library compiler. this will be done by library team and they will supply the .ndm files. so we need to load the .ndm files.
Note: create directory in workspace with project name
/home/hariklr/workspace/ORCA_TOP/
create PD directory in that, 
cd PD
mkdir inputs
mkdir outputs
mkdir scripts
cd outputs
mkdir work

# step 1: search for the path of .ndm files and add that path to the tool path "search_path"
lappend search_path /home/vlsiguru/PHYSICAL_DESIGN/TRAINER1/ICC2/ORCA_TOP/ref/CLIBs /home/hariklr/workspace/ORCA_TOP/PD/inputs

# step 2: create a variable "lib_ref" with list of .ndm files.
set lib_ref {saed32_1p9m_tech.ndm saed32_hvt.ndm saed32_lvt.ndm saed32_rvt.ndm saed32_sram_lp.ndm}

# step 3: create library named "ORCA_TOP.nlib" in work folder
create_lib -ref_libs $lib_ref ./outputs/works/ORCA_TOP.nlib/

# to see the list of libraries added in the design 
report_ref_libs

# save the library created 
save_lib
# step 4: load the input files in the project and create the block using create_block. since we have already the top module(.v) we can use read_verilog to load the module in to the block.
read_verilog ORCA_TOP.v

# to know the current working block 
current_block

# step 5: lik the block that is loaded
link_block -force

# step 6: save the block
save_block

# to open the already existing library 

open_lib ./outputs/works/ORCA_TOP.nlib/

list_blocks

open_block ORCA_TOP


#
