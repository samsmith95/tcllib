if {![package vsatisfies [package provide Tcl] 8.2]} {return}
package ifneeded base64   2.3.3 [list source [file join $dir base64.tcl]]
package ifneeded uuencode 1.1.4 [list source [file join $dir uuencode.tcl]]
package ifneeded yencode  1.1.1 [list source [file join $dir yencode.tcl]]
