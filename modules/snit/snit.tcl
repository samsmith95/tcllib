#-----------------------------------------------------------------------
# TITLE:
#	snit.tcl
#
# AUTHOR:
#	Will Duquette
#
# DESCRIPTION:
#       Snit's Not Incr Tcl: yet another simple object system in Pure Tcl, 
#	just because I wanted to.
#
#-----------------------------------------------------------------------

package provide snit 0.94

#-----------------------------------------------------------------------
# Namespace

namespace eval ::snit:: {
    namespace export \
        compile type widget widgetadaptor typemethod method macro
}

#-----------------------------------------------------------------------
# Some Snit variables

namespace eval ::snit:: {
    variable reservedArgs {type selfns win self}

    # If true, get a pretty, fixed-up stack trace.  Otherwise, get raw
    # stack trace.
    # NOTE: Not Yet Implemented
    variable prettyStackTrace 1
}

#-----------------------------------------------------------------------
# Snit Type Implementation template

namespace eval ::snit:: {
    # Template type definition: All internal and user-visible Snit
    # implementation code.
    #
    # The following placeholders will automatically be replaced with
    # the client's code, in two passes:
    #
    # First pass:
    # %COMPILEDDEFS%  The compiled type definition.
    #
    # Second pass:
    # %TYPE%          The fully qualified type name.
    # %IVARDECS%      Instance variable declarations
    # %TVARDECS%      Type variable declarations
    # %TCONSTBODY%    Type constructor body
    # %INSTANCEVARS%  The compiled instance variable initialization code.
    # %TYPEVARS%      The compiled type variable initialization code.

    variable typeTemplate
}

set ::snit::typeTemplate {

    #-------------------------------------------------------------------
    # The type's namespace definition and the user's type variables

    namespace eval %TYPE% {%TYPEVARS%
    }

    #----------------------------------------------------------------
    # Commands for use in methods, typemethods, etc.
    #
    # These are implemented as aliases into the Snit runtime library.

    interp alias {} %TYPE%::installhull  {} ::snit::RT.installhull %TYPE%
    interp alias {} %TYPE%::install      {} ::snit::RT.install %TYPE%
    interp alias {} %TYPE%::typevariable {} ::variable
    interp alias {} %TYPE%::variable     {} ::snit::RT.variable
    interp alias {} %TYPE%::mytypevar    {} ::snit::RT.mytypevar %TYPE%
    interp alias {} %TYPE%::typevarname  {} ::snit::RT.mytypevar %TYPE%
    interp alias {} %TYPE%::myvar        {} ::snit::RT.myvar
    interp alias {} %TYPE%::varname      {} ::snit::RT.myvar
    interp alias {} %TYPE%::codename     {} ::snit::RT.codename %TYPE%
    interp alias {} %TYPE%::myproc       {} ::snit::RT.myproc %TYPE%
    interp alias {} %TYPE%::mymethod     {} ::snit::RT.mymethod 
    interp alias {} %TYPE%::mytypemethod {} ::snit::RT.mytypemethod %TYPE%
    interp alias {} %TYPE%::from         {} ::snit::RT.from %TYPE%

    #-------------------------------------------------------------------
    # Snit's internal variables

    namespace eval %TYPE% {
        # Array: General Snit Info
        #
        # ns:                The type's namespace
        # hasinstances:      T or F, from pragma -hasinstances.
        # canreplace:        T or F, from pragma -canreplace.
        # counter:           Count of instances created so far.
        # widgetclass:       Set by widgetclass statement.
        # hulltype:          Hull type (frame or toplevel) for widgets only.
        # exceptmethods:     Methods explicitly not delegated to *
        # excepttypemethods: Methods explicitly not delegated to *
        # tvardecs:          Type variable declarations--for dynamic methods
        # ivardecs:          Instance variable declarations--for dyn. methods
        typevariable Snit_info
        set Snit_info(ns)      %TYPE%::
        set Snit_info(hasinstances) 1
        set Snit_info(canreplace) 0
        set Snit_info(counter) 0
        set Snit_info(widgetclass) {}
        set Snit_info(hulltype) frame
        set Snit_info(exceptmethods) {}
        set Snit_info(excepttypemethods) {}
        set Snit_info(tvardecs) {%TVARDECS%}
        set Snit_info(ivardecs) {%IVARDECS%}

        # Array: Public methods of this type.
        # The index is the method name, or "*".
        # The value is [list $pattern $componentName], where
        # $componentName is "" for normal methods.
        typevariable Snit_typemethodInfo
        array unset Snit_typemethodInfo

        # Array: Public methods of instances of this type.
        # The index is the method name, or "*".
        # The value is [list $pattern $componentName], where
        # $componentName is "" for normal methods.
        typevariable Snit_methodInfo
        array unset Snit_methodInfo

        # Array: option information.  See dictionary.txt.
        typevariable Snit_optionInfo
        array unset Snit_optionInfo
        set Snit_optionInfo(local)     {}
        set Snit_optionInfo(delegated) {}
        set Snit_optionInfo(starcomp)  {}
        set Snit_optionInfo(except)    {}
    }

    #----------------------------------------------------------------
    # Compiled Procs
    #
    # These commands are created or replaced during compilation:


    # Type dispatcher function.  Note: This function lives
    # in the parent of the %TYPE% namespace!  All accesses to 
    # %TYPE% variables and methods must be qualified!
    proc %TYPE% {method args} {
        # First, if the typemethod is unknown, we'll assume that it's
        # an instance name if we can.
        if {[catch {set %TYPE%::Snit_typemethodCache($method)} command]} {
            set command [::snit::RT.CacheTypemethodCommand %TYPE% $method]

            if {[llength $command] == 0} {
                return -code error  "\"%TYPE% $method\" is not defined"
            }
        }
        
        uplevel $command $args
    }

    # Snit_instanceVars selfns
    #
    # Initializes the instance variables, if any.  Called during
    # instance creation.
    
    proc %TYPE%::Snit_instanceVars {selfns} {%IVARDECS%
        %INSTANCEVARS%
    }

    # Type Constructor
    proc %TYPE%::Snit_typeconstructor {type} {
        %TVARDECS%
        %TCONSTBODY%
    }

    #----------------------------------------------------------------
    # Default Procs
    #
    # These commands might be replaced during compilation:

    # Snit_constructor type selfns win self args
    #
    # By default, just configures any passed options.  
    # Redefined by the "constructor" definition, hence always redefined
    # for widgets.

    proc %TYPE%::Snit_constructor {type selfns win self args} { 
        $self configurelist $args
    }

    # Snit_destructor type selfns win self
    #
    # Default destructor for the type.  By default, it does
    # nothing.  It's replaced by any user destructor.
    # For types, it's called by method destroy; for widgettypes,
    # it's called by a destroy event handler.

    proc %TYPE%::Snit_destructor {type selfns win self} { }

    #----------------------------------------------------------
    # Compiled Definitions

    # The compiled definitions contain a bunch of stuff,
    # including the following.
            
    # Snit_configure<option> type selfns win self value
    #
    # Defined for each local option.  By default, just updates the
    # options array.  Redefined by an onconfigure definition.
    
    # Snit_method<name> type selfns win self args...
    #
    # Defined for each local instance method.

    # Snit_typemethod<name> type args...
    #
    # Defined for each typemethod.

    %COMPILEDDEFS%

    #----------------------------------------------------------
    # Finally, call the Type Constructor

    %TYPE%::Snit_typeconstructor %TYPE%
}

#=======================================================================
# Snit Type Definition
#
# These are the procs used to define Snit types, widgets, and 
# widgetadaptors.


#-----------------------------------------------------------------------
# Snit Compilation Variables
#
# The following variables are used while Snit is compiling a type,
# and are disposed afterwards.

namespace eval ::snit:: {
    # The compiler variable contains the name of the slave interpreter
    # used to compile type definitions.
    variable compiler ""

    # The compile array accumulates information about the type or
    # widgettype being compiled.  It is cleared before and after each
    # compilation.  It has these indices:
    #
    # type:                  The name of the type being compiled, for use
    #                        in compilation procs.
    # defs:                  Compiled definitions, both standard and client.
    # which:                 type, widget, widgetadaptor
    # instancevars:          Instance variable definitions and initializations.
    # ivprocdec:             Instance variable proc declarations.
    # tvprocdec:             Type variable proc declarations.
    # typeconstructor:       Type constructor body.
    # widgetclass:           The widgetclass, for snit::widgets, only
    # localoptions:          Names of local options.
    # delegatedoptions:      Names of delegated options.
    # localmethods:          Names of locally defined methods.
    # delegatedmethods:      Names of delegated methods.
    # components:            Names of defined components.
    # localtypemethods:      Names of locally defined methods.
    # delegatedtypemethods:  Names of delegated typemethods.
    # typecomponents:        Names of defined typecomponents.
    # typevars:              Typevariable definitions and initializations.
    # varnames:              Names of instance variables
    # typevarnames           Names of type variables
    # resource-$opt          The option's resource name
    # class-$opt             The option's class
    # -default-$opt          The option's default value
    # -validatemethod-$opt   The option's validate method
    # -configuremethod-$opt  The option's configure method
    # -cgetmethod-$opt       The option's cget method.
    # -hastypeinfo           The -hastypeinfo pragma
    # -hastypedestroy        The -hastypedestroy pragma
    # -hasinstances          The -hasinstances pragma
    # -canreplace            The -canreplace pragma
    variable compile

    # The following variable lists the reserved type definition statement
    # names, e.g., the names you can't use as macros.  It's built at
    # compiler definition time using "info commands".
    variable reservedwords {}
}

#-----------------------------------------------------------------------
# type compilation commands
#
# The type and widgettype commands use a slave interpreter to compile
# the type definition.  These are the procs
# that are aliased into it.

# Initialize the compiler
proc ::snit::Comp.Init {} {
    variable compiler
    variable reservedwords

    if {$compiler eq ""} {
        # Create the compiler's interpreter
        set compiler [interp create]

        # Initialize the interpreter
	$compiler eval {
            # Load package information
            # TBD: see if this can be moved outside.
            catch {package require ::snit::__does_not_exist__}

            # Protect some Tcl commands our type definitions
            # will shadow.
            rename proc _proc
            rename variable _variable
        }

        # Define compilation aliases.
        $compiler alias pragma          ::snit::Comp.statement.pragma
        $compiler alias widgetclass     ::snit::Comp.statement.widgetclass
        $compiler alias hulltype        ::snit::Comp.statement.hulltype
        $compiler alias constructor     ::snit::Comp.statement.constructor
        $compiler alias destructor      ::snit::Comp.statement.destructor
        $compiler alias option          ::snit::Comp.statement.option
        $compiler alias oncget          ::snit::Comp.statement.oncget
        $compiler alias onconfigure     ::snit::Comp.statement.onconfigure
        $compiler alias method          ::snit::Comp.statement.method
        $compiler alias typemethod      ::snit::Comp.statement.typemethod
        $compiler alias typeconstructor ::snit::Comp.statement.typeconstructor
        $compiler alias proc            ::snit::Comp.statement.proc
        $compiler alias typevariable    ::snit::Comp.statement.typevariable
        $compiler alias variable        ::snit::Comp.statement.variable
        $compiler alias typecomponent   ::snit::Comp.statement.typecomponent
        $compiler alias component       ::snit::Comp.statement.component
        $compiler alias delegate        ::snit::Comp.statement.delegate
        $compiler alias expose          ::snit::Comp.statement.expose

        # Get the list of reserved words
        set reservedwords [$compiler eval {info commands}]
    }
}

# Compile a type definition, and return the results as a list of two
# items: the fully-qualified type name, and a script that will define
# the type when executed.
#
# which		type, widget, or widgetadaptor
# type          the type name
# body          the type definition
proc ::snit::Comp.Compile {which type body} {
    variable typeTemplate
    variable compile
    variable compiler

    # FIRST, qualify the name.
    if {![string match "::*" $type]} {
        # Get caller's namespace; 
        # append :: if not global namespace.
        set ns [uplevel 2 namespace current]
        if {"::" != $ns} {
            append ns "::"
        }
        
        set type "$ns$type"
    }

    # NEXT, create and initialize the compiler, if needed.
    Comp.Init

    # NEXT, initialize the class data
    array unset compile
    set compile(type) $type
    set compile(defs) {}
    set compile(which) $which
    set compile(localoptions) {}
    set compile(instancevars) {}
    set compile(typevars) {}
    set compile(delegatedoptions) {}
    set compile(ivprocdec) {}
    set compile(tvprocdec) {}
    set compile(typeconstructor) {}
    set compile(widgetclass) {}
    set compile(hulltype) {}
    set compile(localmethods) {}
    set compile(delegatedmethods) {}
    set compile(localtypemethods) {}
    set compile(delegatedtypemethods) {}
    set compile(components) {}
    set compile(typecomponents) {}
    set compile(varnames) {}
    set compile(typevarnames) {}
    set compile(-hastypeinfo) yes
    set compile(-hastypedestroy) yes
    set compile(-hasinstances) yes
    set compile(-canreplace) no

    set isWidget [string match widget* $which]
    set isWidgetAdaptor [string match widgetadaptor $which]

    if {$isWidgetAdaptor} {
        # A widgetadaptor is also a widget.
        set which widget
    }

    # NEXT, Evaluate the type's definition in the class interpreter.
    $compiler eval $body

    # NEXT, Add the standard definitions
    Comp.statement.typevariable Snit_isWidget $isWidget
    Comp.statement.typevariable Snit_isWidgetAdaptor $isWidgetAdaptor

    # Indicate whether the type can create instances that replace
    # existing commands.
    append compile(defs) "\nset %TYPE%::Snit_info(canreplace) $compile(-canreplace)\n"


    # Add the info typemethod unless the pragma forbids it.
    if {$compile(-hastypeinfo)} {
        Comp.statement.delegate typemethod info \
            using {::snit::RT.typemethod.info %t}
    }

    # Add the destroy typemethod unless the pragma forbids it.
    if {$compile(-hastypedestroy)} {
        Comp.statement.delegate typemethod destroy \
            using {::snit::RT.typemethod.destroy %t}
    }

    # Add standard methods/typemethods that only make sense if the
    # type has instances.
    if {$compile(-hasinstances)} {
        Comp.statement.variable options

        Comp.statement.delegate method info \
            using {::snit::RT.method.info %t %n %w %s}
        Comp.statement.delegate method cget \
            using {::snit::RT.method.cget %t %n %w %s}
        Comp.statement.delegate method configurelist \
            using {::snit::RT.method.configurelist %t %n %w %s}
        Comp.statement.delegate method configure \
            using {::snit::RT.method.configure %t %n %w %s}

        if {!$isWidget} {
            Comp.statement.delegate method destroy \
                using {::snit::RT.method.destroy %t %n %w %s}

            Comp.statement.delegate typemethod create \
                using {::snit::RT.type.typemethod.create %t}
        } else {
            Comp.statement.delegate typemethod create \
                using {::snit::RT.widget.typemethod.create %t}
        }
    } else {
        append compile(defs) "\nset %TYPE%::Snit_info(hasinstances) 0\n"
    }

    # NEXT, compiling the type definition built up a set of information
    # about the type's locally defined options; add this information to
    # the compiled definition.
    Comp.SaveOptionInfo

    # NEXT, if this is a widget define the hull component if it isn't
    # already defined.
    if {$isWidget} {
        Comp.DefineComponent hull
    }

    # NEXT, substitute the compiled definition into the type template
    # to get the type definition script.
    set defscript [Expand $typeTemplate \
                       %COMPILEDDEFS% $compile(defs)]

    # NEXT, substitute the defined macros into the type definition script.
    # This is done as a separate step so that the compile(defs) can 
    # contain the macros defined below.

    set defscript [Expand $defscript \
                       %TYPE%         $type \
                       %IVARDECS%     $compile(ivprocdec) \
                       %TVARDECS%     $compile(tvprocdec) \
                       %TCONSTBODY%   $compile(typeconstructor) \
                       %INSTANCEVARS% $compile(instancevars) \
                       %TYPEVARS%     $compile(typevars) \
		       ]

    array unset compile

    return [list $type $defscript]
}

# Information about locally-defined options is accumulated during
# compilation, but not added to the compiled definition--the option
# statement can appear multiple times, so it's easier this way.
# This proc fills in Snit_optionInfo with the accumulated information.
#
# It also computes the option's resource and class names if needed.
#
# Note that the information for delegated options was put in 
# Snit_optionInfo during compilation.

proc ::snit::Comp.SaveOptionInfo {} {
    variable compile

    foreach option $compile(localoptions) {
        if {$compile(resource-$option) eq ""} {
            set compile(resource-$option) [string range $option 1 end]
        }

        if {$compile(class-$option) eq ""} {
            set compile(class-$option) [Capitalize $compile(resource-$option)]
        }

        # NOTE: Don't verify that the validate, configure, and cget 
        # values name real methods; the methods might be defined outside 
        # the typedefinition using snit::method.
        
        Mappend compile(defs) {
            # Option %OPTION%
            lappend %TYPE%::Snit_optionInfo(local) %OPTION%

            set %TYPE%::Snit_optionInfo(islocal-%OPTION%)   1
            set %TYPE%::Snit_optionInfo(resource-%OPTION%)  %RESOURCE%
            set %TYPE%::Snit_optionInfo(class-%OPTION%)     %CLASS%
            set %TYPE%::Snit_optionInfo(default-%OPTION%)   %DEFAULT%
            set %TYPE%::Snit_optionInfo(validate-%OPTION%)  %VALIDATE%
            set %TYPE%::Snit_optionInfo(configure-%OPTION%) %CONFIGURE%
            set %TYPE%::Snit_optionInfo(cget-%OPTION%)      %CGET%
            set %TYPE%::Snit_optionInfo(readonly-%OPTION%)  %READONLY%
        }   %OPTION%    $option \
            %RESOURCE%  $compile(resource-$option) \
            %CLASS%     $compile(class-$option) \
            %DEFAULT%   [list $compile(-default-$option)] \
            %VALIDATE%  [list $compile(-validatemethod-$option)] \
            %CONFIGURE% [list $compile(-configuremethod-$option)] \
            %CGET%      [list $compile(-cgetmethod-$option)] \
            %READONLY%  $compile(-readonly-$option)
    }
}


# Evaluates a compiled type definition, thus making the type available.
proc ::snit::Comp.Define {compResult} {
    # The compilation result is a list containing the fully qualified
    # type name and a script to evaluate to define the type.
    set type [lindex $compResult 0]
    set defscript [lindex $compResult 1]

    # Execute the type definition script.
    # Consider using namespace eval %TYPE%.  See if it's faster.
    if {[catch {eval $defscript} result]} {
        namespace delete $type
        catch {rename $type ""}
        error $result
    }

    return $type
}

# Sets pragma options which control how the type is defined.
proc ::snit::Comp.statement.pragma {args} {
    variable compile

    set errRoot "Error in 'pragma...'"

    foreach {opt val} $args {
        switch -exact -- $opt {
            -hastypeinfo    -
            -hastypedestroy -
            -hasinstances   -
            -canreplace     {
                if {![string is boolean -strict $val]} {
                    error "$errRoot, '$opt' requires a boolean value."
                }
                set compile($opt) $val
            }
        }
    }
}

# Defines a widget's option class name.  
# This statement is only available for snit::widgets,
# not for snit::types or snit::widgetadaptors.
proc ::snit::Comp.statement.widgetclass {name} {
    variable compile

    # First, widgetclass can only be set for true widgets
    if {"widget" != $compile(which)} {
        error "widgetclass cannot be set for snit::$compile(which)s"
    }

    # Next, validate the option name.  We'll require that it begin
    # with an uppercase letter.
    set initial [string index $name 0]
    if {![string is upper $initial]} {
        error "widgetclass '$name' does not begin with an uppercase letter"
    }

    if {"" != $compile(widgetclass)} {
        error "too many widgetclass statements"
    }

    # Next, save it.
    Mappend compile(defs) {
        set  %TYPE%::Snit_info(widgetclass) %WIDGETCLASS%
    } %WIDGETCLASS% [list $name]

    set compile(widgetclass) $name
}

# Defines a widget's hull type.
# This statement is only available for snit::widgets,
# not for snit::types or snit::widgetadaptors.
proc ::snit::Comp.statement.hulltype {name} {
    variable compile

    # First, hulltype can only be set for true widgets
    if {"widget" != $compile(which)} {
        error "hulltype cannot be set for snit::$compile(which)s"
    }

    # Next, it must be either "frame" or "toplevel"
    if {"frame" != $name && "toplevel" != $name} {
        error "invalid hulltype '$name', should be 'frame' or 'toplevel'"
    }

    if {"" != $compile(hulltype)} {
        error "too many hulltype statements"
    }

    # Next, save it.
    Mappend compile(defs) {
        set  %TYPE%::Snit_info(hulltype) %HULLTYPE%
    } %HULLTYPE% $name

    set compile(hulltype) $name
}

# Defines a constructor.
proc ::snit::Comp.statement.constructor {arglist body} {
    variable compile

    CheckArgs "constructor" $arglist

    # Next, add a magic reference to self.
    set arglist [concat type selfns win self $arglist]

    # Next, add variable declarations to body:
    set body "%TVARDECS%%IVARDECS%\n$body"

    append compile(defs) "proc %TYPE%::Snit_constructor [list $arglist] [list $body]\n"
} 

# Defines a destructor.
proc ::snit::Comp.statement.destructor {body} {
    variable compile

    # Next, add variable declarations to body:
    set body "%TVARDECS%%IVARDECS%\n$body"

    append compile(defs) "proc %TYPE%::Snit_destructor {type selfns win self} [list $body]"
} 

# Defines a type option.  The option value can be a triple, specifying
# the option's -name, resource name, and class name. 
proc ::snit::Comp.statement.option {optionDef args} {
    variable compile

    # First, get the three option names.
    set option [lindex $optionDef 0]
    set resourceName [lindex $optionDef 1]
    set className [lindex $optionDef 2]

    set errRoot "Error in 'option [list $optionDef]...'"

    # Next, validate the option name.
    if {![Comp.OptionNameIsValid $option]} {
        error "$errRoot, badly named option '$option'"
    }

    if {[Contains $option $compile(delegatedoptions)]} {
        error "$errRoot, cannot define '$option' locally, it has been delegated."
    }

    if {![Contains $option $compile(localoptions)]} {
        # Remember that we've seen this one.
        lappend compile(localoptions) $option
        
        # Initialize compilation info for this option.
        set compile(resource-$option)         ""
        set compile(class-$option)            ""
        set compile(-default-$option)         ""
        set compile(-validatemethod-$option)  ""
        set compile(-configuremethod-$option) ""
        set compile(-cgetmethod-$option)      ""
        set compile(-readonly-$option)        0
    }

    # NEXT, see if we have a resource name.  If so, make sure it
    # isn't being redefined differently.
    if {$resourceName ne ""} {
        if {$compile(resource-$option) eq ""} {
            # If it's undefined, just save the value.
            set compile(resource-$option) $resourceName
        } elseif {$resourceName ne $compile(resource-$option)} {
            # It's been redefined differently.
            error "$errRoot, resource name redefined from '$compile(resource-$option)' to '$resourceName'."
        }
    }

    # NEXT, see if we have a class name.  If so, make sure it
    # isn't being redefined differently.
    if {$className ne ""} {
        if {$compile(class-$option) eq ""} {
            # If it's undefined, just save the value.
            set compile(class-$option) $className
        } elseif {$className ne $compile(class-$option)} {
            # It's been redefined differently.
            error "$errRoot, class name redefined from '$compile(class-$option)' to '$className'."
        }
    }

    # NEXT, handle the args; it's not an error to redefine these.
    if {[llength $args] == 1} {
        set compile(-default-$option) [lindex $args 0]
    } else {
        foreach {optopt val} $args {
            switch -exact -- $optopt {
                -default         -
                -validatemethod  -
                -configuremethod -
                -cgetmethod      {
                    set compile($optopt-$option) $val
                }
                -readonly        {
                    if {![string is boolean -strict $val]} {
                        error "$errRoot, -readonly requires a boolean, got '$val'"
                    }
                    set compile($optopt-$option) $val
                }
                default {
                    error "$errRoot, unknown option definition option '$optopt'."
                }
            }
        }
    }
}

# 1 if the option name is valid, 0 otherwise.
proc ::snit::Comp.OptionNameIsValid {option} {
    if {![string match {-*} $option] || [string match {*[A-Z ]*} $option]} {
        return 0
    }

    return 1
}

# Defines an option's cget handler
proc ::snit::Comp.statement.oncget {option body} {
    variable compile

    set errRoot "Error in 'oncget $option...'"

    if {[lsearch $compile(delegatedoptions) $option] != -1} {
        error "$errRoot, option '$option' is delegated."
    }

    if {[lsearch $compile(localoptions) $option] == -1} {
        error "$errRoot, option '$option' unknown."
    }

    # Next, add variable declarations to body:
    set body "%TVARDECS%%IVARDECS%\n$body"

    Comp.statement.method _cget$option {_option} $body
    Comp.statement.option $option -cgetmethod _cget$option
} 

# Defines an option's configure handler.
proc ::snit::Comp.statement.onconfigure {option arglist body} {
    variable compile

    if {[lsearch $compile(delegatedoptions) $option] != -1} {
        error "onconfigure $option: option '$option' is delegated."
    }

    if {[lsearch $compile(localoptions) $option] == -1} {
        error "onconfigure $option: option '$option' unknown."
    }

    if {[llength $arglist] != 1} {
        error \
       "onconfigure $option handler should have one argument, got '$arglist'."
    }

    CheckArgs "onconfigure $option" $arglist

    # Next, add a magic reference to the option name
    set arglist [concat _option $arglist]

    Comp.statement.method _configure$option $arglist $body
    Comp.statement.option $option -configuremethod _configure$option
} 

# Defines an instance method.
proc ::snit::Comp.statement.method {method arglist body} {
    variable compile

    if {[Contains $method $compile(delegatedmethods)]} {
        error "Error in 'delegate method $method...', '$method' has been defined locally."
    }

    lappend compile(localmethods) $method

    CheckArgs "method $method" $arglist

    # Next, add magic references to type and self.
    set arglist [concat type selfns win self $arglist]

    # Next, add variable declarations to body:
    set body "%TVARDECS%%IVARDECS%\n$body"

    # Next, save the definition script.
    Mappend compile(defs) {

        # Method %METHOD%
        set  %TYPE%::Snit_methodInfo(%METHOD%) \
            {"%t::Snit_method%m %t %n %w %s" ""}
        proc %TYPE%::Snit_method%METHOD% %ARGLIST% %BODY% 
    } %METHOD% $method %ARGLIST% [list $arglist] %BODY% [list $body] 
} 

# Defines a typemethod method.
proc ::snit::Comp.statement.typemethod {method arglist body} {
    variable compile

    if {[Contains $method $compile(delegatedtypemethods)]} {
        error "Error in 'delegate typemethod $method...', '$method' has been defined locally."
    }

    lappend compile(localtypemethods) $method

    CheckArgs "typemethod $method" $arglist

    # First, add magic reference to type.
    set arglist [concat type $arglist]

    # Next, add typevariable declarations to body:
    set body "%TVARDECS%\n$body"

    Mappend compile(defs) {

        # Typemethod %METHOD%
        set  %TYPE%::Snit_typemethodInfo(%METHOD%) \
            {"%t::Snit_typemethod%m %t" ""}

        proc %TYPE%::Snit_typemethod%METHOD% %ARGLIST% %BODY%
    } %METHOD% $method %ARGLIST% [list $arglist] %BODY% [list $body]
} 

# Defines a typemethod method.
proc ::snit::Comp.statement.typeconstructor {body} {
    variable compile

    if {"" != $compile(typeconstructor)} {
        error "too many typeconstructors"
    }

    set compile(typeconstructor) $body
} 

# Defines a static proc in the type's namespace.
proc ::snit::Comp.statement.proc {proc arglist body} {
    variable compile

    # If "ns" is defined, the proc can see instance variables.
    if {[lsearch -exact $arglist selfns] != -1} {
        # Next, add instance variable declarations to body:
        set body "%IVARDECS%\n$body"
    }

    # The proc can always see typevariables.
    set body "%TVARDECS%\n$body"

    append compile(defs) "

        # Proc $proc
        proc [list %TYPE%::$proc $arglist $body]
    "
} 

# Defines a static variable in the type's namespace.
proc ::snit::Comp.statement.typevariable {name args} {
    variable compile

    set errRoot "Error in 'typevariable $name...'"

    if {[llength $args] > 1} {
        error "$errRoot, too many initializers."
    }

    if {[lsearch -exact $compile(varnames) $name] != -1} {
        error "$errRoot, '$name' is already an instance variable."
    }

    lappend compile(typevarnames) $name

    if {[llength $args] == 1} {
        append compile(typevars) \
		"\n\t    [list ::variable $name [lindex $args 0]]"
    } else {
        append compile(typevars) \
		"\n\t    [list ::variable $name]"
    }

    append compile(tvprocdec) "\n\t    typevariable ${name}"
} 

# Defines an instance variable; the definition will go in the
# type's create typemethod.
proc ::snit::Comp.statement.variable {name args} {
    variable compile

    set errRoot "Error in 'variable $name...'"
    
    if {[llength $args] > 1} {
        error "$errRoot, too many initializers."
    }

    if {[lsearch -exact $compile(typevarnames) $name] != -1} {
        error "$errRoot, '$name' is already a typevariable."
    }

    lappend compile(varnames) $name

    if {[llength $args] == 1} {
        append compile(instancevars) \
		"\n\t    [list set $name [lindex $args 0]]"
    }

    append  compile(ivprocdec) "\n\t    "
    Mappend compile(ivprocdec) {::variable ${selfns}::%N} %N $name 
} 

# Defines a typecomponent, and handles component options.
#
# component     The logical name of the delegate
# args          options.

proc ::snit::Comp.statement.typecomponent {component args} {
    variable compile

    set errRoot "Error in 'typecomponent $component...'"

    # FIRST, define the component
    Comp.DefineTypecomponent $component $errRoot

    # NEXT, handle the options.
    set publicMethod ""
    set inheritFlag 0

    foreach {opt val} $args {
        switch -exact -- $opt {
            -public {
                set publicMethod $val
            }
            -inherit {
                set inheritFlag $val
                if {![string is boolean $inheritFlag]} {
    error "typecomponent $component -inherit: expected boolean value, got '$val'."
                }
            }
            default {
                error "typecomponent $component: Invalid option '$opt'"
            }
        }
    }

    # NEXT, if -public specified, define the method.  
    if {$publicMethod ne ""} {
        Comp.statement.delegate typemethod $publicMethod \
            to $component using {%c}
    }

    # NEXT, if "-inherit 1" is specified, delegate typemethod * to 
    # this component.
    if {$inheritFlag} {
        Comp.statement.delegate typemethod "*" to $component
    }

}


# Defines a name to be a typecomponent
# 
# The name becomes a typevariable; in addition, it gets a 
# write trace so that when it is set, all of the component mechanisms
# get updated.
#
# component     The component name

proc ::snit::Comp.DefineTypecomponent {component {errRoot "Error"}} {
    variable compile

    if {[lsearch -exact $compile(varnames) $component] != -1} {
        error "$errRoot, '$component' is already an instance variable."
    }

    if {[lsearch $compile(typecomponents) $component] == -1} {
        # Remember we've done this.
        lappend compile(typecomponents) $component

        # Make it a type variable with no initial value
        Comp.statement.typevariable $component ""

        # Add a write trace to do the component thing.
        Mappend compile(typevars) {
            trace add variable %COMP% write \
                [list ::snit::RT.TypecomponentTrace [list %TYPE%] %COMP%]
        } %TYPE% $compile(type) %COMP% $component
    }
} 

# Defines a component, and handles component options.
#
# component     The logical name of the delegate
# args          options.
#
# TBD: Ideally, it should be possible to call this statement multiple
# times, possibly changing the option values.  To do that, I'd need
# to cache the option values and not act on them until *after* I'd
# read the entire type definition.

proc ::snit::Comp.statement.component {component args} {
    variable compile

    set errRoot "Error in 'component $component...'"

    # FIRST, define the component
    Comp.DefineComponent $component $errRoot

    # NEXT, handle the options.
    set publicMethod ""
    set inheritFlag 0

    foreach {opt val} $args {
        switch -exact -- $opt {
            -public {
                set publicMethod $val
            }
            -inherit {
                set inheritFlag $val
                if {![string is boolean $inheritFlag]} {
    error "component $component -inherit: expected boolean value, got '$val'."
                }
            }
            default {
                error "component $component: Invalid option '$opt'"
            }
        }
    }

    # NEXT, if -public specified, define the method.  
    if {$publicMethod ne ""} {
        Comp.statement.delegate method $publicMethod to $component using {%c}
    }

    # NEXT, if -inherit is specified, delegate method/option * to 
    # this component.
    if {$inheritFlag} {
        Comp.statement.delegate method "*" to $component
        Comp.statement.delegate option "*" to $component
    }
}


# Defines a name to be a component
# 
# The name becomes an instance variable; in addition, it gets a 
# write trace so that when it is set, all of the component mechanisms
# get updated.
#
# component     The component name

proc ::snit::Comp.DefineComponent {component {errRoot "Error"}} {
    variable compile

    if {[lsearch -exact $compile(typevarnames) $component] != -1} {
        error "$errRoot, '$component' is already a typevariable."
    }

    if {[lsearch $compile(components) $component] == -1} {
        # Remember we've done this.
        lappend compile(components) $component

        # Make it an instance variable with no initial value
        Comp.statement.variable $component ""

        # Add a write trace to do the component thing.
        Mappend compile(instancevars) {
            trace add variable %COMP% write \
                [list ::snit::RT.ComponentTrace [list %TYPE%] $selfns %COMP%]
        } %TYPE% $compile(type) %COMP% $component
    }
} 

# Creates a delegated method, typemethod, or option.
proc ::snit::Comp.statement.delegate {what name args} {
    # FIRST, dispatch to correct handler.
    switch $what {
        typemethod { Comp.DelegatedTypemethod $name $args }
        method     { Comp.DelegatedMethod     $name $args }
        option     { Comp.DelegatedOption     $name $args }
        default {
            error "Error in 'delegate $what $name...', '$what'?"
        }
    }

    if {([llength $args] % 2) != 0} {
        error "Error in 'delegate $what $name...', invalid syntax"
    }
}

# Creates a delegated typemethod delegating it to a particular
# typecomponent or an arbitrary command.
#
# method    The name of the method
# arglist       Delegation options

proc ::snit::Comp.DelegatedTypemethod {method arglist} {
    variable compile

    set errRoot "Error in 'delegate typemethod [list $method]...'"

    # Next, parse the delegation options.
    set component ""
    set target ""
    set exceptions {}
    set pattern ""

    foreach {opt value} $arglist {
        switch -exact $opt {
            to     { set component $value  }
            as     { set target $value     }
            except { set exceptions $value }
            using  { set pattern $value    }
            default {
                error "$errRoot, unknown delegation option '$opt'."
            }
        }
    }

    if {$component eq "" && $pattern eq ""} {
        error "$errRoot, missing 'to'."
    }

    if {$method eq "*" && $target ne ""} {
        error "$errRoot, cannot specify 'as' with method '*'"
    }

    if {$method ne "*" && $exceptions ne ""} {
        error "$errRoot, can only specify 'except' with method '*'" 
    }

    if {$pattern ne "" && $target ne ""} {
        error "$errRoot, cannot specify both 'as' and 'using'"
    }

    # Make sure the pattern is a valid list.
    if {[catch {lindex $pattern 0} result]} {
        error "$errRoot, the -pattern, '$pattern', is not a valid list."
    }

    # NEXT, define the component
    if {$component ne ""} {
        Comp.DefineTypecomponent $component $errRoot
    }

    # NEXT, define the pattern.
    if {$pattern eq ""} {
        if {$method eq "*"} {
            set pattern "%c %m"
        } elseif {$target ne ""} {
            set pattern "%c $target"
        } else {
            set pattern "%c %m"
        }
    }

    if {[Contains $method $compile(localtypemethods)]} {
        error "$errRoot, '$method' has been defined locally."
    }

    Mappend compile(defs) {
        # Delegated typemethod %METH% to %COMP%
        set  %TYPE%::Snit_typemethodInfo(%METH%) \
            {"%PATTERN%" %COMP%}
    } %METH% $method %COMP% [list $component] %PATTERN% $pattern

    if {![string equal $method "*"]} {
        lappend compile(delegatedtypemethods) $method
    } else {
        Mappend compile(defs) {
            set %TYPE%::Snit_info(excepttypemethods) %EXCEPT%
        } %EXCEPT% [list $exceptions]
    }
}


# Creates a delegated method delegating it to a particular
# component or command.
#
# method        The name of the method
# arglist       Delegation options.

proc ::snit::Comp.DelegatedMethod {method arglist} {
    variable compile

    set errRoot "Error in 'delegate method [list $method]...'"

    # Next, parse the delegation options.
    set component ""
    set target ""
    set exceptions {}
    set pattern ""

    foreach {opt value} $arglist {
        switch -exact $opt {
            to     { set component $value  }
            as     { set target $value     }
            except { set exceptions $value }
            using  { set pattern $value    }
            default {
                error "$errRoot, unknown delegation option '$opt'."
            }
        }
    }

    if {$component eq "" && $pattern eq ""} {
        error "$errRoot, missing 'to'."
    }

    if {$method eq "*" && $target ne ""} {
        error "$errRoot, cannot specify 'as' with method '*'"
    }

    if {$method ne "*" && $exceptions ne ""} {
        error "$errRoot, can only specify 'except' with method '*'" 
    }

    if {$pattern ne "" && $target ne ""} {
        error "$errRoot, cannot specify both 'as' and 'using'"
    }

    # Make sure the pattern is a valid list.
    if {[catch {lindex $pattern 0} result]} {
        error "$errRoot, the -pattern, '$pattern', is not a valid list."
    }

    # NEXT, define the component.  Allow typecomponents.
    if {$component ne ""} {
        if {[lsearch -exact $compile(typecomponents) $component] == -1} {
            Comp.DefineComponent $component $errRoot
        }
    }

    # NEXT, define the pattern.
    if {$pattern eq ""} {
        if {$method eq "*"} {
            set pattern "%c %m"
        } elseif {$target ne ""} {
            set pattern "%c $target"
        } else {
            set pattern "%c %m"
        }
    }

    if {[Contains $method $compile(localmethods)]} {
        error "$errRoot, '$method' has been defined locally."
    }

    Mappend compile(defs) {
        # Delegated method %METH% to %COMP%
        set  %TYPE%::Snit_methodInfo(%METH%) \
            {"%PATTERN%" %COMP%}
    } %METH% $method %COMP% [list $component] %PATTERN% $pattern

    if {![string equal $method "*"]} {
        lappend compile(delegatedmethods) $method
    } else {
        Mappend compile(defs) {
            set %TYPE%::Snit_info(exceptmethods) %EXCEPT%
        } %EXCEPT% [list $exceptions]
    }
} 

# Creates a delegated option, delegating it to a particular
# component and, optionally, to a particular option of that
# component.
#
# optionDef     The option definition
# args          definition arguments.

proc ::snit::Comp.DelegatedOption {optionDef arglist} {
    variable compile

    # First, get the three option names.
    set option [lindex $optionDef 0]
    set resourceName [lindex $optionDef 1]
    set className [lindex $optionDef 2]

    set errRoot "Error in 'delegate option [list $optionDef]...'"

    # Next, parse the delegation options.
    set component ""
    set target ""
    set exceptions {}

    foreach {opt value} $arglist {
        switch -exact $opt {
            to     { set component $value  }
            as     { set target $value     }
            except { set exceptions $value }
            default {
                error "$errRoot, unknown delegation option '$opt'."
            }
        }
    }

    if {$component eq ""} {
        error "$errRoot, missing 'to'."
    }

    if {$option eq "*" && $target ne ""} {
        error "$errRoot, cannot specify 'as' with 'delegate option *'"
    }

    if {$option ne "*" && $exceptions ne ""} {
        error "$errRoot, can only specify 'except' with 'delegate option *'" 
    }

    # Next, validate the option name

    if {"*" != $option} {
        if {![Comp.OptionNameIsValid $option]} {
            error "$errRoot, badly named option '$option'"
        }
    }

    if {[Contains $option $compile(localoptions)]} {
        error "$errRoot, '$option' has been defined locally."
    }

    if {[Contains $option $compile(delegatedoptions)]} {
        error "$errRoot, '$option' is multiply delegated."
    }

    # NEXT, define the component
    Comp.DefineComponent $component $errRoot

    # Next, define the target option, if not specified.
    if {![string equal $option "*"] &&
        [string equal $target ""]} {
        set target $option
    }

    if {![string equal $option "*"]} {
        lappend compile(delegatedoptions) $option

        # Next, compute the resource and class names, if they aren't
        # already defined.

        if {"" == $resourceName} {
            set resourceName [string range $option 1 end]
        }

        if {"" == $className} {
            set className [Capitalize $resourceName]
        }

        Mappend  compile(defs) {
            set %TYPE%::Snit_optionInfo(islocal-%OPTION%) 0
            set %TYPE%::Snit_optionInfo(resource-%OPTION%) %RES%
            set %TYPE%::Snit_optionInfo(class-%OPTION%) %CLASS%
            lappend %TYPE%::Snit_optionInfo(delegated) %OPTION%
            set %TYPE%::Snit_optionInfo(target-%OPTION%) [list %COMP% %TARGET%]
            lappend %TYPE%::Snit_optionInfo(delegated-%COMP%) %OPTION%
        }   %OPTION% $option \
            %COMP% $component \
            %TARGET% $target \
            %RES% $resourceName \
            %CLASS% $className 
    } else {
        Mappend  compile(defs) {
            set %TYPE%::Snit_optionInfo(starcomp) %COMP%
            set %TYPE%::Snit_optionInfo(except) %EXCEPT%
        } %COMP% $component %EXCEPT% [list $exceptions]
    }
} 

# Exposes a component, effectively making the component's command an
# instance method.
#
# component     The logical name of the delegate
# "as"          sugar; if not "", must be "as"
# methodname    The desired method name for the component's command, or ""

proc ::snit::Comp.statement.expose {component {"as" ""} {methodname ""}} {
    variable compile


    # FIRST, define the component
    Comp.DefineComponent $component

    # NEXT, define the method just as though it were in the type
    # definition.
    if {[string equal $methodname ""]} {
        set methodname $component
    }

    Comp.statement.method $methodname args [Expand {
        if {[llength $args] == 0} {
            return $%COMPONENT%
        }

        if {[string equal $%COMPONENT% ""]} {
            error "undefined component '%COMPONENT%'"
        }


        set cmd [linsert $args 0 $%COMPONENT%]
        return [uplevel 1 $cmd]
    } %COMPONENT% $component]
}



#-----------------------------------------------------------------------
# Public commands

# Compile a type definition, and return the results as a list of two
# items: the fully-qualified type name, and a script that will define
# the type when executed.
#
# which		type, widget, or widgetadaptor
# type          the type name
# body          the type definition
proc ::snit::compile {which type body} {
    return [Comp.Compile $which $type $body]
}

proc ::snit::type {type body} {
    return [Comp.Define [Comp.Compile type $type $body]]
}

proc ::snit::widget {type body} {
    return [Comp.Define [Comp.Compile widget $type $body]]
}

proc ::snit::widgetadaptor {type body} {
    return [Comp.Define [Comp.Compile widgetadaptor $type $body]]
}

proc ::snit::typemethod {type method arglist body} {
    # Make sure the type exists.
    if {![info exists ${type}::Snit_info]} {
        error "no such type: '$type'"
    }

    upvar ${type}::Snit_info           Snit_info
    upvar ${type}::Snit_typemethodInfo Snit_typemethodInfo

    # FIRST, can't redefine delegated methods.
    if {[info exists Snit_typemethodInfo($method)] &&
        [lindex $Snit_typemethodInfo($method) 1] ne ""} {
        error "Cannot define '$method', it has been delegated."
    }

    CheckArgs "snit::typemethod $type $method" $arglist

    # Next, add magic reference to type.
    set arglist [concat type $arglist]

    # Next, add typevariable declarations to body:
    set body "$Snit_info(tvardecs)\n$body"

    # Next, define it.
    set Snit_typemethodInfo($method) {"%t::Snit_typemethod%m %t" ""}
    
    uplevel [list proc ${type}::Snit_typemethod$method $arglist $body]
}

proc ::snit::method {type method arglist body} {
    # Make sure the type exists.
    if {![info exists ${type}::Snit_info]} {
        error "no such type: '$type'"
    }

    upvar ${type}::Snit_methodInfo  Snit_methodInfo
    upvar ${type}::Snit_info        Snit_info

    if {![info exists Snit_info]} {
        error "no such type: '$type'"
    }

    # FIRST, can't redefine delegated methods.
    if {[info exists Snit_methodInfo($method)] &&
        [lindex $Snit_methodInfo($method) 1] ne ""} {
        error "Cannot define '$method', it has been delegated."
    }

    # NEXT, check the arguments
    CheckArgs "snit::method $type $method" $arglist

    # Next, add magic references to type and self.
    set arglist [concat type selfns win self $arglist]

    # Next, add variable declarations to body:
    set body "$Snit_info(tvardecs)$Snit_info(ivardecs)\n$body"

    # Next, define it.
    set Snit_methodInfo($method) {"%t::Snit_method%m %t %n %w %s" ""}

    uplevel [list proc ${type}::Snit_method$method $arglist $body]
}

# Defines a proc within the compiler; this proc can call other
# type definition statements, and thus can be used for meta-programming.
proc ::snit::macro {name arglist body} {
    variable compiler
    variable reservedwords

    # FIRST, make sure the compiler is defined.
    Comp.Init

    # NEXT, check the macro name against the reserved words
    if {[lsearch -exact $reservedwords $name] != -1} {
        error "invalid macro name '$name'"
    }

    # NEXT, see if the name has a namespace; if it does, define the
    # namespace.
    set ns [namespace qualifiers $name]

    if {$ns ne ""} {
        $compiler eval "namespace eval $ns {}"
    }

    # NEXT, define the macro
    $compiler eval [list _proc $name $arglist $body]
}

#-----------------------------------------------------------------------
# Utility Functions
#
# These are utility functions used while compiling Snit types.

# Builds a template from a tagged list of text blocks, then substitutes
# all symbols in the mapTable, returning the expanded template.
proc ::snit::Expand {template args} {
    return [string map $args $template]
}

# Expands a template and appends it to a variable.
proc ::snit::Mappend {varname template args} {
    upvar $varname myvar

    append myvar [string map $args $template]
}

# Checks argument list against reserved args 
proc ::snit::CheckArgs {which arglist} {
    variable reservedArgs
    
    foreach name $reservedArgs {
        if {[Contains $name $arglist]} {
            error "$which's arglist may not contain '$name' explicitly."
        }
    }
}

# Returns 1 if a value is in a list, and 0 otherwise.
proc ::snit::Contains {value list} {
    if {[lsearch -exact $list $value] != -1} {
        return 1
    } else {
        return 0
    }
}

# Capitalizes the first letter of a string.
proc ::snit::Capitalize {text} {
    set first [string index $text 0]
    set rest [string range $text 1 end]
    return "[string toupper $first]$rest"
}

#=======================================================================
# Snit Runtime Library
#
# These are procs used by Snit types and widgets at runtime.

#-----------------------------------------------------------------------
# Object Creation

# Creates a new instance of the snit::type given its name and the args.
#
# type		The snit::type
# name		The instance name
# args		Args to pass to the constructor

proc ::snit::RT.type.typemethod.create {type name args} {
    variable ${type}::Snit_info
    variable ${type}::Snit_optionInfo

    # FIRST, qualify the name.
    if {![string match "::*" $name]} {
        # Get caller's namespace; 
        # append :: if not global namespace.
        set ns [uplevel 1 namespace current]
        if {"::" != $ns} {
            append ns "::"
        }
        
        set name "$ns$name"
    }

    # NEXT, if %AUTO% appears in the name, generate a unique 
    # command name.  Otherwise, ensure that the name isn't in use.
    if {[string match "*%AUTO%*" $name]} {
        set name [::snit::RT.UniqueName Snit_info(counter) $type $name]
    } elseif {!$Snit_info(canreplace) && [info commands $name] ne ""} {
        error "command \"$name\" already exists."
    }

    # NEXT, create the instance's namespace.
    set selfns \
        [::snit::RT.UniqueInstanceNamespace Snit_info(counter) $type]
    namespace eval $selfns {}

    # NEXT, install the dispatcher
    RT.MakeInstanceCommand $type $selfns $name

    # Initialize the options to their defaults. 
    upvar ${selfns}::options options
    foreach opt $Snit_optionInfo(local) {
        set options($opt) $Snit_optionInfo(default-$opt)
    }
        
    # Initialize the instance vars to their defaults.
    # selfns must be defined, as it is used implicitly.
    ${type}::Snit_instanceVars $selfns

    # Execute the type's constructor.
    set errcode [catch {
        RT.ConstructInstance $type $selfns $name $args
    } result]

    if {$errcode} {
        global errorInfo
        global errorCode
        
        set theInfo $errorInfo
        set theCode $errorCode
        ::snit::RT.DestroyObject $type $selfns $name
        error "Error in constructor: $result" $theInfo $theCode
    }

    # NEXT, return the object's name.
    return $name
}

# Creates a new instance of the snit::widget or snit::widgetadaptor
# given its name and the args.
#
# type		The snit::widget or snit::widgetadaptor
# name		The instance name
# args		Args to pass to the constructor

proc ::snit::RT.widget.typemethod.create {type name args} {
    variable ${type}::Snit_info
    variable ${type}::Snit_optionInfo
    variable ${type}::Snit_isWidgetAdaptor

    # FIRST, if %AUTO% appears in the name, generate a unique 
    # command name.
    if {[string match "*%AUTO%*" $name]} {
        set name [::snit::RT.UniqueName Snit_info(counter) $type $name]
    }
            
    # NEXT, create the instance's namespace.
    set selfns \
        [::snit::RT.UniqueInstanceNamespace Snit_info(counter) $type]
    namespace eval $selfns { }
            
    # NEXT, Initialize the widget's own options to their defaults.
    upvar ${selfns}::options options
    foreach opt $Snit_optionInfo(local) {
        set options($opt) $Snit_optionInfo(default-$opt)
    }

    # Initialize the instance vars to their defaults.
    ${type}::Snit_instanceVars $selfns

    # NEXT, if this is a normal widget (not a widget adaptor) then 
    # create a frame as its hull.  We set the frame's -class to
    # the user's widgetclass, or, if none, to the basename of
    # the $type with an initial upper case letter.
    if {!$Snit_isWidgetAdaptor} {
        # FIRST, determine the class name
        if {"" == $Snit_info(widgetclass)} {
            set Snit_info(widgetclass) \
                [::snit::Capitalize [namespace tail $type]]
        }

        # NEXT, create the widget
        set self $name
        package require Tk
        ${type}::installhull using \
            $Snit_info(hulltype) -class $Snit_info(widgetclass)

        # NEXT, let's query the option database for our
        # widget, now that we know that it exists.
        foreach opt $Snit_optionInfo(local) {
            set dbval [RT.OptionDbGet $type $name $opt]

            if {"" != $dbval} {
                set options($opt) $dbval
            }
        }
    }

    # Execute the type's constructor, and verify that it
    # has a hull.
    set errcode [catch {
        RT.ConstructInstance $type $selfns $name $args
            
        ::snit::RT.Component $type $selfns hull
            
        # Prepare to call the object's destructor when the
        # <Destroy> event is received.  Use a Snit-specific bindtag
        # so that the widget name's tag is unencumbered.
            
        bind Snit$type$name <Destroy> [::snit::Expand {
            ::snit::RT.DestroyObject %TYPE% %NS% %W
        } %TYPE% $type %NS% $selfns]
            
        # Insert the bindtag into the list of bindtags right
        # after the widget name.
        set taglist [bindtags $name]
        set ndx [lsearch $taglist $name]
        incr ndx
        bindtags $name [linsert $taglist $ndx Snit$type$name]
    } result]
        
    if {$errcode} {
        global errorInfo
        global errorCode

        set theInfo $errorInfo
        set theCode $errorCode
        ::snit::RT.DestroyObject $type $selfns $name
        error "Error in constructor: $result" $theInfo $theCode
    }
        
    # NEXT, return the object's name.
    return $name
}


# RT.MakeInstanceCommand type selfns instance
#
# type        The object type
# selfns      The instance namespace
# instance    The instance name
#
# Creates the instance proc.

proc ::snit::RT.MakeInstanceCommand {type selfns instance} {
    variable ${type}::Snit_isWidget
        
    # FIRST, remember the instance name.  The Snit_instance variable
    # allows the instance to figure out its current name given the
    # instance namespace.
    upvar ${selfns}::Snit_instance Snit_instance
    set Snit_instance $instance

    # NEXT, qualify the proc name if it's a widget.
    if {$Snit_isWidget} {
        set procname ::$instance
    } else {
        set procname $instance
    }

    # NEXT, install the new proc
    set body [string map [list %SELFNS% $selfns %WIN% $instance %TYPE% $type] {
        set self [set %SELFNS%::Snit_instance]
            
        if {[catch {set %SELFNS%::Snit_methodCache($method)} command]} {
            set command [snit::RT.CacheMethodCommand %TYPE% %SELFNS% %WIN% $self $method]
                
            if {[llength $command] == 0} {
                return -code error \
                    "'$self $method' is not defined."
            }
        }
            
        uplevel 1 $command $args
    }]

    proc $procname {method args} $body

    # NEXT, add the trace.
    trace add command $procname {rename delete} \
        [list ::snit::RT.InstanceTrace $type $selfns $instance]
}

# This proc is called when the instance command is renamed.
# If op is delete, then new will always be "", so op is redundant.
#
# type		The fully-qualified type name
# selfns	The instance namespace
# win		The original instance/tk window name.
# old		old instance command name
# new		new instance command name
# op		rename or delete
#
# If the op is delete, we need to clean up the object; otherwise,
# we need to track the change.
#
# NOTE: In Tcl 8.4.2 there's a bug: errors in rename and delete
# traces aren't propagated correctly.  Instead, they silently
# vanish.  Add a catch to output any error message.

proc ::snit::RT.InstanceTrace {type selfns win old new op} {
    variable ${type}::Snit_isWidget

    # Note to developers ...
    # For Tcl 8.4.0, errors thrown in trace handlers vanish silently.
    # Therefore we catch them here and create some output to help in
    # debugging such problems.

    if {[catch {
        # FIRST, clean up if necessary
        if {"" == $new} {
            if {$Snit_isWidget} {
                destroy $win
            } else {
                ::snit::RT.DestroyObject $type $selfns $win
            }
        } else {
            # Otherwise, track the change.
            variable ${selfns}::Snit_instance
            set Snit_instance [uplevel namespace which -command $new]
            
            # Also, clear the instance caches, as many cached commands
            # might be invalid.
            RT.ClearInstanceCaches $selfns
        }
    } result]} {
        global errorInfo
        # Pop up the console on Windows wish, to enable stdout.
        # This clobbers errorInfo unix, so save it.
        set ei $errorInfo
        catch {console show}
        puts "Error in ::snit::RT.InstanceTrace $type $selfns $win $old $new $op:"
        puts $ei
    }
}

# Calls the instance constructor and handles related housekeeping.
proc ::snit::RT.ConstructInstance {type selfns instance arglist} {
    variable ${type}::Snit_optionInfo
    variable ${selfns}::Snit_iinfo

    # Track whether we are constructed or not.
    set Snit_iinfo(constructed) 0

    # Call the user's constructor
    eval [list ${type}::Snit_constructor $type $selfns \
              $instance $instance] $arglist

    set Snit_iinfo(constructed) 1

    # Unset the configure cache for all -readonly options.
    # This ensures that the next time anyone tries to 
    # configure it, an error is thrown.
    foreach opt $Snit_optionInfo(local) {
        if {$Snit_optionInfo(readonly-$opt)} {
            unset -nocomplain ${selfns}::configureCache($opt)
        }
    }

    return
}

# Returns a unique command name.  
#
# REQUIRE: type is a fully qualified name.
# REQUIRE: name contains "%AUTO%"
# PROMISE: the returned command name is unused.
proc ::snit::RT.UniqueName {countervar type name} {
    upvar $countervar counter 
    while 1 {
        # FIRST, bump the counter and define the %AUTO% instance name;
        # then substitute it into the specified name.  Wrap around at
        # 2^31 - 2 to prevent overflow problems.
        incr counter
        if {$counter > 2147483646} {
            set counter 0
        }
        set auto "[namespace tail $type]$counter"
        set candidate [Expand $name %AUTO% $auto]
        if {[info commands $candidate] eq ""} {
            return $candidate
        }
    }
}

# Returns a unique instance namespace, fully qualified.
#
# countervar     The name of a counter variable
# type           The instance's type
#
# REQUIRE: type is fully qualified
# PROMISE: The returned namespace name is unused.

proc ::snit::RT.UniqueInstanceNamespace {countervar type} {
    upvar $countervar counter 
    while 1 {
        # FIRST, bump the counter and define the namespace name.
        # Then see if it already exists.  Wrap around at
        # 2^31 - 2 to prevent overflow problems.
        incr counter
        if {$counter > 2147483646} {
            set counter 0
        }
        set ins "${type}::Snit_inst${counter}"
        if {![namespace exists $ins]} {
            return $ins
        }
    }
}

# Retrieves an option's value from the option database.
# Returns "" if no value is found.
proc ::snit::RT.OptionDbGet {type self opt} {
    variable ${type}::Snit_optionInfo
        
    return [option get $self \
                $Snit_optionInfo(resource-$opt) \
                $Snit_optionInfo(class-$opt)]
}

#-----------------------------------------------------------------------
# Object Destruction

# Implements the standard "destroy" method
#
# type		The snit type
# selfns        The instance's instance namespace
# win           The instance's original name
# self          The instance's current name

proc ::snit::RT.method.destroy {type selfns win self} {
    # Calls Snit_cleanup, which (among other things) calls the
    # user's destructor.
    ::snit::RT.DestroyObject $type $selfns $win
}

# This is the function that really cleans up; it's automatically 
# called when any instance is destroyed, e.g., by "$object destroy"
# for types, and by the <Destroy> event for widgets.
#
# type		The fully-qualified type name.
# selfns	The instance namespace
# win		The original instance command name.

proc ::snit::RT.DestroyObject {type selfns win} {
    variable ${type}::Snit_isWidget

    # If the variable Snit_instance doesn't exist then there's no
    # instance command for this object -- it's most likely a 
    # widgetadaptor. Consequently, there are some things that
    # we don't need to do.
    if {[info exists ${selfns}::Snit_instance]} {
        upvar ${selfns}::Snit_instance instance
            
        # First, remove the trace on the instance name, so that we
        # don't call RT.DestroyObject recursively.
        RT.RemoveInstanceTrace $type $selfns $win $instance
            
        # Next, call the user's destructor
        ${type}::Snit_destructor $type $selfns $win $instance

        # Next, if this isn't a widget, delete the instance command.
        # If it is a widget, get the hull component's name, and rename
        # it back to the widget name
                
        # Next, delete the hull component's instance command,
        # if there is one.
        if {$Snit_isWidget} {
            set hullcmd [::snit::RT.Component $type $selfns hull]
            
            catch {rename $instance ""}

            # Clear the bind event
            bind Snit$type$win <Destroy> ""

            if {[info command $hullcmd] != ""} {
                rename $hullcmd ::$instance
            }
        } else {
            catch {rename $instance ""}
        }
    }

    # Next, delete the instance's namespace.  This kills any
    # instance variables.
    namespace delete $selfns
}

# Remove instance trace
# 
# type           The fully qualified type name
# selfns         The instance namespace
# win            The original instance name/Tk window name
# instance       The current instance name

proc ::snit::RT.RemoveInstanceTrace {type selfns win instance} {
    variable ${type}::Snit_isWidget

    if {$Snit_isWidget} {
        set procname ::$instance
    } else {
        set procname $instance
    }
        
    # NEXT, remove any trace on this name
    catch {
        trace remove command $procname {rename delete} \
            [list ::snit::RT.InstanceTrace $type $selfns $win]
    }
}

#-----------------------------------------------------------------------
# Typecomponent Management and Method Caching

# Typecomponent trace; used for write trace on typecomponent 
# variables.  Saves the new component object name, provided 
# that certain conditions are met.  Also clears the typemethod
# cache.

proc ::snit::RT.TypecomponentTrace {type component n1 n2 op} {
    upvar ${type}::Snit_isWidget Snit_isWidget
    upvar ${type}::${component} cvar
    upvar ${type}::Snit_typecomponents Snit_typecomponents
        
    # Save the new component value.
    set Snit_typecomponents($component) $cvar

    # Clear the typemethod cache.
    # TBD: can we unset just the elements related to
    # this component?
    unset -nocomplain -- ${type}::Snit_typemethodCache
}

# Generates and caches the command for a typemethod.
#
# type		The type
# method	The name of the typemethod to call.
proc snit::RT.CacheTypemethodCommand {type method} {
    upvar ${type}::Snit_typemethodInfo  Snit_typemethodInfo
    upvar ${type}::Snit_typecomponents  Snit_typecomponents
    upvar ${type}::Snit_typemethodCache Snit_typemethodCache
    upvar ${type}::Snit_info            Snit_info
    
    # FIRST, get the pattern data and the typecomponent name.
    set implicitCreate 0
    set instanceName ""

    if {[info exists Snit_typemethodInfo($method)]} {
        set key $method
    } elseif {[info exists Snit_typemethodInfo(*)]} {
        if {[lsearch -exact $Snit_info(excepttypemethods) $method] == -1} {
            set key "*"
        } else {
            return ""
        }
    } elseif {$Snit_info(hasinstances)} {
        # Assume the unknown name is an instance name to create, unless
        # this is a widget and the style of the name is wrong, or the
        # name mimics a standard typemethod.

        if {[set ${type}::Snit_isWidget] && 
            ![string match ".*" $method]} {
            return ""
        }

        # Without this check, the call "$type info" will redefine the
        # standard "::info" command, with disastrous results.  Since it's
        # a likely thing to do if !-typeinfo, put in an explicit check.
        if {$method eq "info" || $method eq "destroy"} {
            return ""
        }

        set implicitCreate 1
        set instanceName $method
        set key create
        set method create
    } else {
        return ""
    }
    
    foreach {pattern compName} $Snit_typemethodInfo($key) {}

    # NEXT, build the substitution list
    set subList [list \
                     %% % \
                     %t [list $type] \
                     %m [list $method]]
    
    if {$compName ne ""} {
        if {![info exists Snit_typecomponents($compName)]} {
            error "$type delegates typemethod '$method' to undefined typecomponent '$compName'."
        }
        
        lappend subList %c [list $Snit_typecomponents($compName)]
    }

    set command [string map $subList $pattern]

    if {$implicitCreate} {
        # In this case, $method is the name of the instance to
        # create.  Don't cache, as we usually won't do this one
        # again.
        lappend command $instanceName
    } else {
        set Snit_typemethodCache($method) $command
    }

    return $command
}


#-----------------------------------------------------------------------
# Component Management and Method Caching

# Retrieves the object name given the component name.
proc ::snit::RT.Component {type selfns name} {
    variable ${selfns}::Snit_components

    if {[catch {set Snit_components($name)} result]} {
        variable ${selfns}::Snit_instance

        error "component '$name' is undefined in $type $Snit_instance."
    }
    
    return $result
}

# Component trace; used for write trace on component instance 
# variables.  Saves the new component object name, provided 
# that certain conditions are met.  Also clears the method
# cache.

proc ::snit::RT.ComponentTrace {type selfns component n1 n2 op} {
    upvar ${type}::Snit_isWidget Snit_isWidget
    upvar ${selfns}::${component} cvar
    upvar ${selfns}::Snit_components Snit_components
        
    # If they try to redefine the hull component after
    # it's been defined, that's an error--but only if
    # this is a widget or widget adaptor.
    if {"hull" == $component && 
        $Snit_isWidget &&
        [info exists Snit_components($component)]} {
        set cvar $Snit_components($component)
        error "The hull component cannot be redefined."
    }

    # Save the new component value.
    set Snit_components($component) $cvar

    # Clear the instance caches.
    # TBD: can we unset just the elements related to
    # this component?
    RT.ClearInstanceCaches $selfns
}

# Generates and caches the command for a method.
#
# type:		The instance's type
# selfns:	The instance's private namespace
# win:          The instance's original name (a Tk widget name, for
#               snit::widgets.
# self:         The instance's current name.
# method:	The name of the method to call.
proc ::snit::RT.CacheMethodCommand {type selfns win self method} {
    variable ${type}::Snit_info
    variable ${type}::Snit_methodInfo
    variable ${type}::Snit_typecomponents
    variable ${selfns}::Snit_components
    variable ${selfns}::Snit_methodCache

    # FIRST, get the pattern data and the component name.
    if {[info exists Snit_methodInfo($method)]} {
        set key $method
    } elseif {[info exists Snit_methodInfo(*)] &&
              [lsearch -exact $Snit_info(exceptmethods) $method] == -1} {
        set key "*"
    } else {
        return ""
    }

    foreach {pattern compName} $Snit_methodInfo($key) {}

    # NEXT, build the substitution list
    set subList [list \
                     %% % \
                     %t [list $type] \
                     %m [list $method] \
                     %n [list $selfns] \
                     %w [list $win] \
                     %s [list $self]]

    if {$compName ne ""} {
        if {[info exists Snit_components($compName)]} {
            set compCmd $Snit_components($compName)
        } elseif {[info exists Snit_typecomponents($compName)]} {
            set compCmd $Snit_typecomponents($compName)
        } else {
            error "$type $self delegates method '$method' to undefined component '$compName'."
        }
        
        lappend subList %c [list $compCmd]
    }

    # Note: The cached command will executed faster if it's
    # already a list.
    set command {}

    foreach subpattern $pattern {
        lappend command [string map $subList $subpattern]
    }
    
    set Snit_methodCache($method) $command
        
    return $command
}

# Clears all instance command caches
proc ::snit::RT.ClearInstanceCaches {selfns} {
    unset -nocomplain -- ${selfns}::Snit_methodCache
    unset -nocomplain -- ${selfns}::Snit_cgetCache
    unset -nocomplain -- ${selfns}::Snit_configureCache
    unset -nocomplain -- ${selfns}::Snit_validateCache
}


#-----------------------------------------------------------------------
# Component Installation

# Implements %TYPE%::installhull.  The variables self and selfns
# must be defined in the caller's context.
#
# Installs the named widget as the hull of a 
# widgetadaptor.  Once the widget is hijacked, its new name
# is assigned to the hull component.

proc ::snit::RT.installhull {type {using "using"} {widgetType ""} args} {
    variable ${type}::Snit_isWidget
    variable ${type}::Snit_info
    variable ${type}::Snit_optionInfo
    upvar self self
    upvar selfns selfns
    upvar ${selfns}::hull hull
    upvar ${selfns}::options options

    # FIRST, make sure we can do it.
    if {!$Snit_isWidget} { 
        error "installhull is valid only for snit::widgetadaptors"
    }
            
    if {[info exists ${selfns}::Snit_instance]} {
        error "hull already installed for $type $self"
    }

    # NEXT, has it been created yet?  If not, create it using
    # the specified arguments.
    if {"using" == $using} {
        # FIRST, create the widget
        set cmd [concat [list $widgetType $self] $args]
        set obj [uplevel 1 $cmd]
            
        # NEXT, for each option explicitly delegated to the hull
        # that doesn't appear in the usedOpts list, get the
        # option database value and apply it--provided that the
        # real option name and the target option name are different.
        # (If they are the same, then the option database was
        # already queried as part of the normal widget creation.)
        #
        # Also, we don't need to worry about implicitly delegated
        # options, as the option and target option names must be
        # the same.
        if {[info exists Snit_optionInfo(delegated-hull)]} {
                
            # FIRST, extract all option names from args
            set usedOpts {}
            set ndx [lsearch -glob $args "-*"]
            foreach {opt val} [lrange $args $ndx end] {
                lappend usedOpts $opt
            }
                
            foreach opt $Snit_optionInfo(delegated-hull) {
                set target [lindex $Snit_optionInfo(target-$opt) 1]
                
                if {"$target" == $opt} {
                    continue
                }
                    
                set result [lsearch -exact $usedOpts $target]
                    
                if {$result != -1} {
                    continue
                }

                set dbval [RT.OptionDbGet $type $self $opt]
                $obj configure $target $dbval
            }
        }
    } else {
        set obj $using
        
        if {![string equal $obj $self]} {
            error \
                "hull name mismatch: '$obj' != '$self'"
        }
    }

    # NEXT, get the local option defaults.
    foreach opt $Snit_optionInfo(local) {
        set dbval [RT.OptionDbGet $type $self $opt]
            
        if {"" != $dbval} {
            set options($opt) $dbval
        }
    }


    # NEXT, do the magic
    set i 0
    while 1 {
        incr i
        set newName "::hull${i}$self"
        if {"" == [info commands $newName]} {
            break
        }
    }
        
    rename ::$self $newName
    RT.MakeInstanceCommand $type $selfns $self
        
    # Note: this relies on RT.ComponentTrace to do the dirty work.
    set hull $newName
        
    return
}

# Implements %TYPE%::install.
#
# Creates a widget and installs it as the named component.
# It expects self and selfns to be defined in the caller's context.

proc ::snit::RT.install {type compName "using" widgetType winPath args} {
    variable ${type}::Snit_isWidget
    variable ${type}::Snit_optionInfo
    variable ${type}::Snit_info
    upvar self self
    upvar selfns selfns
    upvar ${selfns}::$compName comp
    upvar ${selfns}::hull hull

    # We do the magic option database stuff only if $self is
    # a widget.
    if {$Snit_isWidget} {
        if {"" == $hull} {
            error "tried to install '$compName' before the hull exists"
        }
            
        # FIRST, query the option database and save the results 
        # into args.  Insert them before the first option in the
        # list, in case there are any non-standard parameters.
        #
        # Note: there might not be any delegated options; if so,
        # don't bother.

        if {[info exists Snit_optionInfo(delegated-$compName)]} {
            set ndx [lsearch -glob $args "-*"]
                
            foreach opt $Snit_optionInfo(delegated-$compName) {
                set dbval [RT.OptionDbGet $type $self $opt]
                    
                if {"" != $dbval} {
                    set target [lindex $Snit_optionInfo(target-$opt) 1]
                    set args [linsert $args $ndx $target $dbval]
                }
            }
        }
    }
             
    # NEXT, create the component and save it.
    set cmd [concat [list $widgetType $winPath] $args]
    set comp [uplevel 1 $cmd]

    # NEXT, handle the option database for "delegate option *",
    # in widgets only.
    if {$Snit_isWidget && $Snit_optionInfo(starcomp) eq $compName} {
        # FIRST, get the list of option specs from the widget.
        # If configure doesn't work, skip it.
        if {[catch {$comp configure} specs]} {
            return
        }

        # NEXT, get the set of explicitly used options from args
        set usedOpts {}
        set ndx [lsearch -glob $args "-*"]
        foreach {opt val} [lrange $args $ndx end] {
            lappend usedOpts $opt
        }

        # NEXT, "delegate option *" matches all options defined
        # by this widget that aren't defined by the widget as a whole,
        # and that aren't excepted.  Plus, we skip usedOpts.  So build 
        # a list of the options it can't match.
        set skiplist [concat \
                          $usedOpts \
                          $Snit_optionInfo(except) \
                          $Snit_optionInfo(local) \
                          $Snit_optionInfo(delegated)]
        
        # NEXT, loop over all of the component's options, and set
        # any not in the skip list for which there is an option 
        # database value.
        foreach spec $specs {
            # Skip aliases
            if {[llength $spec] != 5} {
                continue
            }

            set opt [lindex $spec 0]

            if {[lsearch -exact $skiplist $opt] != -1} {
                continue
            }

            set res [lindex $spec 1]
            set cls [lindex $spec 2]

            set dbvalue [option get $self $res $cls]

            if {"" != $dbvalue} {
                $comp configure $opt $dbvalue
            }
        }
    }

    return
}


#-----------------------------------------------------------------------
# Method/Variable Name Qualification

# Implements %TYPE%::variable.  Requires selfns.
proc ::snit::RT.variable {varname} {
    upvar selfns selfns

    if {![string match "::*" $varname]} {
        uplevel upvar ${selfns}::$varname $varname
    } else {
        # varname is fully qualified; let the standard
        # "variable" command handle it.
        uplevel ::variable $varname
    }
}

# Fully qualifies a typevariable name.
#
# This is used to implement the mytypevar command.

proc ::snit::RT.mytypevar {type name} {
    return ${type}::$name
}

# Fully qualifies an instance variable name.
#
# This is used to implement the myvar command.
proc ::snit::RT.myvar {name} {
    upvar selfns selfns
    return ${selfns}::$name
}

# Use this like "list" to convert a proc call into a command
# string to pass to another object (e.g., as a -command).
# Qualifies the proc name properly.
#
# This is used to implement the "myproc" command.

proc ::snit::RT.myproc {type procname args} {
    set procname "${type}::$procname"
    return [linsert $args 0 $procname]
}

# DEPRECATED
proc ::snit::RT.codename {type name} {
    return "${type}::$name"
}

# Use this like "list" to convert a typemethod call into a command
# string to pass to another object (e.g., as a -command).
# Inserts the type command at the beginning.
#
# This is used to implement the "mytypemethod" command.

proc ::snit::RT.mytypemethod {type args} {
    return [linsert $args 0 $type]
}

# Use this like "list" to convert a method call into a command
# string to pass to another object (e.g., as a -command).
# Inserts the code at the beginning to call the right object, even if
# the object's name has changed.  Requires that selfns be defined
# in the calling context, eg. can only be called in instance
# code.
#
# This is used to implement the "mymethod" command.

proc ::snit::RT.mymethod {args} {
    upvar selfns selfns
    return [linsert $args 0 ::snit::RT.CallInstance ${selfns}]
}

# Calls an instance method for an object given its
# instance namespace and remaining arguments (the first of which
# will be the method name.
#
# selfns		The instance namespace
# args			The arguments
#
# Uses the selfns to determine $self, and calls the method
# in the normal way.
#
# This is used to implement the "mymethod" command.

proc ::snit::RT.CallInstance {selfns args} {
    upvar ${selfns}::Snit_instance self
    return [uplevel 1 [linsert $args 0 $self]]
}

# Looks for the named option in the named variable.  If found,
# it and its value are removed from the list, and the value
# is returned.  Otherwise, the default value is returned.
# If the option is undelegated, it's own default value will be
# used if none is specified.
#
# Implements the "from" command.

proc ::snit::RT.from {type argvName option {defvalue ""}} {
    variable ${type}::Snit_optionInfo
    upvar $argvName argv

    set ioption [lsearch -exact $argv $option]

    if {$ioption == -1} {
        if {"" == $defvalue &&
            [info exists Snit_optionInfo(default-$option)]} {
            return $Snit_optionInfo(default-$option)
        } else {
            return $defvalue
        }
    }

    set ivalue [expr {$ioption + 1}]
    set value [lindex $argv $ivalue]
    
    set argv [lreplace $argv $ioption $ivalue] 

    return $value
}

#-----------------------------------------------------------------------
# Type Destruction

# Implements the standard "destroy" typemethod:
# Destroys a type completely.
#
# type		The snit type

proc ::snit::RT.typemethod.destroy {type} {
    variable ${type}::Snit_isWidget
        
    # FIRST, destroy all instances
    foreach selfns [namespace children $type] {
        if {![namespace exists $selfns]} {
            continue
        }
        upvar ${selfns}::Snit_instance obj
            
        if {$Snit_isWidget} {
            destroy $obj
        } else {
            if {"" != [info commands $obj]} {
                $obj destroy
            }
        }
    }

    # NEXT, destroy the type's data.
    namespace delete $type

    # NEXT, get rid of the type command.
    rename $type ""
}



#-----------------------------------------------------------------------
# Option Handling

# Implements the standard "cget" method
#
# type		The snit type
# selfns        The instance's instance namespace
# win           The instance's original name
# self          The instance's current name
# option        The name of the option

proc ::snit::RT.method.cget {type selfns win self option} {
    if {[catch {set ${selfns}::Snit_cgetCache($option)} command]} {
        set command [snit::RT.CacheCgetCommand $type $selfns $win $self $option]
        
        if {[llength $command] == 0} {
            return -code error "unknown option \"$option\""
        }
    }
            
    uplevel 1 $command
}

# Retrieves and caches the command that implements "cget" for the 
# specified option.
#
# type		The snit type
# selfns        The instance's instance namespace
# win           The instance's original name
# self          The instance's current name
# option        The name of the option

proc ::snit::RT.CacheCgetCommand {type selfns win self option} {
    variable ${type}::Snit_optionInfo
    variable ${selfns}::Snit_cgetCache
                
    if {[info exists Snit_optionInfo(islocal-$option)]} {
        # We know the item; it's either local, or explicitly delegated.
        if {$Snit_optionInfo(islocal-$option)} {
            # It's a local option.  If it has a cget method defined,
            # use it; otherwise just return the value.

            if {$Snit_optionInfo(cget-$option) eq ""} {
                set command [list set ${selfns}::options($option)]
            } else {
                set command [snit::RT.CacheMethodCommand \
                                 $type $selfns $win $self \
                                 $Snit_optionInfo(cget-$option)]
                lappend command $option
            }

            set Snit_cgetCache($option) $command
            return $command
        }
         
        # Explicitly delegated option; get target
        set comp [lindex $Snit_optionInfo(target-$option) 0]
        set target [lindex $Snit_optionInfo(target-$option) 1]
    } elseif {$Snit_optionInfo(starcomp) ne "" &&
              [lsearch -exact $Snit_optionInfo(except) $option] == -1} {
        # Unknown option, but unknowns are delegated; get target.
        set comp $Snit_optionInfo(starcomp)
        set target $option
    } else {
        return ""
    }
    
    # Get the component's object.
    set obj [RT.Component $type $selfns $comp]

    set command [list $obj cget $target]
    set Snit_cgetCache($option) $command

    return $command
}

# Implements the standard "configurelist" method
#
# type		The snit type
# selfns        The instance's instance namespace
# win           The instance's original name
# self          The instance's current name
# optionlist    A list of options and their values.

proc ::snit::RT.method.configurelist {type selfns win self optionlist} {
    variable ${type}::Snit_optionInfo

    foreach {option value} $optionlist {
        # FIRST, get the configure command, caching it if need be.
        if {[catch {set ${selfns}::Snit_configureCache($option)} command]} {
            set command [snit::RT.CacheConfigureCommand \
                             $type $selfns $win $self $option]
        
            if {[llength $command] == 0} {
                return -code error "unknown option \"$option\""
            }
        }

        # NEXT, the caching the configure command also cached the
        # validate command, if any.  If we have one, run it.
        set valcommand [set ${selfns}::Snit_validateCache($option)]

        if {$valcommand ne ""} {
            lappend valcommand $value
            uplevel 1 $valcommand
        }

        # NEXT, configure the option with the value.
        lappend command $value
        uplevel 1 $command
    }
    
    return
}

# Retrieves and caches the command that stores the named option.
# Also stores the command that validates the name option if any;
# If none, the validate command is "", so that the cache is always
# populated.
#
# type		The snit type
# selfns        The instance's instance namespace
# win           The instance's original name
# self          The instance's current name
# option        An option name

proc ::snit::RT.CacheConfigureCommand {type selfns win self option} {
    variable ${type}::Snit_optionInfo
    variable ${selfns}::Snit_configureCache
    variable ${selfns}::Snit_validateCache

    if {[info exist Snit_optionInfo(islocal-$option)]} {
        # We know the item; it's either local, or explicitly delegated.
        
        if {$Snit_optionInfo(islocal-$option)} {
            # It's a local option.

            # If it's readonly, it throws an error if we're already 
            # constructed.
            if {$Snit_optionInfo(readonly-$option)} {
                if {[set ${selfns}::Snit_iinfo(constructed)]} {
                    error "option $option can only be set at instance creation"
                }
            }

            # If it has a validate method, cache that for later.
            if {$Snit_optionInfo(validate-$option) ne ""} {
                set command [snit::RT.CacheMethodCommand \
                                 $type $selfns $win $self \
                                 $Snit_optionInfo(validate-$option)]
                lappend command $option
                set Snit_validateCache($option) $command
            } else {
                set Snit_validateCache($option) ""
            }
            
            # If it has a configure method defined,
            # cache it; otherwise, just set the value.

            if {$Snit_optionInfo(configure-$option) eq ""} {
                set command [list set ${selfns}::options($option)]
            } else {
                set command [snit::RT.CacheMethodCommand \
                                 $type $selfns $win $self \
                                 $Snit_optionInfo(configure-$option)]
                lappend command $option
            }

            set Snit_configureCache($option) $command
            return $command
        }

        # Delegated option: get target.
        set comp [lindex $Snit_optionInfo(target-$option) 0]
        set target [lindex $Snit_optionInfo(target-$option) 1]
    } elseif {$Snit_optionInfo(starcomp) != "" &&
              [lsearch -exact $Snit_optionInfo(except) $option] == -1} {
        # Unknown option, but unknowns are delegated.
        set comp $Snit_optionInfo(starcomp)
        set target $option
    } else {
        return ""
    }

    # There is no validate command in this case; save an empty string.
    set Snit_validateCache($option) ""
        
    # Get the component's object
    set obj [RT.Component $type $selfns $comp]
    
    set command [list $obj configure $target]
    set Snit_configureCache($option) $command

    return $command
}

# Implements the standard "configure" method
#
# type		The snit type
# selfns        The instance's instance namespace
# win           The instance's original name
# self          The instance's current name
# args          A list of options and their values, possibly empty.

proc ::snit::RT.method.configure {type selfns win self args} {
    # If two or more arguments, set values as usual.
    if {[llength $args] >= 2} {
        ::snit::RT.method.configurelist $type $selfns $win $self $args
        return
    }

    # If zero arguments, acquire data for each known option
    # and return the list
    if {[llength $args] == 0} {
        set result {}
        foreach opt [RT.method.info.options $type $selfns $win $self] {
            # Refactor this, so that we don't need to call via $self.
            lappend result [RT.GetOptionDbSpec \
                                $type $selfns $win $self $opt]
        }
        
        return $result
    }

    # They want it for just one.
    set opt [lindex $args 0]

    return [RT.GetOptionDbSpec $type $selfns $win $self $opt]
}


# Retrieves the option database spec for a single option.
#
# type		The snit type
# selfns        The instance's instance namespace
# win           The instance's original name
# self          The instance's current name
# option        The name of an option
#
# TBD: This is a bad name.  What it's returning is the
# result of the configure query.

proc ::snit::RT.GetOptionDbSpec {type selfns win self opt} {
    variable ${type}::Snit_optionInfo

    upvar ${selfns}::Snit_components Snit_components
    upvar ${selfns}::options         options
    
    if {[info exists options($opt)]} {
        # This is a locally-defined option.  Just build the
        # list and return it.
        set res $Snit_optionInfo(resource-$opt)
        set cls $Snit_optionInfo(class-$opt)
        set def $Snit_optionInfo(default-$opt)

        return [list $opt $res $cls $def \
                    [RT.method.cget $type $selfns $win $self $opt]]
    } elseif {[info exists Snit_optionInfo(target-$opt)]} {
        # This is an explicitly delegated option.  The only
        # thing we don't have is the default.
        set res $Snit_optionInfo(resource-$opt)
        set cls $Snit_optionInfo(class-$opt)
        
        # Get the default
        set logicalName [lindex $Snit_optionInfo(target-$opt) 0]
        set comp $Snit_components($logicalName)
        set target [lindex $Snit_optionInfo(target-$opt) 1]

        if {[catch {$comp configure $target} result]} {
            set defValue {}
        } else {
            set defValue [lindex $result 3]
        }

        return [list $opt $res $cls $defValue [$self cget $opt]]
    } elseif {$Snit_optionInfo(starcomp) ne "" &&
              [lsearch -exact $Snit_optionInfo(except) $opt] == -1} {
        set logicalName $Snit_optionInfo(starcomp)
        set target $opt
        set comp $Snit_components($logicalName)

        if {[catch {set value [$comp cget $target]} result]} {
            error "unknown option \"$opt\""
        }

        if {![catch {$comp configure $target} result]} {
            # Replace the delegated option name with the local name.
            return [::snit::Expand $result $target $opt]
        }

        # configure didn't work; return simple form.
        return [list $opt "" "" "" $value]
    } else {
        error "unknown option \"$opt\""
    }
}

#-----------------------------------------------------------------------
# Type Introspection

# Implements the standard "info" typemethod.
#
# type		The snit type
# command       The info subcommand
# args          All other arguments.

proc ::snit::RT.typemethod.info {type command args} {
    global errorInfo
    global errorCode

    switch -exact $command {
        typevars - 
        instances {
            # TBD: it should be possible to delete this error
            # handling.
            set errflag [catch {
                uplevel ::snit::RT.typemethod.info.$command \
                    $type $args
            } result]
                
            if {$errflag} {
                return -code error -errorinfo $errorInfo \
                    -errorcode $errorCode $result
            } else {
                return $result
            }
        }
        default {
            error "'$type info $command' is not defined."
        }
    }
}


# Returns a list of the type's typevariables whose names match a 
# pattern, excluding Snit internal variables.
#
# type		A Snit type
# pattern       Optional.  The glob pattern to match.  Defaults
#               to *.

proc ::snit::RT.typemethod.info.typevars {type {pattern *}} {
    set result {}
    foreach name [info vars "${type}::$pattern"] {
        set tail [namespace tail $name]
        if {![string match "Snit_*" $tail]} {
            lappend result $name
        }
    }
    
    return $result
}

# Returns a list of the type's instances whose names match
# a pattern.
#
# type		A Snit type
# pattern       Optional.  The glob pattern to match
#               Defaults to *
#
# REQUIRE: type is fully qualified.

proc ::snit::RT.typemethod.info.instances {type {pattern *}} {
    set result {}

    foreach selfns [namespace children $type] {
        upvar ${selfns}::Snit_instance instance

        if {[string match $pattern $instance]} {
            lappend result $instance
        }
    }

    return $result
}

#-----------------------------------------------------------------------
# Instance Introspection

# Implements the standard "info" method.
#
# type		The snit type
# selfns        The instance's instance namespace
# win           The instance's original name
# self          The instance's current name
# command       The info subcommand
# args          All other arguments.

proc ::snit::RT.method.info {type selfns win self command args} {
    switch -exact $command {
        type    -
        vars    -
        options -
        typevars {
            set errflag [catch {
                uplevel ::snit::RT.method.info.$command \
                    $type $selfns $win $self $args
            } result]
            
            if {$errflag} {
                global errorInfo
                return -code error -errorinfo $errorInfo $result
            } else {
                return $result
            }
        }
        default {
            # error "'$self info $command' is not defined."
            return -code error "'$self info $command' is not defined."
        }
    }
}

# $self info type
#
# Returns the instance's type
proc ::snit::RT.method.info.type {type selfns win self} {
    return $type
}

# $self info typevars
#
# Returns the instance's type's typevariables
proc ::snit::RT.method.info.typevars {type selfns win self {pattern *}} {
    return [RT.typemethod.info.typevars $type $pattern]
}

# $self info vars
#
# Returns the instance's instance variables
proc ::snit::RT.method.info.vars {type selfns win self {pattern *}} {
    set result {}
    foreach name [info vars "${selfns}::$pattern"] {
        set tail [namespace tail $name]
        if {![string match "Snit_*" $tail]} {
            lappend result $name
        }
    }

    return $result
}

# $self info options 
#
# Returns a list of the names of the instance's options
proc ::snit::RT.method.info.options {type selfns win self {pattern *}} {
    variable ${type}::Snit_optionInfo

    # First, get the local and explicitly delegated options
    set result [concat $Snit_optionInfo(local) $Snit_optionInfo(delegated)]

    # If "configure" works as for Tk widgets, add the resulting
    # options to the list.  Skip excepted options
    if {$Snit_optionInfo(starcomp) ne ""} {
        upvar ${selfns}::Snit_components Snit_components
        set logicalName $Snit_optionInfo(starcomp)
        set comp $Snit_components($logicalName)

        if {![catch {$comp configure} records]} {
            foreach record $records {
                set opt [lindex $record 0]
                if {[lsearch -exact $result $opt] == -1 &&
                    [lsearch -exact $Snit_optionInfo(except) $opt] == -1} {
                    lappend result $opt
                }
            }
        }
    }

    # Next, apply the pattern
    set names {}

    foreach name $result {
        if {[string match $pattern $name]} {
            lappend names $name
        }
    }

    return $names
}
