###
# Behaviors to enforce on morph
###
oo::define oo::class {
  ###
  # topic: d15a85525b1f7151cd808e592bc09fed
  ###
  method morph newclass {
    if {$newclass eq {}} return
    set class [string trimleft [info object class [self]]]
    set newclass [string trimleft $newclass :]
    if {[info command ::$newclass] eq {}} {
      error "Class $newclass does not exist"
    }
    if { $class ne $newclass } {
      my Morph_leave
      oo::objdefine [self] class ::${newclass}
      my variable config
      set savestate $config
      my _staticInit
      my configurelist $savestate
      my Morph_enter
    }
  }

  method Morph_leave {} {}
  method Morph_enter {} {}

}