package require listutil
package require dicttool
package require cron 1.2
::namespace eval ::tool {}

###
# topic: 27196ce57a9fd09198a0b277aabdb0a96b432cb9
###
proc ::tool::pathload {path {order {}} {skip {}}} {
  set loaded {pkgIndex.tcl index.tcl}
  foreach item $skip {
    lappend loaded [file tail $skip]
  }
  foreach file $order {
    set file [file tail $file]
    if {$file in $loaded} continue
    uplevel #0 [list source [file join $path $file]]
    lappend loaded $file
  }
  foreach file [lsort -dictionary [glob -nocomplain [file join $path *.tcl]]] {
    if {[file tail $file] in $loaded} continue
    uplevel #0 [list source $file]
    lappend loaded [file tail $file]
  }
}

set idxfile [file normalize [info script]]
set cwd [file dirname $idxfile]
set ::tool::tool_root [file dirname $cwd]
::tool::pathload $cwd {} $idxfile
package provide tool 0.1

