
package ifneeded yaml         0.3.8 [list source [file join $dir yaml.tcl]]
package ifneeded huddle       0.1.7 [list source [file join $dir huddle.tcl]]

if {![package vsatisfies [package provide Tcl] 8.5]} {return}

package ifneeded huddle::json 0.1   [list source [file join $dir json2huddle.tcl]]
