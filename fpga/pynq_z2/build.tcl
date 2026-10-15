# vivado -mode batch -source build.tcl   (run from this directory)
set_param general.maxThreads 8
set H [file normalize [file dirname [info script]]]
set S [file normalize $H/../../src]
set srcs {}
foreach f [glob $S/*.v] { if {![string match *cpu_core.v $f]} { lappend srcs $f } }
read_verilog [concat $srcs [list $H/pynq_top.v]]
read_xdc $H/pynq_z2.xdc
synth_design -top pynq_top -part xc7z020clg400-1 -include_dirs $S \
    -generic "INST_INIT=\"$H/build/prog.hex\""
opt_design; place_design; route_design
report_utilization -file $H/build/util.rpt
report_timing_summary -file $H/build/timing.rpt
write_bitstream -force $H/build/pynq_top.bit
