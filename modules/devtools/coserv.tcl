# -*- tcl -*-
# CoServ - Comm Server
# Copyright (c) 2004, Andreas Kupries <andreas_kupries@users.sourceforge.net>

# ### ### ### ######### ######### #########
## Commands to create server processes ready to talk to their parent
## via 'comm'. They assume that the 'tcltest' environment is present
## without having to load it explicitly. We do load 'comm' explicitly.

# ### ### ### ######### ######### #########
## Load "comm" into the master.

namespace eval ::coserv {}

package forget comm
catch {namespace delete comm}

set ::coserv::commsrc [file join [file dirname [file dirname [info script]]] comm comm.tcl]
if {[catch {source $::coserv::commsrc} msg]} {
    puts "Error loading \"comm\": $msg"
    error ""
}

package require comm
puts "- comm [package present comm]"
puts "Main       @ [::comm::comm self]"

# ### ### ### ######### ######### #########
## Core of all sub processes.

set ::coserv::subcode [::tcltest::makeFile {
    puts "Subshell is \"[info nameofexecutable]\""
    catch {wm withdraw .}

    # ### ### ### ######### ######### #########
    ## Get main configuration data out of the command line, i.e.
    ## - Id of the main process for sending information back.
    ## - Path to the sources of comm.

    foreach {commsrc main cookie} $argv break

    # ### ### ### ######### ######### #########
    ## Load and initialize "comm" in the sub process. The latter
    ## includes a report to main that we are ready.

    source $commsrc
    ::comm::comm send $main [list ::coserv::ready $cookie [::comm::comm self]]

    # ### ### ### ######### ######### #########
    ## Now wait for scripts sent by main for execution in sub.

    #comm::comm debug 1
    vwait forever

    # ### ### ### ######### ######### #########
    exit
} coserv.sub]

# ### ### ### ######### ######### #########
## Command used by sub processes to signal that they are ready.

proc ::coserv::ready {cookie id} {
    puts "Sub server @ $id\t\[$cookie\]"
    set ::coserv::go $id
    return
}

# ### ### ### ######### ######### #########
## Start a new sub server process, talk to it.

proc ::coserv::start {cookie} {
    variable subcode
    variable commsrc
    variable go

    set go {}

    exec [info nameofexecutable] $subcode \
	    $commsrc [::comm::comm self] $cookie &

    puts "Waiting for sub server to boot"
    vwait ::coserv::go

    # We return the id of the server
    return $::coserv::go
}

proc ::coserv::run {id script} {
    return [comm::comm send $id $script]
}

proc ::coserv::task {id script} {
    comm::comm send -async $id $script
    return
}

proc ::coserv::shutdown {id} {
    puts "Sub server @ $id\tShutting down ..."
    task $id exit
}

# ### ### ### ######### ######### #########
