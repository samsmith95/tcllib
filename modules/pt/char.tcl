# -*- tcl -*-
#
# Copyright (c) 2009 by Andreas Kupries <andreas_kupries@users.sourceforge.net>
# Operations with characters: (Un)quoting.

# ### ### ### ######### ######### #########
## Requisites

package require Tcl 8.5

namespace eval char {
    namespace export unquote quote
    namespace ensemble create
    namespace eval quote {
	namespace export tcl string comment cstring
	namespace ensemble create
    }
}

# ### ### ### ######### ######### #########
## API

proc ::char::unquote {args} {
    if {1 == [llength $args]} { return [Unquote {*}$args] }
    set res {}
    foreach ch $args { lappend res [Unquote $ch] }
    return $res
}

proc ::char::Unquote {ch} {

    # A character, stored in quoted form is transformed back into a
    # proper Tcl character (i.e. the internal representation).

    switch -exact -- $ch {
	"\\n"  {return \n}
	"\\t"  {return \t}
	"\\r"  {return \r}
	"\\["  {return \[}
	"\\]"  {return \]}
	"\\'"  {return '}
	"\\\"" {return "\""}
	"\\\\" {return \\}
    }

    if {[regexp {^\\([0-2][0-7][0-7])$} $ch -> ocode]} {
	return [format %c $ocode]

    } elseif {[regexp {^\\([0-7][0-7]?)$} $ch -> ocode]} {
	return [format %c 0$ocode]

    } elseif {[regexp {^\\u([[:xdigit:]][[:xdigit:]]?[[:xdigit:]]?[[:xdigit:]]?)$} $ch -> hcode]} {
	return [format %c 0x$hcode]

    }

    return $ch
}

# ### ### ### ######### ######### #########

proc ::char::quote::tcl {ch args} {
    if {![llength $args]} { return [Tcl $ch] }
    lappend res [Tcl $ch]
    foreach ch $args { lappend res [Tcl $ch] }
    return $res
}

proc ::char::quote::Tcl {ch} {
    # Input:  A single character
    # Output: A string representing the input.
    # Properties of the output:
    # (1) Contains only ASCII characters (7bit Unicode subset).
    # (2) When embedded in a ""-quoted Tcl string in a piece of Tcl
    #     code the Tcl parser will regenerate the input character.

    # Special character?
    switch -exact -- $ch {
	"\n" {return "\\n"}
	"\r" {return "\\r"}
	"\t" {return "\\t"}
	"\\" - "\;" -
	" "  - "\"" -
	"("  - ")"  -
	"\{" - "\}" -
	"\[" - "\]" {
	    # Quote space and all the brackets as well, using octal,
	    # for easy impure list-ness.

	    scan $ch %c chcode
	    return \\[format %o $chcode]
	}
    }

    scan $ch %c chcode

    # Control character?
    if {[::string is control -strict $ch]} {
	return \\[format %o $chcode]
    }

    # Unicode beyond 7bit ASCII?
    if {$chcode > 127} {
	return \\u[format %04x $chcode]
    }

    # Regular character: Is its own representation.
    return $ch
}

# ### ### ### ######### ######### #########

proc ::char::quote::string {ch args} {
    if {![llength $args]} { return [String $ch] }
    lappend res [String $ch]
    foreach ch $args { lappend res [String $ch] }
    return $res
}

proc ::char::quote::String {ch} {
    # Input:  A single character
    # Output: A string representing the input
    # Properties of the output
    # (1) Human-readable, for use in error messages, or comments.
    # (1a) Uses only printable characters.
    # (2) NO particular properties with regard to C or Tcl parsers.

    scan $ch %c chcode

    # Map the ascii control characters to proper names.
    if {($chcode <= 32) || ($chcode == 127)} {
	variable strmap
	return [dict get $strmap $chcode]
    }

    # Printable ascii characters represent themselves.
    if {$chcode < 128} {
	return $ch
    }

    # Unicode characters. Mostly represent themselves, except if
    # control or not printable. Then they are represented by their
    # codepoint.

    # Control characters: Octal
    if {[::string is control -strict $ch] ||
	![::string is print -strict $ch]} {
	return <U+[format %04x $chcode]>
    }

    return $ch
}

namespace eval ::char::quote {
    variable strmap {
	0 <NUL>  8 <BS>   16 <DLE> 24 <CAN>  32 <SPACE>
	1 <SOH>  9 <TAB>  17 <DC1> 25 <EM>  127 <DEL>
	2 <STX> 10 <LF>   18 <DC2> 26 <SUB>
	3 <ETX> 11 <VTAB> 19 <DC3> 27 <ESC>
	4 <EOT> 12 <FF>   20 <DC4> 28 <FS>
	5 <ENQ> 13 <CR>   21 <NAK> 29 <GS>
	6 <ACK> 14 <SO>   22 <SYN> 30 <RS>
	7 <BEL> 15 <SI>   23 <ETB> 31 <US>
    }
}

# ### ### ### ######### ######### #########

proc ::char::quote::cstring {ch args} {
    if {![llength $args]} { return [CString $ch] }
    lappend res [CString $ch]
    foreach ch $args { lappend res [CString $ch] }
    return $res
}

proc ::char::quote::CString {ch} {
    # Input:  A single character
    # Output: A string representing the input.
    # Properties of the output:
    # (1) Contains only ASCII characters (7bit Unicode subset).
    # (2) When embedded in a ""-quoted C string in a piece of
    #     C code the C parser will regenerate the input character
    #     in UTF-8 encoding.

    # Special characters (named).
    switch -exact -- $ch {
	"\n" {return "\\n"}
	"\r" {return "\\r"}
	"\t" {return "\\t"}
	"\"" - "\\" {
	    return \\$ch
	}
    }

    scan $ch %c chcode

    # Control characters: Octal
    if {[::string is control -strict $ch]} {
	return \\[format %o $chcode]
    }

    # Beyond 7-bit ASCII: Unicode
    if {$chcode > 127} {
	# Recode the character into the sequence of utf-8 bytes and
	# convert each to octal.
	foreach x [split [encoding convertto utf-8 $ch] {}] {
	    scan $x %c x
	    append res \\[format %o $x]
	}
	return $res
    }

    # Regular character: Is its own representation.

    return $ch
}

# ### ### ### ######### ######### #########

proc ::char::quote::comment {ch args} {
    if {![llength $args]} { return [Comment $ch] }
    lappend res [Comment $ch]
    foreach ch $args { lappend res [Comment $ch] }
    return $res
}

proc ::char::quote::Comment {ch} {
    # Converts a Tcl character (internal representation) into a string
    # which is accepted by the Tcl parser when used within a Tcl
    # comment.

    # Special characters

    switch -exact -- $ch {
	" "  {return "<blank>"}
	"\n" {return "\\n"}
	"\r" {return "\\r"}
	"\t" {return "\\t"}
	"\"" -
	"\{" - "\}" -
	"("  - ")"  {
	    return \\$ch
	}
    }

    scan $ch %c chcode

    # Control characters: Octal
    if {[::string is control -strict $ch]} {
	return \\[format %o $chcode]
    }

    # Beyond 7-bit ASCII: Unicode

    if {$chcode > 127} {
	return \\u[format %04x $chcode]
    }

    # Regular character: Is its own representation.

    return $ch
}

# ### ### ### ######### ######### #########
## Ready

package provide char 1.0.1
