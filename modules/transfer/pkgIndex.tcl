if {![package vsatisfies [package provide Tcl] 8.4]} return
package ifneeded transfer::copy              0.1 [list source [file join $dir copyops.tcl]]
