# Umbrella, i.e. Bundle, to put all of the critcl modules which are
# found in Tcllib in one shared library.

package require critcl
package provide tcllibc 0.3.2

namespace eval ::tcllib {
    variable tcllibc_rcsid {$Id: tcllibc.tcl,v 1.7 2007/08/29 22:10:30 andreas_kupries Exp $}
    critcl::ccode {
        /* no code required in this file */
    }
}
