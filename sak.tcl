#!/bin/sh
# -*- tcl -*- \
exec tclsh "$0" ${1+"$@"}

# --------------------------------------------------------------
# Perform various checks and operations on the distribution.
# SAK = Swiss Army Knife.

set distribution   [file dirname [info script]]
lappend auto_path  [file join $distribution modules]

source [file join $distribution tcllib_version.tcl] ; # Get version information.

catch {eval file delete -force [glob [file rootname [info script]].tmp.*]}

# --------------------------------------------------------------

proc tclfiles {} {
    global distribution
    package require fileutil
    set fl [fileutil::findByPattern $distribution -glob *.tcl]
    proc tclfiles {} [list return $fl]
    return $fl
}

proc modtclfiles {modules} {
    global mfiles guide
    load_modinfo
    set mfiles [list]
    foreach m $modules {
	eval $guide($m,pkg) $m __dummy__
    }
    return $mfiles
}


proc modules {} {
    global distribution
    set fl [list]
    foreach f [glob -nocomplain [file join $distribution modules *]] {
	if {![file isdirectory $f]} {continue}
	if {[string match CVS [file tail $f]]} {continue}

	if {![file exists [file join $f pkgIndex.tcl]]} {continue}

	lappend fl [file tail $f]
    }
    set fl [lsort $fl]
    proc modules {} [list return $fl]
    return $fl
}

proc modules_mod {m} {
    return [expr {[lsearch -exact [modules] $m] > 0}]
}

proc load_modinfo {} {
    global distribution modules guide
    source [file join $distribution installed_modules.tcl] ; # Get list of installed modules.
    source [file join $distribution install_action.tcl] ; # Get list of installed modules.
    proc load_modinfo {} {}
    return
}

proc imodules {} {global modules ; load_modinfo ; return $modules}

proc imodules_mod {m} {
    global modules
    load_modinfo
    return [expr {[lsearch -exact $modules $m] > 0}]
}


proc loadpkglist {fname} {
    set f [open $fname r]
    foreach line [split [read $f] \n] {
	foreach {n v} $line break
	set p($n) $v
    }
    close $f
    return [array get p]
}

proc ipackages {args} {
    # Determine indexed packages (ifneeded, pkgIndex.tcl)

    global distribution

    if {[llength $args] == 0} {set args [modules]}

    array set p {}
    foreach m $args {
	set f [open [file join $distribution modules $m pkgIndex.tcl] r]
	foreach line [split [read $f] \n] {
	    if { [regexp {#}        $line]} {continue}
	    if {![regexp {ifneeded} $line]} {continue}
	    regsub {^.*ifneeded } $line {} line
	    regsub {([0-9]) \[.*$}  $line {\1} line

	    foreach {n v} $line break
	    set p($n) $v
	}
	close $f
    }
    return [array get p]
}


proc ppackages {args} {
    # Determine provided packages (provide, *.tcl - pkgIndex.tcl)

    global    p pf currentfile
    array set p {}

    if {[llength $args] == 0} {
	set files [tclfiles]
    } else {
	set files [modtclfiles $args]
    }

    foreach f $files {
	# We ignore package indices and all files not in a module.

	if {[string equal pkgIndex.tcl [file tail $f]]} {continue}
	if {![regexp modules $f]}                       {continue}

	set fh [open $f r]

	# Source the code into a sub-interpreter. The sub interpreter
	# overloads 'package provide' so that the information about
	# new packages goes directly to us. We also make sure that the
	# sub interpreter doesn't kill us, and will not get stuck
	# early by trying to load other files, or when creating
	# procedures in namespaces which do not exist due to us
	# disabling most of the package management.

	set currentfile [eval file join [lrange [file split $f] end-1 end]]

	set ip [interp create]
	interp alias $ip package {} xPackage
	interp alias $ip source  {} xNULL
	interp alias $ip unknown {} xNULL
	interp alias $ip proc    {} xNULL
	interp alias $ip exit    {} xNULL
	if {[catch {$ip eval [read $fh]} msg]} {
	    #puts "ERROR in $currentfile:\n$msg\n"
	}
	close $fh
	interp delete $ip
    }

    set   pp [array get p]
    unset p
    return $pp 
}

proc xNULL    {args} {}
proc xPackage {cmd args} {

    if {[string equal $cmd provide]} {
	global p pf currentfile
	foreach {n v} $args break

	# No version specified, this is an inquiry, we ignore these.
	if {$v == {}} {return}

	set p($n) $v
	set pf($n) $currentfile
    }
    return
}



proc sep {} {puts ~~~~~~~~~~~~~~~~~~~~~~~~}

proc gendoc {fmt ext args} {
    global distribution
    global tcl_platform

    set null 0
    if {![string compare $fmt null]} {set null 1}
    if {[llength $args] == 0} {set args [modules]}

    set mpe [file join $distribution modules doctools mpexpand]
    if {$tcl_platform(platform) != "unix"} {
        set mpe [list [info nameofexecutable] $mpe]
    }
    set ::env(TCLLIBPATH) [file join $distribution modules]

    if {!$null} {
	file mkdir [file join doc $fmt]
    }

    foreach m $args {
	set fl [glob -nocomplain [file join $distribution modules $m *.man]]
	if {[llength $fl] == 0} {continue}

	if {$null} {
	    set tmp    [open [set tmpname [file rootname [info script]].tmp.[pid]] w]
	    set target -
	    set stdout $tmp
	    set stderr $tmp
	} else {
	    set stdout stdout
	    set stderr stderr
	}
	foreach f $fl {
	    if {!$null} {
                set target [file join doc $fmt \
                                [file rootname [file tail $f]].$ext]
                if {[file exists $target] 
                    && [file mtime $target] > [file mtime $f]} {
                    continue
                }
	    }
	    puts "Gen ($fmt): $f"

	    set     cmd $mpe
	    lappend cmd -module $m
	    if {$null} {lappend cmd -deprecated}
	    lappend cmd $fmt $f $target >@ $stdout 2>@ $stderr
	    if {[catch {
		eval exec $cmd
	    } msg]} {
		puts $msg
	    }
	}
	if {$null} {
	    catch {close $tmp}
	    catch {file delete -force $tmpname}
	}
    }
}

proc gd-cleanup {} {
    global tcllib_version

    puts {Cleaning up...}

    set        fl [glob -nocomplain tcllib-${tcllib_version}*]
    foreach f $fl {
	puts "    Deleting $f ..."
	catch {file delete -force $f}
    }
    return
}

proc gd-gen-archives {} {
    global tcllib_version

    puts {Generating archives...}

    set tar [auto_execok tar]
    if {$tar != {}} {
        puts "    Gzipped tarball (tcllib-${tcllib_version}.tar.gz)..."
        catch {
            exec $tar cf - tcllib-${tcllib_version} | gzip --best > tcllib-${tcllib_version}.tar.gz
        }

        set bzip [auto_execok bzip2]
        if {$bzip != {}} {
            puts "    Bzipped tarball (tcllib-${tcllib_version}.tar.bz2)..."
            exec tar cf - tcllib-${tcllib_version} | bzip2 > tcllib-${tcllib_version}.tar.bz2
        }
    }

    set zip [auto_execok zip]
    if {$zip != {}} {
        puts "    Zip archive     (tcllib-${tcllib_version}.zip)..."
        catch {
            exec $zip -r   tcllib-${tcllib_version}.zip             tcllib-${tcllib_version}
        }
    }

    set sdx [auto_execok sdx]
    if {$sdx != {}} {
	file rename tcllib-${tcllib_version} tcllib.vfs

	puts "    Starkit         (tcllib-${tcllib_version}.kit)..."
	exec sdx wrap tcllib
	file rename   tcllib tcllib-${tcllib_version}.kit

	if {![file exists tclkit]} {
	    puts "    No tclkit present in current working directory, no starpack."
	} else {
	    puts "    Starpack        (tcllib-${tcllib_version}.exe)..."
	    exec sdx wrap tcllib -runtime tclkit
	    file rename   tcllib tcllib-${tcllib_version}.exe
	}

	file rename tcllib.vfs tcllib-${tcllib_version}
    }

    puts {    Keeping directory for other archive types}

    ## Keep the directory for 'sdx' - kit/pack
    return
}

proc xcopyfile {src dest} {
    # dest can be dir or file
    global  mfiles
    lappend mfiles $src
    return
}

proc xcopy {src dest recurse {pattern *}} {
    foreach file [glob [file join $src $pattern]] {
        set base [file tail $file]
	set sub  [file join $dest $base]
	if {0 == [string compare CVS $base]} {continue}
        if {[file isdirectory $file]} then {
	    if {$recurse} {
		xcopy $file $sub $recurse $pattern
	    }
        } else {
            xcopyfile $file $sub
        }
    }
}


proc xxcopy {src dest recurse {pattern *}} {
    file mkdir $dest
    foreach file [glob -nocomplain [file join $src $pattern]] {
        set base [file tail $file]
	set sub  [file join $dest $base]

	# Exclude CVS automatically, and possibly the temp hierarchy
	# itself too.

	if {0 == [string compare CVS $base]} {continue}
	if {[string match tcllib-*   $base]} {continue}
	if {[string match *~         $base]} {continue}

        if {[file isdirectory $file]} then {
	    if {$recurse} {
		file mkdir  $sub
		xxcopy $file $sub $recurse $pattern
	    }
        } else {
	    puts -nonewline stdout . ; flush stdout
            file copy -force $file $sub
        }
    }
}

proc gd-assemble {} {
    global tcllib_version distribution

    puts "Assembling distribution in directory 'tcllib-${tcllib_version}'"

    xxcopy $distribution tcllib-${tcllib_version} 1
    file delete -force \
	    tcllib-${tcllib_version}/config \
	    tcllib-${tcllib_version}/modules/ftp/example \
	    tcllib-${tcllib_version}/modules/ftpd/examples \
	    tcllib-${tcllib_version}/modules/stats \
	    tcllib-${tcllib_version}/modules/fileinput
    puts ""
    return
}

proc gd-gen-tap {} {
    package require textutil
    package require fileutil
    global tcllib_name tcllib_version distribution tcl_platform

    set modules [imodules]
    set     lines [list]
    # Header
    lappend lines {format  {TclDevKit Project File}}
    lappend lines {fmtver  2.0}
    lappend lines {fmttool {TclDevKit TclApp PackageDefinition} 2.5}
    lappend lines {}
    lappend lines "##  Saved at : [clock format [clock seconds]]"
    lappend lines "##  By       : $tcl_platform(user)"
    lappend lines {##}
    lappend lines "##  Generated by \"[file tail [info script]] tap\""
    lappend lines "##  of $tcllib_name $tcllib_version"
    lappend lines {}
    lappend lines {########}
    lappend lines {#####}
    lappend lines {###}
    lappend lines {##}
    lappend lines {#}

    # Bundle definition
    lappend lines {}
    lappend lines {# ###############}
    lappend lines {# Complete bundle}
    lappend lines {}
    lappend lines [list Package [list $tcllib_name $tcllib_version]]
    lappend lines "Base     @TAP_DIR@"
    lappend lines "Platform *"
    lappend lines "Desc     {Tcllib: Bundle of all packages}"
    lappend lines "Path     pkgIndex.tcl"
    lappend lines "Path     [join $modules "\nPath     "]"

    set  strip [llength [file split $distribution]]
    incr strip 2

    foreach m $modules {
	# File set of module ...

	lappend lines {}
	lappend lines "# #########[::textutil::strRepeat {#} [string length $m]]" ; # {}
	lappend lines "# Module \"$m\""
	set n 0
	foreach {p v} [ppackages $m] {
	    lappend lines "# \[[format %1d [incr n]]\]    | \"$p\""
	}
	lappend lines "# -------+"
	lappend lines {}
	lappend lines [list Package [list __$m 0.0]]
	lappend lines "Platform *"
	lappend lines "Desc     {Tcllib module}"
	lappend lines Hidden
	lappend lines "Base     @TAP_DIR@/$m"

	foreach f [modtclfiles $m] {
	    lappend lines "Path     [fileutil::stripN $f $strip]"
	}

	# Packages in the module ...
	foreach {p v} [ppackages $m] {
	    lappend lines {}
	    lappend lines [list Package [list $p $v]]
	    lappend lines "See   [list __$m]"
	    lappend lines "Platform *"
	    lappend lines "Desc     {Tcllib package}"
	}
	lappend lines {}
	lappend lines {#}
	lappend lines "# #########[::textutil::strRepeat {#} [string length $m]]"
    }

    lappend lines {}
    lappend lines {#}
    lappend lines {##}
    lappend lines {###}
    lappend lines {#####}
    lappend lines {########}

    # Write definition
    set    f [open [file join $distribution tcllib.tap] w]
    puts  $f [join $lines \n]
    close $f
    return
}


proc gd-tip55 {} {
    global tcllib_version tcllib_name distribution contributors
    contributors

    set md {Identifier: %N
Title:  Tcl Standard Library
Description: This package is intended to be a collection of
    Tcl packages that provide utility functions useful to a
    large collection of Tcl programmers.
Rights: BSD
Version: %V
URL: http://tcllib.sourceforge.net/
Architecture: tcl
}

    regsub {Version: %V} $md "Version: $tcllib_version" md
    regsub {Identifier: %N} $md "Identifier: $tcllib_name" md
    foreach person [lsort [array names contributors]] {
        set mail $contributors($person)
        regsub {@}  $mail " at " mail
        regsub -all {\.} $mail " dot " mail
        append md "Contributor: $person <$mail>\n"
    }

    set f [open [file join $distribution DESCRIPTION.txt] w]
    puts $f $md
    close $f
}

# Fill the global array of contributors to tcllib by processing the
# ChangeLog entries.
#
proc contributors {} {
    global distribution contributors
    if {![info exists contributors] || [array size contributors] == 0} {
        get_contributors [file join $distribution ChangeLog]

        foreach f [glob -nocomplain [file join $distribution modules *]] {
            if {![file isdirectory $f]} {continue}
            if {[string match CVS [file tail $f]]} {continue}
            if {![file exists [file join $f ChangeLog]]} {continue}
            get_contributors [file join $f ChangeLog]
        }
    }
}

proc get_contributors {changelog} {
    global contributors
    set f [open $changelog r]
    while {![eof $f]} {
        gets $f line
        if {[regexp {^[\d-]+\s+(.*?)<(.*?)>} $line r name mail]} {
            set name [string trim $name]
            if {![info exists names($name)]} {
                set contributors($name) $mail
            }
        }
    }
    close $f
}

proc validate_imodules_cmp {imvar dmvar} {
    upvar $imvar im $dmvar dm

    foreach m [lsort [array names im]] {
	if {![info exists dm($m)]} {
	    puts "  Installed, does not exist: $m"
	}
    }
    foreach m [lsort [array names dm]] {
	if {![info exists im($m)]} {
	    puts "  Missing in installer:      $m"
	}
    }
    return
}

proc validate_imodules {} {
    foreach m [imodules] {set im($m) .}
    foreach m [modules]  {set dm($m) .}

    validate_imodules_cmp im dm
    return
}

proc validate_imodules_mod {m} {
    array set im {}
    array set dm {}
    if {[imodules_mod $m]} {set im($m) .}
    if {[modules_mod  $m]} {set dm($m) .}

    validate_imodules_cmp im dm
    return
}
proc validate_versions_cmp {ipvar ppvar} {
    upvar $ipvar ip $ppvar pp
    set maxl 0
    foreach name [array names ip] {if {[string length $name] > $maxl} {set maxl [string length $name]}}
    foreach name [array names pp] {if {[string length $name] > $maxl} {set maxl [string length $name]}}

    foreach p [lsort [array names ip]] {
	if {![info exists pp($p)]} {
	    puts "  Indexed, no provider:           $p"
	}
    }
    foreach p [lsort [array names pp]] {
	if {![info exists ip($p)]} {
	    puts "  Provided, not indexed:          [format "%-*s | %s" $maxl $p $::pf($p)]"
	}
    }
    foreach p [lsort [array names ip]] {
	if {
	    [info exists pp($p)] && ![string equal $pp($p) $ip($p)]
	} {
	    puts "  Index/provided versions differ: [format "%-*s | %8s | %8s" $maxl $p $ip($p) $pp($p)]"
	}
    }
}

proc validate_versions {} {
    foreach {p v} [ipackages] {set ip($p) $v}
    foreach {p v} [ppackages] {set pp($p) $v}

    validate_versions_cmp ip pp
    return
}

proc validate_versions_mod {m} {
    foreach {p v} [ipackages $m] {set ip($p) $v}
    foreach {p v} [ppackages $m] {set pp($p) $v}

    validate_versions_cmp ip pp
    return
}

proc validate_testsuite_mod {m} {
    global distribution
    if {[llength [glob -nocomplain [file join $distribution modules $m *.test]]] == 0} {
	puts "  Without testsuite : $m"
    }
    return
}

proc validate_testsuites {} {
    foreach m [modules] {
	validate_testsuite_mod $m
    }
    return
}

proc validate_pkgIndex_mod {m} {
    global distribution
    if {[llength [glob -nocomplain [file join $distribution modules $m pkgIndex.tcl]]] == 0} {
	puts "  Without package index : $m"
    }
    return
}

proc validate_pkgIndex {} {
    global distribution
    foreach m [modules] {
	validate_pkgIndex_mod $m
    }
    return
}

proc validate_doc_existence_mod {m} {
    global distribution
    if {[llength [glob -nocomplain [file join $distribution modules $m {*.[13n]}]]] == 0} {
	if {[llength [glob -nocomplain [file join $distribution modules $m {*.man}]]] == 0} {
	    puts "  Without * any ** manpages : $m"
	}
    } elseif {[llength [glob -nocomplain [file join $distribution modules $m {*.man}]]] == 0} {
	puts "  Without doctools manpages : $m"
    } else {
	foreach f [glob -nocomplain [file join $distribution modules $m {*.[13n]}]] {
	    if {![file exists [file rootname $f].man]} {
		puts "     no .man equivalent : $f"
	    }
	}
    }
    return
}

proc validate_doc_existence {} {
    global distribution
    foreach m [modules] {
	validate_doc_existence_mod $m
    }
    return
}


proc validate_doc_markup_mod {m} {
    gendoc null null $m
    return
}

proc validate_doc_markup {} {
    gendoc null null
    return
}


proc run-frink {args} {
    global distribution

    set tmp [file rootname [info script]].tmp.[pid]

    if {[llength $args] == 0} {
	set files [tclfiles]
    } else {
	set files [modtclfiles $args]
    }

    foreach f $files {
	puts "FRINK ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	puts "$f..."
	puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

	catch {exec frink 2> $tmp -H $f}
	set data [get_input $tmp]
	if {[string length $data] > 0} {
	    puts $data
	}
    }
    catch {file delete -force $tmp}
    return
}

proc run-procheck {args} {
    global distribution

    if {[llength $args] == 0} {
	set files [tclfiles]
    } else {
	set files [modtclfiles $args]
    }

    foreach f $files {
	puts "PROCHECK ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
	puts "$f ..."
	puts "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

	catch {exec procheck >@ stdout $f}
    }
    return
}

proc get_input {f} {return [read [set if [open $f r]]][close $if]}

# --------------------------------------------------------------
# Help

proc __help {} {
    puts stdout {
	Commands avalable through the swiss army knife aka SAK:

	help     - This help

	/Configuration
	version  - Return tcllib version number
	major    - Return tcllib major version number
	minor    - Return tcllib minor version number
	name     - Return tcllib package name

	/Development
	modules          - Return list of modules.
        contributors     - Print a list of contributors to tcllib.
	lmodules         - See above, however one module per line
	imodules         - Return list of modules known to the installer.

	packages         - Return indexed packages in tcllib, plus versions,
	                   one package per line. Extracted from the
	                   package indices found in the modules.
	provided         - Return list and versions of provided packages
	                   (in contrast to indexed).
	vcompare pkglist - Compare package list of previous 'packages'
	                   call with current packages. Marks all new
	                   and unchanged packages for higher attention.

        validate ?module..?     - Check listed modules for problems.
                                  For all modules if none specified.

	test ?module...?        - Run testsuite for listed modules.
	                          For all modules if none specified.

	/Release engineering
	gendist  - Generate distribution from CVS snapshot
        gentip55 - Generate a TIP55-style DESCRIPTION.txt file.

	/Documentation
	nroff ?module...?    - Generate manpages
	html  ?module...?    - Generate HTML pages
	tmml  ?module...?    - Generate TMML
	text  ?module...?    - Generate plain text
	list  ?module...?    - Generate a list of manpages
	wiki  ?module...?    - Generate wiki markup
	latex ?module...?    - Generate LaTeX pages
	dvi   ?module...?    - See latex, + conversion to dvi
	ps    ?module...?    - See dvi,   + conversion to PostScript
    }
}

# --------------------------------------------------------------
# Configuration

proc __name    {} {global tcllib_name    ; puts $tcllib_name}
proc __version {} {global tcllib_version ; puts $tcllib_version}
proc __minor   {} {global tcllib_version ; puts [lindex [split $tcllib_version .] 1]}
proc __major   {} {global tcllib_version ; puts [lindex [split $tcllib_version .] 0]}

# --------------------------------------------------------------
# Development

proc __imodules {}  {puts [imodules]}
proc __modules {}  {puts [modules]}
proc __lmodules {} {puts [join [modules] \n]}


proc nparray {a} {
    upvar $a packages

    set maxl 0
    foreach name [lsort [array names packages]] {
        if {[string length $name] > $maxl} {
            set maxl [string length $name]
        }
    }
    foreach name [lsort [array names packages]] {
        puts stdout [format "%-*s %s" $maxl $name $packages($name)]
    }
    return
}

proc __packages {} {
    array set packages [ipackages]
    nparray packages
    return
}

proc __provided {} {
    array set packages [ppackages]
    nparray packages
    return
}


proc __vcompare {} {
    global argv
    set oldplist [lindex $argv 0]

    array set curpkg [ipackages]
    array set oldpkg [loadpkglist $oldplist]

    foreach p [array names curpkg] {set __($p) .}
    foreach p [array names oldpkg] {set __($p) .}
    set unified [lsort [array names __]]
    unset __

    set maxl 0
    foreach name $unified {
        if {[string length $name] > $maxl} {
            set maxl [string length $name]
        }
    }
    foreach name $unified {
	set suffix ""
	if {![info exists curpkg($name)]} {set curpkg($name) "--"}
	if {![info exists oldpkg($name)]} {set oldpkg($name)   "--" ; append suffix " NEW"}
	if {[string equal $oldpkg($name) $curpkg($name)]} {append suffix " \t<<<"}
        puts stdout [format "%-*s %-*s %-*s" $maxl $name 8 $oldpkg($name) 8 $curpkg($name)]$suffix
    }
    return
}



proc __test {} {
    global argv distribution
    # Run testsuite

    set modules $argv
    if {[llength $modules] == 0} {
	set modules [modules]
    }

    exec [info nameofexecutable] \
	    [file join $distribution all.tcl] \
	    -modules $modules \
	    >@ stdout 2>@ stderr
    return
}

proc checkmod {} {
    global argv
    set fail 0
    foreach m $argv {
	if {![modules_mod $m]} {
	    puts "  Bogus module: $m"
	    set fail 1
	}
    }
    if {$fail} {
	puts "  Stop."
	return 0
    }
    return 1
}

proc __validate {} {
    global argv
    if {[llength $argv] == 0} {
	_validate_all
    } else {
	if {![checkmod]} {return}
	foreach m $argv {
	    _validate_module $m
	}
    }
    return
}

proc _validate_all {} {
    global tcllib_name tcllib_version
    set i 0

    puts "Validating $tcllib_name $tcllib_version development"
    puts "==================================================="
    puts "[incr i]: Existence of testsuites ..."
    puts "------------------------------------------------------"
    validate_testsuites
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Existence of package indices ..."
    puts "------------------------------------------------------"
    validate_pkgIndex
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Consistency of package versions ..."
    puts "------------------------------------------------------"
    validate_versions
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Installed vs. developed modules ..."
    puts "------------------------------------------------------"
    validate_imodules
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Existence of documentation ..."
    puts "------------------------------------------------------"
    validate_doc_existence
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Validate documentation markup (doctools) ..."
    puts "------------------------------------------------------"
    validate_doc_markup
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Static syntax check ..."
    puts "------------------------------------------------------"

    set frink    [auto_execok frink]
    set procheck [auto_execok procheck]

    if {$frink    == {}} {puts "  Tool 'frink'    not found, no check"}
    if {$procheck == {}} {puts "  Tool 'procheck' not found, no check"}
    if {($frink == {}) || ($procheck == {})} {
	puts "------------------------------------------------------"
    }
    if {($frink == {}) && ($procheck == {})} {
	return
    }
    if {$frink    != {}} {
	run-frink
	puts "------------------------------------------------------"
    }
    if {$procheck    != {}} {
	run-procheck
	puts "------------------------------------------------------"
    }
    puts ""

    return
}

proc _validate_module {m} {
    global tcllib_name tcllib_version
    set i 0

    puts "Validating $tcllib_name $tcllib_version development -- $m"
    puts "==================================================="
    puts "[incr i]: Existence of testsuites ..."
    puts "------------------------------------------------------"
    validate_testsuite_mod $m
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Existence of package indices ..."
    puts "------------------------------------------------------"
    validate_pkgIndex_mod $m
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Consistency of package versions ..."
    puts "------------------------------------------------------"
    validate_versions_mod $m
    puts "------------------------------------------------------"
    puts ""

    #puts "[incr i]: Installed vs. developed modules ..."
    puts "------------------------------------------------------"
    validate_imodules_mod $m
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Existence of documentation ..."
    puts "------------------------------------------------------"
    validate_doc_existence_mod $m
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Validate documentation markup (doctools) ..."
    puts "------------------------------------------------------"
    validate_doc_markup_mod $m
    puts "------------------------------------------------------"
    puts ""

    puts "[incr i]: Static syntax check ..."
    puts "------------------------------------------------------"

    set frink    [auto_execok frink]
    set procheck [auto_execok procheck]

    if {$frink    == {}} {puts "  Tool 'frink'    not found, no check"}
    if {$procheck == {}} {puts "  Tool 'procheck' not found, no check"}
    if {($frink == {}) || ($procheck == {})} {
	puts "------------------------------------------------------"
    }
    if {($frink == {}) && ($procheck == {})} {
	return
    }
    if {$frink    != {}} {
	run-frink $m
	puts "------------------------------------------------------"
    }
    if {$procheck    != {}} {
	run-procheck $m
	puts "------------------------------------------------------"
    }
    puts ""

    return
}

# --------------------------------------------------------------
# Release engineering

proc __gendist {} {
    gd-cleanup
    gd-tip55
    gd-assemble
    gd-gen-archives

    puts ...Done
    return
}

proc __gentip55 {} {
    gd-tip55
    puts "Created DESCRIPTION.txt"
    return
}

proc __contributors {} {
    global contributors
    contributors
    foreach person [lsort [array names contributors]] {
        puts "$person <$contributors($person)>"
    }
    return
}

proc __tap {} {
    gd-gen-tap
    puts "Created Tcl Dev Kit \"tcllib.tap\""
}


# --------------------------------------------------------------
# Documentation

proc __html  {} {global argv ; if {![checkmod]} return ; eval gendoc html  html $argv}
proc __nroff {} {global argv ; if {![checkmod]} return ; eval gendoc nroff n    $argv}
proc __tmml  {} {global argv ; if {![checkmod]} return ; eval gendoc tmml  tmml $argv}
proc __text  {} {global argv ; if {![checkmod]} return ; eval gendoc text  txt  $argv}
proc __wiki  {} {global argv ; if {![checkmod]} return ; eval gendoc wiki  wiki $argv}
proc __latex {} {global argv ; if {![checkmod]} return ; eval gendoc latex tex  $argv}
proc __dvi   {} {
    global argv ; if {![checkmod]} return
    __latex
    file mkdir [file join doc dvi]
    cd         [file join doc dvi]
    foreach f [glob -nocomplain ../latex/*.tex] {
	puts "Gen (dvi): $f"
	exec latex $f 1>@ stdout 2>@ stderr
    }
    cd ../..
}
proc __ps   {} {
    global argv ; if {![checkmod]} return
    __dvi
    file mkdir [file join doc ps]
    cd         [file join doc ps]
    foreach f [glob -nocomplain ../dvi/*.dvi] {
	puts "Gen (dvi): $f"
	exec dvips -o [file rootname [file tail $f]].ps $f 1>@ stdout 2>@ stderr
    }
    cd ../..
}

proc __list  {} {
    global argv ; if {![checkmod]} return
    eval gendoc list l $argv
    
    set FILES [glob -nocomplain doc/list/*.l]
    set LIST [open [file join doc list manpages.tcl] w]

    foreach file $FILES {
        set f [open $file r]
        puts $LIST [read $f]
        close $f
    }
    close $LIST

    eval file delete -force $FILES

    return
}

# --------------------------------------------------------------

set cmd [lindex $argv 0]
if {[llength [info procs __$cmd]] == 0} {
    puts stderr "unknown command $cmd"
    set fl {}
    foreach p [lsort [info procs __*]] {
	lappend fl [string range $p 2 end]
    }
    puts stderr "use: [join $fl ", "]"
    exit 1
}

set  argv [lrange $argv 1 end]
incr argc -1

__$cmd
exit 0
