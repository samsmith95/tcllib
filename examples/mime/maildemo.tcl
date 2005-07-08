# maildemo.tcl - Copyright (C) 2005 Pat Thoyts <patthoyts@users.sf.net>
# 
# This program illustrates the steps required to compose a MIME message and 
# mail it to a recipient using the tcllib mime and smtp packages.
#
# If we can find suitable environment variables we will authenticate with a
# server (if it presents this option) and we will use SSL communications
# if available.
#
# $Id: maildemo.tcl,v 1.1 2005/06/16 00:36:08 patthoyts Exp $

package require mime
package require smtp

# The use of SSL by our client can be controlled by a policy procedure. Using
# this we can specify that we REQUIRE SSL or we can make SSL optional.
# This procedure should return 'secure' to require SSL
#
proc policy {demoarg code diagnostic} {
    if {$code > 299} {
        puts stderr "TLS error: $code $diagnostic"
    }
    #return secure;                      # fail if no TLS
    return insecure;
}

# Setup default sender and target
set DEFUSER tcllib-demo@[info host]
set USERNAME $tcl_platform(user)
set PASSWORD ""

# Try and lift authentication details from the environment. This looks for
# some Windows NT-suitable details like the NT domain.
if {[info exists env(USERNAME)]} {
    set USERNAME $env(USERNAME)
    if {[info exists env(USERDOMAIN)]} {
        set USERNAME $env(USERDOMAIN)\\$USERNAME
    }
}

# We can get the password from http_proxy - maybe.
if {[info exists env(http_proxy_passwd)]} {
    set PASSWORD $env(http_proxy_passwd)
}

set defmsg "This is a default tcllib demo mail message."

# Compose and send a message. Command parameters can override the settings 
# discovered above.
#
proc Send [list \
               [list server localhost] \
               [list port 25] \
               [list from $DEFUSER] \
               [list to   $DEFUSER] \
               [list msg  $defmsg]] {
    set tok [mime::initialize -canonical text/plain -string $msg]
    set args [list \
                  -debug 1 \
                  -servers   [list $server] \
                  -ports     [list $port] \
                  -usetls    1 \
                  -tlspolicy [list policy $tok] \
                  -header    [list From "$from"] \
                  -header    [list To "$to"] \
                  -header    [list Subject "RFC 2554 test"] \
                  -header    [list Date "[clock format [clock seconds]]"]]
    if {[info exists ::USERNAME] && [string length $::USERNAME] > 0} {
        lappend args \
            -username  $::USERNAME \
            -password  $::PASSWORD
    }

    eval [linsert $args 0 smtp::sendmessage $tok]    
    mime::finalize $tok
}

if {!$tcl_interactive} {
    eval [linsert $argv 0 Send]
}