# pkgIndex.tcl                                                -*- tcl -*-
# Copyright (C) 2005 Pat Thoyts <patthoyts@users.sourceforge.net>
# $Id: pkgIndex.tcl,v 1.6 2006/04/26 09:05:11 patthoyts Exp $
if {![package vsatisfies [package provide Tcl] 8.2]} {
    # PRAGMA: returnok
    return
}
package ifneeded SASL 1.2.0 [list source [file join $dir sasl.tcl]]
package ifneeded SASL::NTLM 1.0.0 [list source [file join $dir ntlm.tcl]]
package ifneeded SASL::XGoogleToken 1.0.0 [list source [file join $dir gtoken.tcl]]
