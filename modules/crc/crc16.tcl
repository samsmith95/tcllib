# crc16.tcl -- Copyright (C) 2002 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# Cyclic Redundancy Check - this is a Tcl implementation of a general
# table-driven CRC implementation. This code should be able to generate
# the lookup table and implement the correct algorithm for most types
# of CRC. CRC-16, CRC-32 and the CITT version of CRC-16.
#
# See http://www.microconsultants.com/tips/crc/crc.txt for the reference
# implementation and http://www.embedded.com/internet/0001/0001connect.htm
# for another good discussion of why things are the way they are.
#
# Checks: a crc for the string "123456789" should give:
#   CRC16:     0xBB3D
#   CRC-CCITT: 0x29B1
#   CRC-32:    0xCBF43926
#
# eg: crc::crc16 "123456789"
#     crc::crc-ccitt "123456789"
# or  crc::crc16 -file tclsh.exe
#
#
# -------------------------------------------------------------------------
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
# -------------------------------------------------------------------------
# $Id: crc16.tcl,v 1.1 2002/09/25 23:43:58 patthoyts Exp $


namespace eval crc {
    
    namespace export crc16 crc-ccitt crc-32

    variable version_crc16 1.0

    # Standard CRC generator polynomials.
    variable polynomial
    set polynomial(crc16) [expr {(1<<16) | (1<<15) | (1<<2) | 1}]
    set polynomial(citt)  [expr {(1<<16) | (1<<12) | (1<<5) | 1}]
    set polynomial(crc32) [expr {(1<<32) | (1<<26) | (1<<23) | (1<<22) 
                                 | (1<<16) | (1<<12) | (1<<11) | (1<<10)
                                 | (1<<8) | (1<<7) | (1<<5) | (1<<4)
                                 | (1<<2) | (1<<1) | 1}]

    # Array to hold the generated tables
    variable table
    if {![info exists table]} { array set table {}}

    # calculate the sign bit for the current platform.
    variable signbit
    if {![info exists signbit]} {
        for {set v 1} {$v != 0} {set signbit $v; set v [expr {$v<<1}]} {}
    }
}

# -------------------------------------------------------------------------
# Generate a CRC lookup table.
# This creates a CRC algorithm lookup lable for a 'width' bits checksum
# using the 'poly' polynomial for all values of an input byte.
# Setting 'reflected' changes the bit order for input bytes.
# Returns a list or 255 elements.
#
# CRC-32:     Crc_table 32 $crc::polynomial(crc32) 1
# CRC-16:     Crc_table 16 $crc::polynomial(crc16) 1
# CRC16/CITT: Crc_table 16 $crc::polynomial(citt)  0
#
proc crc::Crc_table {width poly reflected} {
    set tbl {}
    if {$width < 32} {
        set mask   [expr {(1 << $width) - 1}]
        set topbit [expr {1 << ($width - 1)}]
    } else {
        set mask   0xffffffff
        set topbit 0x80000000
    }

    for {set i 0} {$i < 256} {incr i} {
        if {$reflected} {
            set r [reflect $i 8]
        } else {
            set r $i
        }
        set r [expr {$r << ($width - 8)}]
        for {set k 0} {$k < 8} {incr k} {
            if {[expr {$r & $topbit}] != 0} {
                set r [expr {($r << 1) ^ $poly}]
            } else {
                set r [expr {$r << 1}]
            }
        }
        if {$reflected} {
            set r [reflect $r $width]
        }
        lappend tbl [expr {$r & $mask}]
    }
    return $tbl
}

# -------------------------------------------------------------------------
# Calculate the CRC checksum for the data in 's' using aprecalculated
# table.
#  s the input data
#  width - the width in bits of the CRC algorithm
#  table - the name of the variable holding the calculated table
#  init  - the start value (or the last CRC for sequential blocks)
#  xorout - the final value may be XORd with this value
#  reflected - a boolean indicating that the bit order is reversed.
#              For hardware optimised CRC checks, the bits are handled
#              in transmission order (ie: bit0, bit1, ..., bit7)
proc crc::Crc {s width table {init 0} {xorout 0} {reflected 0}} {
    upvar $table tbl

    if {$width < 32} {
        set mask   [expr {(1 << $width) - 1}]
        set rot    [expr {$width - 8}]
    } else {
        set mask   0xffffffff
        set rot    24
    }

    set crc $init
    binary scan $s c* data
    foreach {datum} $data {
        if {$reflected} {
            set crc [expr {[lindex $tbl \
                                [expr {($crc ^ $datum) & 0xFF}]] \
                               ^ [expr {($crc>>8)}]}]
        } else {
            set crc [expr {[lindex $tbl \
                                [expr {(($crc >> $rot) ^ $datum) & 0xFF}]] \
                               ^ ($crc << 8) & $mask}]
        }
    }

    return [expr {$crc ^ $xorout}]
}

# -------------------------------------------------------------------------
# Reverse the bit ordering for 'b' bits of the input value 'v'
proc crc::reflect {v b} {
    set t $v
    for {set i 0} {$i < $b} {incr i} {
        set v [expr {($t & 1) ? ($v | (1<<(($b-1)-$i))) : ($v & ~(1<<(($b-1)-$i))) }]
        set t [expr {$t >> 1}]
    }
    return $v
}

# -------------------------------------------------------------------------
# Description:
#  Pop the nth element off a list. Used in options processing.
#
proc crc::Pop {varname {nth 0}} {
    upvar $varname args
    set r [lindex $args $nth]
    set args [lreplace $args $nth $nth]
    return $r
}

# -------------------------------------------------------------------------
# Specialisation of the general crc procedure to perform the standard CRC16
# checksum
proc crc::CRC16 {s {seed 0}} {
    variable table
    if {![info exists table(crc16)]} {
        variable polynomial
        set table(crc16) [Crc_table 16 $polynomial(crc16) 1]
    }

    return [Crc $s 16 [namespace current]::table(crc16) $seed 0 1]
}

# -------------------------------------------------------------------------
# Specialisation of the general crc procedure to perform the CCITT telecoms
# flavour of the CRC16 checksum
proc crc::CRC-CCITT {s {seed 0xFFFF}} {
    variable table
    if {![info exists table(citt)]} {
        variable polynomial
        set table(citt) [Crc_table 16 $polynomial(citt) 0]
    }

    return [Crc $s 16 [namespace current]::table(citt) $seed 0 0]
}

# -------------------------------------------------------------------------
# Demostrates the parameters used for the 32 bit checksum CRC-32.
# This can be used to show the algorithm is working right by comparison with
# other crc32 implementations
proc crc::CRC-32 {s {seed 0xFFFFFFFF}} {
    variable table
    if {![info exists table(crc32)]} {
        variable polynomial
        set table(crc32) [Crc_table 32 $polynomial(crc32) 1]
    }

    return [Crc $s 32 [namespace current]::table(crc32) $seed 0xFFFFFFFF 1]
}

# -------------------------------------------------------------------------
# User level CRC command.
proc crc::crc {args} {
    array set opts [list filename {} format %u seed 0 impl [namespace origin CRC16]]
    
    while {[string match -* [lindex $args 0]]} {
        switch -glob -- [lindex $args 0] {
            -fi* { set opts(filename) [Pop args 1] }
            -fo* { set opts(format) [Pop args 1] }
            -i*  { set opts(impl) [uplevel 1 namespace origin [Pop args 1]] }
            -s*  { set opts(seed) [Pop args 1] }
            -- { Pop args ; break }
            default {
                set err [join [lsort [array names opts]] ", -"]
                return -code error "bad option [lindex $args 0]:\
                       must be one of -$options"
            }
        }
        Pop args
    }

    if {$opts(filename) != {}} {
        set r $opts(seed)
        set f [open $opts(filename) r]
        fconfigure $f -translation binary
        while {![eof $f]} {
            set chunk [read $f 4096]
            set r [$opts(impl) [lindex $chunk] $r]
        }
        close $f
    } else {
        if {[llength $args] != 1} {
            return -code error "wrong \# args: should be\
                   \"crc16 ?-format string? ?-seed value? ?-impl procname?\
                   -file name | data\""
        }
        set r [$opts(impl) [lindex $args 0] $opts(seed)]
    }
    return [format $opts(format) $r]
}

# -------------------------------------------------------------------------
# The user commands. See 'crc'
#
proc crc::crc16 {args} {
    return [eval crc -impl [namespace origin CRC16] $args]
}

proc crc::crc-ccitt {args} {
    return [eval crc -impl [namespace origin CRC-CCITT] -seed 0xFFFF $args]
}

proc crc::crc-32 {args} {
    return [eval crc -impl [namespace origin CRC-32] -seed 0xFFFFFFFF $args]
}

# -------------------------------------------------------------------------

package provide crc16 $crc::version_crc16

# -------------------------------------------------------------------------
#
# Local variables:
#   mode: tcl
#   indent-tabs-mode: nil
# End:
