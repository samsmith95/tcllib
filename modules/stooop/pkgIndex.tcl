# Copyright (c) 2001 by Jean-Luc Fontaine <jfontain@free.fr>.
# This code may be distributed under the same terms as Tcl.
#
# $Id: pkgIndex.tcl,v 1.3 2001/12/19 11:59:23 jfontain Exp $

# Since stooop redefines the proc command and the default package facility will
# only load the stooop package at the first unknown command, proc being
# obviously known by default, forcing the loading of stooop is mandatory prior
# to the first proc declaration.

package ifneeded stooop 4.3 [list source [file join $dir stooop.tcl]]

# the following package index instruction was generated using:
#   "tclsh mkpkgidx.tcl switched switched.tcl"
# (comment out the following line if you do not want to use the switched class
# as a package)
package ifneeded switched 2.2 [list tclPkgSetup $dir switched 2.2 {{switched.tcl source {::switched::_copy ::switched::cget ::switched::complete ::switched::configure ::switched::description ::switched::descriptions ::switched::options ::switched::switched ::switched::~switched}}}]
