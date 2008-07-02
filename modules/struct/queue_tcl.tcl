# queue.tcl --
#
#	Queue implementation for Tcl.
#
# Copyright (c) 1998-2000 by Ajuba Solutions.
# Copyright (c) 2008 Andreas Kupries
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# 
# RCS: @(#) $Id: queue_tcl.tcl,v 1.1 2008/07/02 23:35:07 andreas_kupries Exp $

namespace eval ::struct {}
namespace eval ::struct::queue {
    # The arrays hold all of the queues which were made.
    variable qat    ; # Index in qret of next element to return
    variable qret   ; # List of elements waiting for return
    variable qadd   ; # List of elements added and not yet reached for return.
    
    # counter is used to give a unique name for unnamed queues
    variable counter 0

    # Only export one command, the one used to instantiate a new queue
    namespace export queue_tcl
}

# ::struct::queue::queue_tcl --
#
#	Create a new queue with a given name; if no name is given, use
#	queueX, where X is a number.
#
# Arguments:
#	name	name of the queue; if null, generate one.
#
# Results:
#	name	name of the queue created

proc ::struct::queue::queue_tcl {args} {
    variable qat
    variable qret
    variable qadd
    variable counter

    switch -exact -- [llength [info level 0]] {
	1 {
	    # Missing name, generate one.
	    incr counter
	    set name "queue${counter}"
	}
	2 {
	    # Standard call. New empty queue.
	    set name [lindex $args 0]
	}
	default {
	    # Error.
	    return -code error \
		    "wrong # args: should be \"queue ?name?\""
	}
    }

    # FIRST, qualify the name.
    if {![string match "::*" $name]} {
        # Get caller's namespace; append :: if not global namespace.
        set ns [uplevel 1 [list namespace current]]
        if {"::" != $ns} {
            append ns "::"
        }

        set name "$ns$name"
    }
    if {[llength [info commands $name]]} {
	return -code error \
		"command \"$name\" already exists, unable to create queue"
    }

    # Initialize the queue as empty
    set qat($name)  0
    set qret($name) [list]
    set qadd($name) [list]

    # Create the command to manipulate the queue
    interp alias {} $name {} ::struct::queue::QueueProc $name

    return $name
}

##########################
# Private functions follow

# ::struct::queue::QueueProc --
#
#	Command that processes all queue object commands.
#
# Arguments:
#	name	name of the queue object to manipulate.
#	args	command name and args for the command
#
# Results:
#	Varies based on command to perform

proc ::struct::queue::QueueProc {name {cmd ""} args} {
    # Do minimal args checks here
    if { [llength [info level 0]] == 2 } {
	error "wrong # args: should be \"$name option ?arg arg ...?\""
    }
    
    # Split the args into command and args components
    set sub _$cmd
    if { [llength [info commands ::struct::queue::$sub]] == 0 } {
	set optlist [lsort [info commands ::struct::queue::_*]]
	set xlist {}
	foreach p $optlist {
	    set p [namespace tail $p]
	    lappend xlist [string range $p 1 end]
	}
	set optlist [linsert [join $xlist ", "] "end-1" "or"]
	return -code error \
		"bad option \"$cmd\": must be $optlist"
    }

    uplevel 1 [linsert $args 0 ::struct::queue::_$cmd $name]
}

# ::struct::queue::_clear --
#
#	Clear a queue.
#
# Arguments:
#	name	name of the queue object.
#
# Results:
#	None.

proc ::struct::queue::_clear {name} {
    variable qat
    variable qret
    variable qadd
    set qat($name)  0
    set qret($name) [list]
    set qadd($name) [list]
    return
}

# ::struct::queue::_destroy --
#
#	Destroy a queue object by removing it's storage space and 
#	eliminating it's proc.
#
# Arguments:
#	name	name of the queue object.
#
# Results:
#	None.

proc ::struct::queue::_destroy {name} {
    variable qat  ; unset qat($name)
    variable qret ; unset qret($name)
    variable qadd ; unset qadd($name)
    interp alias {} $name {}
    return
}

# ::struct::queue::_get --
#
#	Get an item from a queue.
#
# Arguments:
#	name	name of the queue object.
#	count	number of items to get; defaults to 1
#
# Results:
#	item	first count items from the queue; if there are not enough 
#		items in the queue, throws an error.

proc ::struct::queue::_get {name {count 1}} {
    if { $count < 1 } {
	error "invalid item count $count"
    } elseif { $count > [_size $name] } {
	error "insufficient items in queue to fill request"
    }

    Shift? $name

    variable qat  ; upvar 0 qat($name)  AT
    variable qret ; upvar 0 qret($name) RET
    variable qadd ; upvar 0 qadd($name) ADD

    if { $count == 1 } {
	# Handle this as a special case, so single item gets aren't
	# listified

	set item [lindex $RET $AT]
	incr AT
	Shift? $name
	return $item
    }

    # Otherwise, return a list of items

    if {$count > ([llength $RET] - $AT)} {
	# Need all of RET and parts of ADD, maybe all.
	set max    [expr {$count - ([llength $RET] - $AT) - 1}]
	set result [concat $RET [lrange $ADD 0 $max]]
	Shift $name
	set AT $max
    } else {
	# Request can be satisified from RET alone.
	set max    [expr {$AT + $count - 1}]
	set result [lrange $RET $AT $max]
	set AT $max
    }

    incr AT
    Shift? $name
    return $result
}

# ::struct::queue::_peek --
#
#	Retrieve the value of an item on the queue without removing it.
#
# Arguments:
#	name	name of the queue object.
#	count	number of items to peek; defaults to 1
#
# Results:
#	items	top count items from the queue; if there are not enough items
#		to fulfill the request, throws an error.

proc ::struct::queue::_peek {name {count 1}} {
    variable queues
    if { $count < 1 } {
	error "invalid item count $count"
    } elseif { $count > [_size $name] } {
	error "insufficient items in queue to fill request"
    }

    Shift? $name

    variable qat  ; upvar 0 qat($name)  AT
    variable qret ; upvar 0 qret($name) RET
    variable qadd ; upvar 0 qadd($name) ADD

    if { $count == 1 } {
	# Handle this as a special case, so single item pops aren't
	# listified
	return [lindex $RET $AT]
    }

    # Otherwise, return a list of items

    if {$count > [llength $RET] - $AT} {
	# Need all of RET and parts of ADD, maybe all.
	set over [expr {$count - ([llength $RET] - $AT) - 1}]
	return [concat $RET [lrange $ADD 0 $over]]
    } else {
	# Request can be satisified from RET alone.
	return [lrange $RET $AT [expr {$AT + $count - 1}]]
    }
}

# ::struct::queue::_put --
#
#	Put an item into a queue.
#
# Arguments:
#	name	name of the queue object
#	args	items to put.
#
# Results:
#	None.

proc ::struct::queue::_put {name args} {
    variable qadd
    if { [llength $args] == 0 } {
	error "wrong # args: should be \"$name put item ?item ...?\""
    }
    foreach item $args {
	lappend qadd($name) $item
    }
    return
}

# ::struct::queue::_unget --
#
#	Put an item into a queue. At the _front_!
#
# Arguments:
#	name	name of the queue object
#	item	item to put at the front of the queue
#
# Results:
#	None.

proc ::struct::queue::_unget {name item} {
    variable qat  ; upvar 0 qat($name) AT
    variable qret ; upvar 0 qret($name) RET

    if {![llength $RET]} {
	set RET [list $item]
    } elseif {$AT == 0} {
	set RET [linsert [K $RET [unset RET]] 0 $item]
    } else {
	# step back and modify return buffer
	incr AT -1
	set RET [lreplace [K $RET [unset RET]] $AT $AT $item]
    }
    return
}

# ::struct::queue::_size --
#
#	Return the number of objects on a queue.
#
# Arguments:
#	name	name of the queue object.
#
# Results:
#	count	number of items on the queue.

proc ::struct::queue::_size {name} {
    variable qat
    variable qret
    variable qadd
    return [expr {
	  [llength $qret($name)] + [llength $qadd($name)] - $qat($name)
    }]
}

# ### ### ### ######### ######### #########

proc ::struct::queue::Shift? {name} {
    variable qat
    variable qret
    if {$qat($name) < [llength $qret($name)]} return
    Shift $name
    return
}

proc ::struct::queue::Shift {name} {
    variable qat
    variable qret
    variable qadd
    set qat($name) 0
    set qret($name) $qadd($name)
    set qadd($name) [list]
    return
}

proc ::struct::queue::K {x y} { set x }

# ### ### ### ######### ######### #########
## Ready

namespace eval ::struct {
    # Get 'queue::queue' into the general structure namespace for
    # pickup by the main management.
    namespace import -force queue::queue_tcl
}

