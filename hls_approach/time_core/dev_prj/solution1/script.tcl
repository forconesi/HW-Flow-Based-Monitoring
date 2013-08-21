############################################################
## This file is generated automatically by Vivado HLS.
## Please DO NOT edit it.
## Copyright (C) 2013 Xilinx Inc. All rights reserved.
############################################################
open_project dev_prj
set_top time_gen
add_files src/time_gen.cpp
add_files -tb src/simple_test.cpp
open_solution "solution1"
set_part  {xc5vtx240tff1759-2}
create_clock -period 5

source "./dev_prj/solution1/directives.tcl"
csynth_design
