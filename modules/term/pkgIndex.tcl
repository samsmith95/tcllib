if {![package vsatisfies [package provide Tcl] 8.2]} return
package ifneeded term                     0.1 [list source [file join $dir term.tcl]]
package ifneeded term::send               0.1 [list source [file join $dir send.tcl]]
package ifneeded term::ansi::send         0.1 [list source [file join $dir ansi/send.tcl]]
package ifneeded term::ansi::code         0.1 [list source [file join $dir ansi/code.tcl]]
package ifneeded term::ansi::code::ctrl   0.1 [list source [file join $dir ansi/code/ctrl.tcl]]
package ifneeded term::ansi::code::attr   0.1 [list source [file join $dir ansi/code/attr.tcl]]
package ifneeded term::ansi::code::macros 0.1 [list source [file join $dir ansi/code/macros.tcl]]

