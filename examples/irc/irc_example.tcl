#!/bin/sh
# the next line restarts using tclsh \
	exec tclsh "$0" "$@"

# irc example script, by David N. Welton <davidw@dedasys.com>
# $Id: irc_example.tcl,v 1.1 2001/11/20 00:01:09 andreas_kupries Exp $

set nick TclIrc
set channel \#tcl

if { [catch {package require irc}] } {
    set here [file dirname [info script]]
    source [file join $here .. .. modules irc irc.tcl]
}

proc bgerror { args } {
    puts $args
    if { [info exists errorInfo] } {
	puts $errorInfo
    }
}

namespace eval client { }

proc client::connect { nick } {
    set cn [::irc::connection irc.openprojects.net 6667]
    set ns [namespace qualifiers $cn]

    $cn registerevent PING {
	network send "PONG [msg]"
	set ::PING 1
    }
	
    $cn registerevent defaultcmd {
	puts "[action] [msg]"
    }

    $cn registerevent defaultnumeric {
	puts "[action] XXX [target] XXX [msg]"
    }

    $cn registerevent defaultevent {
	puts "[action] XXX [who] XXX [target] XXX [msg]"
    }

    $cn registerevent PRIVMSG {
	puts "[who] says to [target] [msg]"
    }

    $cn registerevent KICK {
	puts "[who] KICKed [target 1] from [target] : [msg]"
    }

    $cn connect 

    $cn user $nick localhost "www.tcl-tk.net"
    $cn nick $nick

    vwait ::PING
    $cn join $::channel
}

client::connect $nick

vwait forever
