#
#   YAML parser for Tcl.
#
#   See http://www.yaml.org/spec/1.1/
#
#   yaml.tcl,v 0.3.0 2008-06-01 22:28:28 KATO Kanryu(k.kanryu@gmail.com)
#
#   It is published with the terms of tcllib's BSD-style license.
#   See the file named license.terms.
#
# It currently supports a very limited subsection of the YAML spec.
#
#

if {$::tcl_version < 8.5} {
    package require dict
}

package provide yaml 0.3.0
package require cmdline
package require huddle


namespace eval ::yaml {
    namespace export load setOptions dict2dump list2dump
    variable data
    array set data {}

    # fixed value groups for some yaml-types.
    variable fixed

    # a plane scalar is worked for matching and converting to the specific type.
    # proc some_command {value} {
    #   return [list !!type $treatmented-value]
    #     or
    #   return ""
    # }
    variable parsers
    
    # scalar/collection treatment for matched specific yaml-tag
    # proc some_composer {type value} {
    #   return [list 1 $result-type $treatmented-value]
    #     or
    #   return ""
    # }
    variable composer

    variable defaults 
    array set defaults {
        isfile   0
        validate 0
        types {timestamp int float null true false merge}
        composer {
            !!binary ::yaml::_composeBinary
        }
        parsers {
            timestamp ::yaml::_parseTimestamp
        }
        shorthands {
            !! {tag:yaml.org,2002:}
        }
        fixed {
            null:Value  ""
            null:Group  {null "" ~}
            true:Value  1
            true:Group  {true on + yes y}
            false:Value 0
            false:Group {false off - no n}
        }
    }
    
    variable _dumpIndent   2
    variable _dumpWordWrap 40

    variable opts [lrange [::cmdline::GetOptionDefaults {
        {file             {input is filename}}
        {stream           {input is stream}}
        {m.arg        ""  {fixed-modifiers bulk setting(null/true/false)}}
        {m:null.arg   ""  {null modifier setting(default {"" {null "" ~}})}}
        {m:true.arg   ""  {true modifier setting(default {1 {true on + yes y}})}}
        {m:false.arg  ""  {false modifier setting(default {0 {false off - no n}})}}
        {types.arg    ""  {modifier list setting(default {nop timestamp integer null true false})}}
        {validate         {to validate the input(not dumped tcl content)}}
    } result] 2 end] ;# Remove ? and help.

    variable errors
    array set errors {
        TAB_IN_PLAIN        {Tabs can be used only in comments, and in quoted "..." '...'.}
        AT_IN_PLAIN         {Reserved indicators {@} can't start a plain scalar.}
        BT_IN_PLAIN         {Reserved indicators {`} can't start a plain scalar.}
        SEQEND_NOT_IN_SEQ   {There is a flow-sequence end '\]' not in flow-sequence [v, ...].}
        MAPEND_NOT_IN_MAP   {There is a flow-mapping end '\}' not in flow-mapping {k: v, ...}.}
        ANCHOR_NOT_FOUND    {Could not find the anchor-name(current-version, "after refering" is not supported)}
        MALFORM_D_QUOTE     {Double quote "..." parsing error. end of quote is missing?}
        MALFORM_S_QUOTE     {Single quote '...' parsing error. end of quote is missing?}
        TAG_NOT_FOUND       {The "$p1" handle wasn't declared.}
        INVALID_MERGE_KEY   {merge-key "<<" is not impremented in not mapping scope(e.g. in sequence).}
        MALFORMED_MERGE_KEY {malformed merge-key "<<" using.}
    }
}


####################
# Public APIs
####################

proc ::yaml::load {args} {
    _getOption $args
    
    if {$yaml::data(validate)} {
        set result [_parseBlockNode]
        set result [string map "{\n} {\\n}" $result]
    } else {
        set result [_parseBlockNode]
    }
    return [huddle strip $result]
}

proc ::yaml::loadHuddle {args} {
    _getOption $args
    
    if {$yaml::data(validate)} {
        set result [_parseBlockNode]
        set result [string map "{\n} {\\n}" $result]
    } else {
        set result [_parseBlockNode]
    }
    return $result
}

proc ::yaml::setOptions {argv} {
    variable defaults
    array set options [_imp_getOptions argv]
    array set defaults [array get options]
}

# Dump TCL List to YAML
#
# TCL's interp can not treate mixed structure (list/dict/space separeted string).
# So, when really to implement the command, we should prepare library
# to express solid structures.
#
# Indent's default is 2 spaces, wordwrap's default is 40 characters.  And
# you can turn off wordwrap by passing in 0.

proc ::yaml::list2yaml {list {indent 2} {wordwrap 40}} {
    set yaml::_dumpIndent   $indent
    set yaml::_dumpWordWrap $wordwrap
    # New YAML document
    set out "---\n"
    
    # Start at the base of the array and move through it.
    foreach {value} $list {
        set out "$out[_dumpNode {} $value 0]"
    }
    return $out
}

proc ::yaml::dict2yaml {dict {indent 2} {wordwrap 40}} {
    set yaml::_dumpIndent   $indent
    set yaml::_dumpWordWrap $wordwrap
    # New YAML document
    set out "---\n"
    
    # Start at the base of the array and move through it.
    foreach {key value} $dict {
        set out "$out[_dumpNode $key $value 0]"
    }
    return $out
}

####################
# Option Setting
####################

proc ::yaml::_getOption {argv} {
    variable data
    variable parsers
    variable fixed
    variable composer

    # default setting
    array set options [_imp_getOptions argv]

    array set fixed    $options(fixed)
    array set parsers  $options(parsers)
    array set composer $options(composer)
    array set data [list validate $options(validate) types $options(types)]
    set isfile $options(isfile)
    
    foreach {buffer} $argv break
    if {$isfile} {
        set fd [open $buffer r]
        set buffer [read $fd]
        close $fd
    }
    set data(buffer) $buffer
    set data(start)  0
    set data(length) [string length $buffer]
}

proc ::yaml::_imp_getOptions {{argvvar argv}} {
    upvar 1 $argvvar argv

    variable defaults
    variable opts
    array set options [array get defaults]

    # default setting
    array set fixed $options(fixed)

    # parse argv
    set argc [llength $argv]
    while {[set err [::cmdline::getopt argv $opts opt arg]]} {
        switch -- $opt {
            "file" {
                set options(isfile) 1
            }
            "stream" {
                set options(isfile) 0
            }
            "m" {
                array set options(fixed) $arg
            }
            "validate" {
                set options(validate) 1
            }
            "types" {
                set options(types) $arg
            }
            default {
                if [regexp {m:(\w+)} $opt nop type] {
                    if {$arg eq ""} {
                        set fixed(${type}:Group) ""
                    } else {
                        foreach {value group} $arg {
                            set fixed(${type}:Value) $value
                            set fixed(${type}:Group) $group
                        }
                    }
                }
            }
        }
    }
    set options(fixed) [array get fixed]
    return [array get options]
}

#########################
# Scalar/Block Composers
#########################
proc ::yaml::_composeTags {tag value} {
    if {$tag eq ""} {return $value}
    set value [huddle strip $value]
    if {$tag eq "!!str"} {
        set pair [list $tag $value]
    } elseif [info exists yaml::composer($tag)] {
        set pair [$yaml::composer($tag) $value]
    } else {
        error [_getErrorMessage TAG_NOT_FOUND $tag]
    }
    foreach {tag value} $pair break
    return  [huddle wrap $tag $value]
}

proc ::yaml::_composeBinary {value} {
    package require base64
    return [list !!binary [::base64::decode $value]]
}

proc ::yaml::_composePlain {value} {
    if {[huddle type $value] ne "plain"} {return $value}
    set value [huddle strip $value]
    set pair [_toType $value]
    foreach {tag value} $pair break
    return  [huddle wrap $tag $value]
}

proc ::yaml::_toType {value} {
    if {$value eq ""} {return [list !!str ""]}
    
    set lowerval [string tolower $value]
    foreach {type} $yaml::data(types) {
        if [info exists yaml::parsers($type)] {
            set pair [$yaml::parsers($type) $value]
            if {$pair ne ""} {return $pair}
            continue
        }
        switch -- $type {
            int {
                # YAML 1.1
                if [regexp {^-?\d[\d,]*\d$|^\d$} $value] {
                    regsub -all "," $value "" integer
                    return [list !!int $integer]
                }
            }
            float {
                # don't run before "integer"
                regsub -all "," $value "" val
                if [string is double $val] {
                    return [list !!float $val]
                }
            }
            default {
                # !!null !!true !!false
                if {[info exists yaml::fixed($type:Group)] \
                 && [lsearch $yaml::fixed($type:Group) $lowerval] >= 0} {
                    set value $yaml::fixed($type:Value)
                    return [list !!$type $value]
                }
            }
        }
    }

    # the others
    return [list !!str $value]
}

####################
# Block Node parser
####################
proc ::yaml::_parseBlockNode {{status ""} {indent -1}} {
    set prev {}
    set result {}
    set scalar 0
    set pos 0
    set tag ""
    while {1} {
        _skipSpaces 1
        set type [_getc]
        set current [_getCurrent]
# set dd1 "$yaml::data(current) $yaml::data(start)"
        if {$type eq "-"} {
            set cc "[_getc][_getc]"
            if {"$type$cc" eq "---" && $current == 0} {
                continue
            } else {
                _ungetc 2
                
                # [Spec]
                # Since people perceive the�g-�hindicator as indentation, 
                # nested block sequences may be indented by one less space 
                # to compensate, except, of course, 
                # if nested inside another block sequence.
                incr current
            }
        }
# set dd2 "$yaml::data(current) $yaml::data(start)"
# if {$dd1 ne $dd2} {error "$dd1/$dd2"}
        if {$type eq ""  || $current <= $indent} { ; # end document
            _ungetc
            break
        }
        switch -- $type {
            "-" { ; # block sequence entry
                set pos $current
                # [196]      l-block-seq-entry(n,c)
                foreach {scalar value} [_parseSubBlock $pos "SEQUENCE"] break
            }
            "?" { ; # mapping key
                foreach {scalar nop} [_parseSubBlock $pos ""] break
            }
            ":" { ; # mapping value
                if {$current < $pos} {set pos [expr {$current+1}]}
                foreach {scalar value} [_parseSubBlock $pos "MAPPING"] break
            }
            "|" { ; # literal block scalar
                set value [_parseBlockScalar $indent "\n"]
            }
            ">" { ; # folded block scalar
                set value [_parseBlockScalar $indent " "]
            }
            "<" { ; # mergeing
                set c [_getc]
                if {"$type$c" eq "<<"} {
                    set pos [_getCurrent]
                    _skipSpaces 1
                    set c [_getc]
                    if {$c ne ":"} {error [_getErrorMessage INVALID_MERGE_KEY]}
                    if {$status ne "" && $status ne "MAPPING"} {error [_getErrorMessage INVALID_MERGE_KEY]}
                    set status "MAPPING"
                    if {$result eq ""} {set result [huddle mapping]}
                    if {$prev ne ""} {
                        if {[llength $prev] == 2} {
                            set result [_set_huddle_mapping $result $prev]
                            set prev {}
                        } else {
                            error [_getErrorMessage MALFORMED_MERGE_KEY]
                        }
                    }

                    set value [_parseBlockNode "" [expr {$pos}]]
                    # merging expanded aliases
                    if {[huddle type $value] eq "list"} {
                        set len [huddle llength $value]
                        for {set i 0} {$i < $len} {incr i} {
                            set sub [huddle get $value $i]
                            set result [huddle combine $result $sub]
                        }
                        unset sub len
                    } else {
                        set result [huddle combine $result $value]
                    }
                    unset value
                } else {
                    _ungetc
                    set scalar 1
                }
            }
            "&" { ; # node's anchor property
                set anchor [_getToken]
            }
            "*" { ; # alias node
                set alias [_getToken]
                if {$yaml::data(validate)} {
                    set status "ALIAS"
                    set value *$alias
                } else {
                    set value [_getAnchor $alias]
                }
            }
            "!" { ; # node's tag
                _ungetc
                set tag [_getToken]
            }
            "%" { ; # directive line
                _getLine
            }
            default {
                if [regexp {^[\[\]\{\}\"']$} $type] {
                    set pos [expr {1 + $current}]
                    _ungetc
                    set value [_parseFlowNode]
                } else {
                    set scalar 1
                }
            }
        }
        if {$scalar} {
            set pos [_getCurrent]
            _ungetc
            set value [_parseScalarNode $type "BLOCK" $pos]
            set value [_composeTags $tag $value]
            set tag ""
            set scalar 0
        }
        if [info exists value] {
            switch -- $status {
                "NODE" {
                    return $value
                }
                "SEQUENCE" {
                    lappend result [_composePlain $value]
                }
                "MAPPING" {
                    if [info exists prev] {
                        if {[llength $prev] == 2} {
                            set result [_set_huddle_mapping $result $prev]
                            set prev [list $value]
                        } else {
                            lappend prev $value
                        }
                    }
                }
                default {
                    lappend prev $value
                }
            }
            unset value
        }
    }
    if {$status eq "SEQUENCE"} {
        set result [eval huddle sequence $result]
    } elseif {$status eq "MAPPING"} {
        if {[llength $prev] == 2} {
            set result [_set_huddle_mapping $result $prev]
        }
    } else {
        if [info exists prev] {
            set result $prev
        }
        set result [lindex $result 0]
        set result [_composePlain $result]
        if {![huddle isHuddle $result]} {
            set result [huddle wrap !!str $result]
        }
    }
    if {$tag ne ""} {
        set result [_composeTags $tag $result]
        unset tag
    }
    if [info exists anchor] {
        _setAnchor $anchor $result
        unset anchor
    }
    return $result
}

proc ::yaml::_parseSubBlock {pos statusnew} {
    upvar 1 status status
    set scalar 0
    set value ""
    if [_next_is_blank] {
        if {$statusnew ne ""} {
            set status $statusnew
            set value [_parseBlockNode "" $pos]
        }
    } else {
        _ungetc
        set scalar 1
    }
    return [list $scalar $value]
}

proc ::yaml::_set_huddle_mapping {result prev} {
    foreach {key val} $prev break
    set val [_composePlain $val]
    if [huddle isHuddle $key] {
        set key [huddle strip $key]
    }
    if {$result eq ""} {
        set result [huddle mapping $key $val]
    } else {
        huddle append result $key $val
    }
    return $result
}


# remove duplications with saving key order
proc ::yaml::_remove_duplication {dict} {
    array set tmp $dict
    array set tmp2 {}
    foreach {key nop} $dict {
        if [info exists tmp2($key)] continue
        lappend result $key $tmp($key)
        set tmp2($key) 1
    }
    return $result
}

proc ::yaml::_doValidate {type result {param ""}} {
    foreach {type value} $result break
    return $value
}


# literal "|" (line separator is "\n")
# folding ">" (line separator is " ")
proc ::yaml::_parseBlockScalar {base separator} {
    foreach {explicit chomping} [_parseBlockIndicator] break
    
    set idch [string repeat " " $explicit]
    set sep $separator
    foreach {indent c line} [_getLine] {}
    if {$indent < $base} {return ""}
    # the first line, NOT ignored comment (as a normal-string)
    set first $indent
    set value $line
    set stop 0
    
    while {![_eof]} {
        set pos [_getpos]
        foreach {indent c line} [_getLine] {}
        if {$line eq ""} {
            regsub " " $sep "" sep
            append sep "\n"
            continue
        }
        if {$c eq "#"} {
            # skip comments
            continue
        }
        if {$indent <= $base} {
            set stop 1
            break
        }
        append value $sep[string repeat " " [expr {$indent - $first}]]$line
        set sep $separator
    }
    if {[info exists pos] && $stop} {_setpos $pos}
    switch -- $chomping {
        "strip" {
        }
        "keep" {
            append value $sep
        }
        "clip" {
            append value "\n"
        }
    }
    return [huddle wrap !!str $value]
}

# in {> |}
proc ::yaml::_parseBlockIndicator {} {
    set chomping "clip"
    set explicit 0
    while {1} {
        set type [_getc]
        if [regexp {[1-9]} $type digit] { ; # block indentation
            set explicit $digit
        } elseif {$type eq "-"} {   ; # strip chomping
            set chomping "strip"
        } elseif {$type eq "+"} {   ; # keep chomping
            set chomping "keep"
        } else {
            _ungetc
            break
        }
    }
    # Note: skipped after the indicator
    _getLine
    return [list $explicit $chomping]
}

# [162]    ns-plain-multi(n,c)
proc ::yaml::_parsePlainScalarInBlock {base} {
    set reStr {(?:[^:#\t \n]*(?::[^\t \n]+)*(?:#[^\t \n]+)* *)*[^:#\t \n]*}
    set result [_getFoldedString $reStr]

    set result [string trim $result]
    set c [_getc 0]
    if {$c eq "\n" || $c eq "#"} { ; # multi-line
        set lb ""
        while {1} {
            set fpos [_getpos]
            foreach {indent nop line} [_getLine] break
            if [_eof] {break}

            if {$line ne "" && [string index $line 0] ne "#"} {
                break
            }
            append lb "\n"
        }
        set lb [string range $lb 1 end]
        _setpos $fpos
        if {$base <= $indent} {
            if {$lb eq ""} {
                set lb " "
            }
            set subs [_parsePlainScalarInBlock $base]
            if {$subs ne ""} {
                append result "$lb$subs"
            }
        }
    }
    return $result
}

####################
# Flow Node parser
####################
proc ::yaml::_parseFlowNode {{status ""}} {
    set scalar 0
    set result {}
    set tag ""
    while {1} {
        _skipSpaces 1
        set type [_getc]
        switch -- $type {
            "" {
                break
            }
            "?" -
            ":" { ; # mapping value
                if [_next_is_blank] {
                    set value [_parseFlowNode "NODE"]
                } else {
                    set scalar 1
                }
            }
            "," { ; # ends a flow collection entry
                if {$status eq"NODE"} {
                    _ungetc
                    return $value
                }
            }
            "\{" { ; # starts a flow mapping
                set value [_parseFlowNode "MAPPING"]
            }
            "\}" { ; # ends a flow mapping
                if {$status ne "MAPPING"}  {error [_getErrorMessage MAPEND_NOT_IN_MAP] }
                return $result
            }
            "\[" { ; # starts a flow sequence
                 set value [_parseFlowNode "SEQUENCE"]
            }
            "\]" { ; # ends a flow sequence
                if {$status ne "SEQUENCE"} {error [_getErrorMessage SEQEND_NOT_IN_SEQ] }
                set result [eval huddle sequence $result]
                return $result
            }
            "&" { ; # node's anchor property
                set anchor [_getToken]
            }
            "*" { ; # alias node
                set alias [_getToken]
                set value [_getAnchor $alias]
            }
            "!" { ; # node's tag
                _ungetc
                set tag [_getToken]
            }
            "%" { ; # directive line
                _ungetc
                _parseDirective
            }
            default {
                set scalar 1
            }
        }
        if {$scalar} {
            _ungetc
            set value [_parseScalarNode $type "FLOW"]
            set value [_composeTags $tag $value]
            set tag ""
            set scalar 0
        }
        if [info exists value] {
            if [info exists anchor] {
                _setAnchor $anchor $value
                unset anchor
            }
            switch -- $status {
                "" -
                "NODE" {
                    return $value
                }
                "SEQUENCE" {
                    lappend result [_composePlain $value]
                }
                "MAPPING" {
                    if {![info exists key]} {
                        set key $value
                    } else {
                        set result [_set_huddle_mapping $result [list $key $value]]
                        unset key
                    }
                }
            }
            unset value
        }
    }
    return $result
}

proc ::yaml::_parseScalarNode {type scope {pos 0}} {
    set tag !!str
    switch -- $type {
        {"} { ; # surrounds a double-quoted flow scalar
            set value [_parseDoubleQuoted]
        }
        {'} { ; # surrounds a single-quoted flow scalar
            set value [_parseSingleQuoted]
        }
        "\t" {error [_getErrorMessage TAB_IN_PLAIN] }
        "@"  {error [_getErrorMessage AT_IN_PLAIN] }
        "`"  {error [_getErrorMessage BT_IN_PLAIN] }
        default {
            # Plane Scalar
            if       {$scope eq "FLOW"} {
                set value [_parsePlainScalarInFlow]
            } elseif {$scope eq "BLOCK"} {
                set value [_parsePlainScalarInBlock $pos]
            }
            set tag !!plain
        }
    }
    return [huddle wrap $tag $value]
}


# 2001-12-15T02:59:43.1Z       => 1008385183
# 2001-12-14t21:59:43.10-05:00 => 1008385183
# 2001-12-14 21:59:43.10 -5    => 1008385183
# 2001-12-15 2:59:43.10        => 1008352783
# 2002-12-14                   => 1039791600
proc ::yaml::_parseTimestamp {scalar} {
    if {![regexp {^\d\d\d\d-\d\d-\d\d} $scalar]} {return ""}
    set datestr  {\d\d\d\d-\d\d-\d\d}
    set timestr  {\d\d?:\d\d:\d\d}
    set timezone {Z|[-+]\d\d?(?::\d\d)?}

    set canonical [subst -nobackslashes -nocommands {^($datestr)[Tt ]($timestr)\.\d+ ?($timezone)?$}]
    set dttm [subst -nobackslashes -nocommands {^($datestr)(?:[Tt ]($timestr))?$}]
    if {$::tcl_version < 8.5} {
        if [regexp $canonical $scalar nop dt tm zone] {
            # Canonical
            if {$zone eq ""} {
                return [list !!timestamp [clock scan "$dt $tm"]]
            } elseif {$zone eq "Z"} {
                return [list !!timestamp [clock scan "$dt $tm" -gmt 1]]
            }
            if [regexp {^([-+])(\d\d?)$} $zone nop sign d] {set zone [format "$sign%02d:00" $d]}
            regexp {^([-+]\d\d):(\d\d)} $zone nop h m
            set m [expr {$h > 0 ? $h*60 + $m : $h*60 - $m}]
            return [list !!timestamp [clock scan "[expr -$m] minutes" -base [clock scan "$dt $tm" -gmt 1]]]
        } elseif [regexp $dttm $scalar nop dt tm] {
            if {$tm ne ""} {
                return [list !!timestamp [clock scan "$dt $tm"]]
            } else {
                return [list !!timestamp [clock scan $dt]]
            }
        }
    } else {
        if [regexp $canonical $scalar nop dt tm zone] {
            # Canonical
            if {$zone ne ""} {
                if [regexp {^([-+])(\d\d?)$} $zone nop sign d] {set zone [format "$sign%02d:00" $d]}
                return [list !!timestamp [clock scan "$dt $tm $zone" -format {%Y-%m-%d %k:%M:%S %Z}]]
            } else {
                return [list !!timestamp [clock scan "$dt $tm"       -format {%Y-%m-%d %k:%M:%S}]]
            }
        } elseif [regexp $dttm $scalar nop dt tm] {
            if {$tm ne ""} {
                return [list !!timestamp [clock scan "$dt $tm" -format {%Y-%m-%d %k:%M:%S}]]
            } else {
                return [list !!timestamp [clock scan $dt       -format {%Y-%m-%d}]]
            }
        }
    }
    return ""
}


proc ::yaml::_parseDirective {} {
    variable data
    variable shorthands

    set directive [_getToken]
    
    if [regexp {^%YAML} $directive] {
        # YAML directive
        _skipSpaces
        set version [_getToken]
        set data(YAMLVersion) $version
        if {![regexp {^\d\.\d$} $version]}   { error [_getErrorMessage ILLEGAL_YAML_DIRECTIVE] }
    } elseif [regexp {^%TAG} $directive] {
        # TAG directive
        _skipSpaces
        set handle [_getToken]
        if {![regexp {^!$|^!\w*!$} $handle]} { error [_getErrorMessage ILLEGAL_YAML_DIRECTIVE] }

        _skipSpaces
        set prefix [_getToken]
        if {![regexp {^!$|^!\w*!$} $prefix]} { error [_getErrorMessage ILLEGAL_YAML_DIRECTIVE] }
        set shorthands(handle) $prefix
    }
}

proc ::yaml::_parseTagHandle {} {
    set token [_getToken]
    
    if [regexp {^(!|!\w*!)(.*)} $token nop handle named] {
        # shorthand or non-specific Tags
        switch -- $handle {
            ! { ;       # local or non-specific Tags
            }
            !! { ;      # yaml Tags
            }
            default { ; # shorthand Tags
                
            }
        }
        if {![info exists prefix($handle)]} { error [_getErrorMessage TAG_NOT_FOUND] }
    } elseif [regexp {^!<(.+)>} $token nop uri] {
        # Verbatim Tags
        if {![regexp {^[\w:/]$} $token nop uri]} { error [_getErrorMessage ILLEGAL_TAG_HANDLE] }
    } else {
        error [_getErrorMessage ILLEGAL_TAG_HANDLE]
    }
    
    return "!<$prefix($handle)$named>"
}


proc ::yaml::_parseDoubleQuoted {} {
    # capture quoted string with backslash sequences
    set reStr {(?:(?:\")(?:[^\\\"]*(?:\\.[^\\\"]*)*)(?:\"))}
    set result [_getFoldedString $reStr]
    if {$result eq ""} { error [_getErrorMessage MALFORM_D_QUOTE] }

    # [116] nb-double-multi-line
    regsub -all {[ \t]*\n[\t ]*} $result "\r" result
    regsub -all {([^\r])\r} $result {\1 } result
    regsub -all { ?\r} $result "\n" result
    # [112] s-s-double-escaped(n)
    # is not impremented.(specification ???)

    # chop off outer ""s and substitute backslashes
    # This does more than the RFC-specified backslash sequences,
    # but it does cover them all
    set chopped [subst -nocommands -novariables \
        [string range $result 1 end-1]]
    return $chopped
}

proc ::yaml::_parseSingleQuoted {} {
    set reStr {(?:(?:')(?:[^']*(?:''[^']*)*)(?:'))}
    set result [_getFoldedString $reStr]
    if {$result eq ""} { error [_getErrorMessage MALFORM_S_QUOTE] }

    # [126] nb-single-multi-line
    regsub -all {[ \t]*\n[\t ]*} $result "\r" result
    regsub -all {([^\r])\r} $result {\1 } result
    regsub -all { ?\r} $result "\n" result

    regsub -all {''} [string range $result 1 end-1] {'} chopped
    
    return $chopped
}


# [155]     nb-plain-char-in
proc ::yaml::_parsePlainScalarInFlow {} {
    set sep {\t \n,\[\]\{\}}
    set reStr {(?:[^$sep:#]*(?::[^$sep]+)*(?:#[^$sep]+)* *)*[^$sep:#]*}
    set reStr [subst -nobackslashes -nocommands $reStr]
    set result [_getFoldedString $reStr]
    set result [string trim $result]

    if {[_getc 0] eq "#"} {
        _getLine
        set result "$result [_parsePlainScalarInFlow]"
    }
    return $result
}

####################
# Generic parser
####################
proc ::yaml::_getFoldedString {reStr} {
    variable data

    set buff [string range $data(buffer) $data(start) end]
    regexp $reStr $buff token
    if {![info exists token]} {return}
    
    set len [string length $token]
    if {[string first $token "\n"] >= 0} { ; # multi-line
        set data(current) [expr $len - [string last $token "\n"]]
    } else {
        incr data(current) $len
    }
    incr data(start) $len
    
    return $token
}

# get a space separated token
proc ::yaml::_getToken {} {
    variable data

    set reStr {^[^ \t\n,]+}
    set result [_getFoldedString $reStr]
    return $result
}

proc ::yaml::_skipSpaces {{commentSkip 0}} {
    variable data

    while {1} {
        set ch [string index $data(buffer) $data(start)]
        incr data(start)
        switch -- $ch {
            " " {
                incr data(current)
                continue
            }
            "\n" {
                set data(current) 0
                continue
            }
            "\#" {
                if {$commentSkip} {
                    _getLine
                    continue
                }
            }
        }
        break
    }
    incr data(start) -1
}

# get a line of stream(line-end trimed)
# (cannot _ungetc)
proc ::yaml::_getLine {{scrolled 1}} {
    variable data

    set pos [string first "\n" $data(buffer) $data(start)]
    if {$pos == -1} {
        set pos $data(length)
    }
    set line [string range $data(buffer) $data(start) [expr {$pos-1}]]
    regexp {^( *)(.*)} $line nop space result
    if {$scrolled} {
        set data(start) [expr {$pos + 1}]
        set data(current) 0
    }
    return [list [string length $space] [string index $result 0] $result]
}

proc ::yaml::_getCurrent {} {
    variable data
    return [expr {$data(current) ? $data(current)-1 : 0}]
}

proc ::yaml::_getLineNum {} {
    variable data
    set prev [string range $data(buffer) 0 $data(start)]
    return [llength [split $prev "\n"]]
}

proc ::yaml::_getc {{scrolled 1}} {
    variable data

    set result [string index $data(buffer) $data(start)]
    if {$scrolled} {
        incr data(start)
        if {$result eq "\n"} {
            set data(current) 0
        } else {
            incr data(current)
        }
    }
    return $result
}

proc ::yaml::_eof {} {
    variable data
    return [expr {$data(start) == $data(length)}]
}


proc ::yaml::_getpos {} {
    variable data
    return $data(start)
}

proc ::yaml::_setpos {pos} {
    variable data
    set data(start) $pos
}

proc ::yaml::_ungetc {{len 1}} {
    variable data
    incr data(start) [expr {-$len}]
    incr data(current) [expr {-$len}]
    if {$data(current) < 0} {
        set prev [string range $data(buffer) 0 $data(start)]
        if {[string index $prev end] eq "\n"} {set prev [string replace $prev end end a]}
        set data(current) [expr {$data(start) - [string last "\n" $prev] - 1}]
    }
}

proc ::yaml::_next_is_blank {} {
    set c [_getc 0]
    if {$c eq " " || $c eq "\n"} {
        return 1
    } else {
        return 0
    }
}

proc ::yaml::_setAnchor {anchor value} {
    variable data
    set data(anchor:$anchor) $value
}

proc ::yaml::_getAnchor {anchor} {
    variable data
    if {![info exists data(anchor:$anchor)]} {error [_getErrorMessage ANCHOR_NOT_FOUND]}
    return  $data(anchor:$anchor)
}

proc ::yaml::_getErrorMessage {ID {p1 ""}} {
    set num [_getLineNum]
    if {$p1 != ""} {
        return "line($num): [subst -nobackslashes -nocommands $yaml::errors($ID)]"
    } else {
        return "line($num): $yaml::errors($ID)"
    }
}


################
## Dumpers    ##
################

# There is a big problem in Tcl's Structures/Containers
# about Array/List/Dictionary(dict).
# (e.g.) {a b {This is a pen.} d e}
#     3rd element is a List or String?
#
# To enable it to write out correctly, the internal expression
# which can distinguish each other is needed.

# Return YAML from a key and a value
proc ::yaml::_dumpNode {key value indent} {
    # do some folding here, for blocks
    if {   [string first "\n" $value] >= 0
        || [string first ": " $value] >= 0
        || [string first "- " $value] >= 0} {
        set value [_doLiteralBlock $value $indent]
    } else {
        set value [_doFolding $value $indent]
    }
    
    set spaces [string repeat " " $indent]
    
    if {$key eq ""} {
        # It's a sequence
        set str "$spaces- $value\n"
    } else {
        # It's a mapping
        set str "$spaces$key: $value\n"
    }
    return $str
}


# Creates a literal block for dumping
proc ::yaml::_doLiteralBlock {value indent} {
    variable _dumpIndent
    set exploded [split $value "\n"]
    set newValue "|"
    incr indent $_dumpIndent
    set spaces [string repeat " " $indent]
    foreach {line} $exploded {
        set newValue "$newValue\n$spaces[string trim $line]"
    }
    return $newValue
}

# Folds a string of text, if necessary
proc ::yaml::_doFolding {value indent} {
    variable _dumpIndent
    variable _dumpWordWrap
    # Don't do anything if wordwrap is set to 0
    if {$_dumpWordWrap == 0} {
        return $value
    }
    
    if {[string length $value] > $_dumpWordWrap} {
        incr indent $_dumpIndent
        set spaces [string repeat " " $indent]
        set wrapped [_simple_justify $value $_dumpWordWrap "\n$spaces"]
        set value ">\n$spaces$wrapped"
    }
    return $value
}

# Finds and returns the indentation of a YAML line
proc ::yaml::_getIndent {line} {
    set match [regexp -inline -- {^\s{1,}} " $line"]
    return [expr {[string length $match] - 3}]
}

# http://wiki.tcl.tk/1774
proc ::yaml::_simple_justify {text width {wrap \n} {cut 0}} {
    for {set result {}} {[string length $text] > $width} {
                set text [string range $text [expr {$brk+1}] end]
            } {
        set brk [string last " " $text $width]
        if { $brk < 0 } {
            if {$cut == 0} {
                append result $text
                return $result
            } else {
                set brk $width
            }
        }
        append result [string range $text 0 $brk] $wrap
    }
    return $result$text
}

########################
## Huddle Settings    ##
########################


proc ::yaml::_huddle_mapping {command args} {
    switch -- $command {
        setting { ; # type definition
            return {
                type dict
                method {mapping}
                tag {!!map parent}
                constructor mapping
                str !!str
            }
        }
        mapping { ; # $args: all arguments after "huddle mapping"
            if {[llength $args] % 2} {error {wrong # args: should be "huddle mapping ?key value ...?"}}
            set resultL {}
            foreach {key value} $args {
                lappend resultL $key [huddle to_node $value !!str]
            }
            return [huddle wrap !!map $resultL]
        }
        default { ; # devolving to default dict-callback
            return [huddle call D $command $args]
        }
    }
}

proc ::yaml::_huddle_sequence {command args} {
    switch -- $command {
        setting { ; # type definition
            return {
                type list
                method {sequence}
                tag {!!seq parent}
                constructor sequence
                str !!str
            }
        }
        sequence {
            set resultL {}
            foreach {value} $args {
                lappend resultL [huddle to_node $value !!str]
            }
            return [huddle wrap !!seq $resultL]
        }
        default {
            return [huddle call L $command $args]
        }
    }
}

proc ::yaml::_makeChildType {type tag} {
    set procname ::yaml::_huddle_$type
    proc $procname {command args} [string map "@TYPE@ $type @TAG@ $tag" {
        switch -- $command {
            setting { ; # type definition
                return {
                    type @TYPE@
                    method {}
                    tag {@TAG@ child}
                    constructor ""
                    str @TAG@
                }
            }
            default {
                return [huddle call s $command $args]
            }
        }
    }]
    return $procname
}

huddle addType ::yaml::_huddle_mapping
huddle addType ::yaml::_huddle_sequence
huddle addType [::yaml::_makeChildType string !!str]
huddle addType [::yaml::_makeChildType string !!timestamp]
huddle addType [::yaml::_makeChildType string !!float]
huddle addType [::yaml::_makeChildType string !!int]
huddle addType [::yaml::_makeChildType string !!null]
huddle addType [::yaml::_makeChildType string !!true]
huddle addType [::yaml::_makeChildType string !!false]
huddle addType [::yaml::_makeChildType string !!binary]
huddle addType [::yaml::_makeChildType plain !!plain]


