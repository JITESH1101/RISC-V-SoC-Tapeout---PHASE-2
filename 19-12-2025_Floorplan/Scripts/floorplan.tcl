############################################################
# Task 5 – SoC Floorplanning Using ICC2 (Floorplan Only)
# Design  : vsdcaravel
# Tool    : Synopsys ICC2 2022.12
############################################################

# ---------------------------------------------------------
# Basic Setup
# ---------------------------------------------------------
set DESIGN_NAME      vsdcaravel
set DESIGN_LIBRARY   vsdcaravel_fp_lib

# ---------------------------------------------------------
# Reference Library (includes technology internally)
# ---------------------------------------------------------
# Using unified NDM library provided with ICC2 workshop
set REF_LIB \
"/home/Synopsys/pdk/SCL_PDK_3/work/run1/icc2_workshop_collaterals/standaloneFlow/work/raven_wrapperNangate/lib.ndm"

# ---------------------------------------------------------
# Create ICC2 Design Library
# ---------------------------------------------------------
if {[file exists $DESIGN_LIBRARY]} {
    file delete -force $DESIGN_LIBRARY
}

create_lib $DESIGN_LIBRARY \
    -ref_libs $REF_LIB

# ---------------------------------------------------------
# Read Synthesized Netlist
# (Netlist is read only to create design context;
# unresolved cells are acceptable for floorplan-only task)
# ---------------------------------------------------------
read_verilog -top $DESIGN_NAME /home/rjreddy/task4/vsdRiscvScl180/synthesis/output/vsdcaravel_synthesis.v

current_design $DESIGN_NAME

# ---------------------------------------------------------
# Floorplan Definition (MANDATORY)
# Die Size  : 3.588 mm × 5.188 mm
# Core Margin : 200 µm on all sides
#
# NOTE:
# This ICC2 version requires die-controlled initialization
# using -control_type die and -boundary syntax.
# ---------------------------------------------------------
initialize_floorplan \
    -control_type die \
    -boundary {{0 0} {3588 5188}} \
    -core_offset {200 200 200 200}
# ---------------------------------------------------------
# IO Regions using Placement Blockages (Corrected)
# ---------------------------------------------------------

# Bottom IO region (along bottom die edge)
create_placement_blockage \
  -name IO_BOTTOM \
  -type hard \
  -boundary {{0 0} {3588 100}}

# Top IO region (along top die edge)
create_placement_blockage \
  -name IO_TOP \
  -type hard \
  -boundary {{0 5088} {3588 5188}}

# Left IO region (along left die edge)
create_placement_blockage \
  -name IO_LEFT \
  -type hard \
  -boundary {{0 100} {100 5088}}

# Right IO region (along right die edge)
create_placement_blockage \
  -name IO_RIGHT \
  -type hard \
  -boundary {{3488 100} {3588 5088}}


# ---------------------------------------------------------
# Macro Placement
# ---------------------------------------------------------
# NOTE:
# No physical hard macros exist in this design.
# RAM128 and RAM256 are RTL-based memory models that were
# synthesized into logic and optimized away.
# Therefore, no macro placement is performed here.
# ---------------------------------------------------------

# ---------------------------------------------------------
# Reports
# ---------------------------------------------------------
redirect -file /home/rjreddy/task4/vsdRiscvScl180/Floorplan/reports/floorplan_report.txt {

    puts "===== FLOORPLAN GEOMETRY (USER DEFINED) ====="
    puts "Die Area  : 0 0 3588 5188  (microns)"
    puts "Core Area : 200 200 3388 4988  (microns)"

    puts "\n===== TOP LEVEL PORTS ====="
    get_ports
}
