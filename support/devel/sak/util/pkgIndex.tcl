if {![package vsatisfies [package provide Tcl] 8.2]} return
package ifneeded sak::util     1.0 [list source [file join $dir util.tcl]]
package ifneeded sak::registry 1.0 [list source [file join $dir registry.tcl]]
