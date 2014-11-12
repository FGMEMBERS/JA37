# $Id$

var UPDATE_PERIOD = 0.1;

var g_curr 	= props.globals.getNode("accelerations/pilot-gdamped", 1);

var prevGear0 = 1;
var prevGear1 = 1;
var prevGear2 = 1;
var touchdown1 = 0;
var touchdown2 = 0;
var total_fuel = 0;
var bingoFuel = 0;
############### Main loop ###############

input = {
  replay:       "sim/replay/replay-state",
  g3d:          "/velocities/groundspeed-3D-kt",
  wow0:         "/gear/gear[0]/wow",
  wow1:         "/gear/gear[1]/wow",
  wow2:         "/gear/gear[2]/wow",
  elapsed:      "sim/time/elapsed-sec",
  elapsedInit:  "sim/time/elapsed-at-init-sec",
  fullInit:     "sim/time/full-init",
  tank8LvlNorm: "/consumables/fuel/tank[8]/level-norm",
  tank0LvlGal:  "/consumables/fuel/tank[0]/level-gal_us",
  tank1LvlGal:  "/consumables/fuel/tank[1]/level-gal_us",
  tank2LvlGal:  "/consumables/fuel/tank[2]/level-gal_us",
  tank3LvlGal:  "/consumables/fuel/tank[3]/level-gal_us",
  tank4LvlGal:  "/consumables/fuel/tank[4]/level-gal_us",
  tank5LvlGal:  "/consumables/fuel/tank[5]/level-gal_us",
  tank6LvlGal:  "/consumables/fuel/tank[6]/level-gal_us",
  tank7LvlGal:  "/consumables/fuel/tank[7]/level-gal_us",
  tank8LvlGal:  "/consumables/fuel/tank[8]/level-gal_us",
  fuelNeedleB:  "/instrumentation/fuel/needleB_rot",
  fuelNeedleF:  "/instrumentation/fuel/needleF_rot",
  fuelWarning:  "sim/ja37/sound/fuel-low-on",
  n1:           "/engines/engine/n1",
  n2:           "/engines/engine/n2",
  reversed:     "/engines/engine/reversed",
  augmentation: "/controls/engines/engine[0]/augmentation",
  gearCmdNorm:  "/fdm/jsbsim/gear/gear-cmd-norm",
  batteryOutput:"systems/electrical/outputs/battery",
  flapPosCmd:   "/fdm/jsbsim/fcs/flap-pos-cmd",
  serviceElec:  "systems/electrical/serviceable",
  canopyPower:  "/fdm/jsbsim/fcs/canopy/has-power",
  vgFps:        "/fdm/jsbsim/velocities/vg-fps",
  downFps:      "/velocities/down-relground-fps",
  thrustLb:     "engines/engine/thrust_lb",
  thrustLbAbs:  "engines/engine/thrust_lb-absolute",
  indAltMeter:  "instrumentation/altimeter/indicated-altitude-meter",
  indAltFt:     "instrumentation/altimeter/indicated-altitude-ft",
  autoReverse:  "sim/ja37/autoReverseThrust",
  stationSelect:"controls/armament/station-select",
  combat:       "/sim/ja37/hud/combat",
  warnButton:   "sim/ja37/avionics/master-warning-button",
  warn:         "/instrumentation/master-warning",
  engineRunning:"engines/engine/running",
  hz10:         "sim/ja37/blink/ten-Hz/state",
  hz05:         "sim/ja37/blink/five-Hz/state",
  flame:        "engines/engine/flame",
  generatorOn:  "/systems/electrical/generator_on",
  mass1:        "fdm/jsbsim/inertia/pointmass-weight-lbs[1]",
  mass3:        "fdm/jsbsim/inertia/pointmass-weight-lbs[3]",
  asymLoad:     "fdm/jsbsim/inertia/asymmetric-wing-load",
  indJoy:       "/instrumentation/joystick-indicator",
  indAtt:       "/instrumentation/attitude-indicator",
  indAlt:       "/instrumentation/altitude-indicator",
  indTrn:       "/instrumentation/transonic-indicator",
  indRev:       "/instrumentation/reverse-indicator",
  tank8Flow:    "fdm/jsbsim/propulsion/tank[8]/external-flow-rate-pps",
  tank8Selected:"/consumables/fuel/tank[8]/selected",
  tank8Jettison:"/consumables/fuel/tank[8]/jettisoned",
  lockHeading:  "/autopilot/locks/heading",
  lockAltitude: "/autopilot/locks/altitude",
  lockPassive:  "/autopilot/locks/passive-mode",
  roll:         "/instrumentation/attitude-indicator/indicated-roll-deg",
  speedMach:    "/instrumentation/airspeed-indicator/indicated-mach",
  speedKt:      "/instrumentation/airspeed-indicator/indicated-speed-kt",
};
   
var update_loop = func {
  if(input.replay.getValue() == 1) {
    # replay is active, skip rest of loop.
    settimer(update_loop, UPDATE_PERIOD);
  } else {
    # set the full-init property
    if(input.elapsed.getValue() > input.elapsedInit.getValue() + 5) {
      input.fullInit.setValue(1);
    } else {
      input.fullInit.setValue(0);
    }

  	 ## Sets fuel gauge needles rotation ##
  	 
     if(input.tank8LvlNorm.getValue() != nil) {
       input.fuelNeedleB.setValue(input.tank8LvlNorm.getValue()*230);
     }     

    var current = input.tank0LvlGal.getValue()
                + input.tank1LvlGal.getValue()
                + input.tank2LvlGal.getValue()
                + input.tank3LvlGal.getValue()
                + input.tank4LvlGal.getValue()
                + input.tank5LvlGal.getValue()
                + input.tank6LvlGal.getValue()
                + input.tank7LvlGal.getValue();


    input.fuelNeedleF.setValue((current / total_fuel) *230);

    # fuel warning annuciator
    if((current / total_fuel) < 0.24) {# warning at 24% as per sources
      input.fuelWarning.setValue(1);
    } else {
      input.fuelWarning.setValue(0);
    }

    if (current > 0 and input.tank8LvlNorm.getValue() > 0) {
      bingoFuel = 0;
    } else {
      bingoFuel = 1;
    }

    ## control augmented thrust ##
     
    var n1 = input.n1.getValue();
    var n2 = input.n2.getValue();
    var reversed = input.reversed.getValue();

    if ( (n1 > 102) and (n2 > 99) and (reversed == 0) ) { #was 99 and 97
      input.augmentation.setValue(1);
    } else {
      input.augmentation.setValue(0);
    }

    ## control flaps ##

    var flapsCommand = 0;
    var gear = input.gearCmdNorm.getValue();
    var battery = input.batteryOutput.getValue();

    if ((battery < 25) or (gear == nil)) {
      flapsCommand = 0.11765;
    } else {
      flapsCommand = gear;
    }
    if (input.flapPosCmd.getValue() != flapsCommand) {
      #trying to not write to fdm unless changed.
      input.flapPosCmd.setValue(flapsCommand);
    }
    
    if (input.serviceElec.getValue() < 1) {
      if (input.canopyPower.getValue() != 0) {
        input.canopyPower.setValue(0);
      }
    } else {
      if (input.canopyPower.getValue() != 1) {
        input.canopyPower.setValue(1);
      }
    }

    #if(getprop("/sim/failure-manager/controls/flight/rudder/serviceable") == 1) {
    #  setprop("fdm/jsbsim/fcs/rudder/serviceable", 1);
    #} elsif (getprop("fdm/jsbsim/fcs/rudder/serviceable") == 1) {
    #  setprop("fdm/jsbsim/fcs/rudder-sum-stuck", getprop("fdm/jsbsim/fcs/rudder-sum"));
    #  setprop("fdm/jsbsim/fcs/rudder-serviceable", 0);
    #}

    ## set groundspeed property used for crashcode ##
    var horz_speed = input.vgFps.getValue();
    var vert_speed = input.downFps.getValue();
    var real_speed = math.sqrt((horz_speed * horz_speed) + (vert_speed * vert_speed));
    real_speed = real_speed * 0.5924838;
    input.g3d.setValue(real_speed);
    
    
    # Animating engine fire
    if (n1 > 100) n1 = 100;
    var flame = 100 / (100-n1);
    input.flame.setValue(flame);


    # indicators
    var joystick = 0;
    var attitude = 0;
    var altitude = 0;
    var transonic = 0;
    var rev = 0;

    # joystick indicator
    if(input.generatorOn.getValue() == 1) {
      if (((input.lockHeading.getValue() != '' and input.lockHeading.getValue() != nil) and (input.lockAltitude.getValue() != ''
       and input.lockAltitude.getValue() != nil)) or input.lockPassive.getValue() == 1 and input.batteryOutput.getValue() > 23) {
        joystick = 0;
      } else {
        joystick = 1;
      }
    } else {
      joystick = 0;
    }

    # attitude indicator
    if(input.lockPassive.getValue() == 1 or (input.lockHeading.getValue() != '' and input.lockHeading.getValue() != nil)
     and input.batteryOutput.getValue() > 23) {
      if (input.roll.getValue() > 70 or input.roll.getValue() < -70) {
        attitude = input.hz05.getValue();
      } else {
        attitude = 1;
      }
    } else {
      attitude = 0;
    }

    # altitude indicator
    if(input.lockPassive.getValue() == 1 or (input.lockAltitude.getValue() != '' and input.lockAltitude.getValue() != nil)
     and input.batteryOutput.getValue() > 23) {
      if (input.speedMach.getValue() > 0.97 and input.speedMach.getValue() < 1.05) {
        altitude = input.hz05.getValue();
      } else {
        altitude = 1;
      }
    } else {
      altitude = 0;
    }

    #transonic indicator
    if (input.speedMach.getValue() > 0.97 and input.speedMach.getValue() < 1.05
     and input.batteryOutput.getValue() > 23) {
      transonic = 1;
    } else {
      if(input.reversed.getValue() == 1 and input.speedKt.getValue() < 64.8 and input.batteryOutput.getValue() > 23) {
        # warning that speed is so low that its risky to continue reverse thrust
          transonic = 1;
        } else {
          transonic = 0;
        }
    }

    # reverse indicator
    if(input.reversed.getValue() == 1 and input.batteryOutput.getValue() > 23) {
      rev = 1;
    } else {
      rev = 0;
    }

    input.indJoy.setValue(joystick);
    input.indAtt.setValue(attitude);
    input.indAlt.setValue(altitude);
    input.indTrn.setValue(transonic);
    input.indRev.setValue(rev);

    # pylon payloads

    for(var i=0; i<=4; i=i+1) {
      if(getprop("payload/weight["~ (i) ~"]/selected") != "none" and getprop("payload/weight["~ (i) ~"]/weight-lb") == 0) {
        # missile was loaded manually through payload/fuel dialog, so setting the pylon to not released
        setprop("controls/armament/station["~(i+1)~"]/released", 0);
        #print("adding "~i);
        if(i != 4) {
          #not drop tank
          if(armament.AIM9.new(i) == -1) {
            #missile added through menu while another from that pylon is still flying.
            #to handle this we have to ignore that addition.
            setprop("controls/armament/station["~(i+1)~"]/released", 1);
            setprop("payload/weight["~ (i) ~"]/selected", "none");
            #print("refusing to mount new missile yet "~i);
          }
          #print("new "~(i-1));

        }
      }
      #if(i!=0 and getprop("payload/weight["~ (i-1) ~"]/selected") == "none" and getprop("payload/weight["~ (i-1) ~"]/weight-lb") != 0) {
      #  if(armament.AIM9.active[i-1] != nil) {
          # pylon emptied through menu, so remove the logic
          #print("removing "~i);
      #    armament.AIM9.active[i-1].del();
      #  } 
      #}
    }

    #activate searcher on selected pylon if missile mounted
    var armSelect = input.stationSelect.getValue();
    for(i = 0; i <= 3; i += 1) {
      if(armament.AIM9.active[i] != nil) {
        #missile is mounted on pylon
        if(armSelect != i+1) {
          #pylon not selected, missile off
          armament.AIM9.active[i].status = -1;#print("not sel "~(i));
        } elsif (input.combat.getValue() == 0 or (armament.AIM9.active[i].status != -1 and armament.AIM9.active[i].status != 2 and getprop("payload/weight["~ (i) ~"]/selected") == "none")) {
          #pylon is selected but missile not mounted and not flying
          armament.AIM9.active[i].status = -1;#print("empty "~(i));
        } elsif (armament.AIM9.active[i].status == -1 and getprop("payload/weight["~ (i) ~"]/selected") != "none" and input.combat.getValue() == 1) {
          #pylon selected, activate if not already
          armament.AIM9.active[i].status = 0;#print("active "~(i));
          armament.AIM9.active[i].search();
        }
      }
    }

    var selected = nil;
    for(var i=0; i<=4; i=i+1) { # set JSBSim mass
      selected = getprop("payload/weight["~i~"]/selected");
      if(selected == "none") {
        # the pylon is empty, set its pointmass to zero
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 0) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 0);
        }
        if(i==4) {
          # no drop tank attached
          if (input.tank8Flow.getValue() != -1500) {
            input.tank8Flow.setValue(-1500);
          }
          input.tank8Selected.setValue(0);
          input.tank8Jettison.setValue(1);
          input.tank8LvlNorm.setValue(0);
        }
      } elsif (selected == "RB 24J") {
        # the pylon has a sidewinder, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 188) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 188);
        }
      } elsif (selected == "Drop tank") {
        # the pylon has a drop tank, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") == 0 or input.tank8Flow.getValue() != 0) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 224.87);#if change this also change it in jsbsim
          input.tank8Flow.setValue(0);
        }
        input.tank8Selected.setValue(1);
        input.tank8Jettison.setValue(0);
      }
    }

    # for aerodynamic response to asymmetric wing loading
    if(input.mass1.getValue() == input.mass3.getValue()) {
      # wing pylons symmetric loaded
      if (input.asymLoad.getValue() != 0) {
        input.asymLoad.setValue(0);
      }
    } elsif(input.mass1.getValue() < input.mass3.getValue()) {
      # right wing pylon has more load than left
      if (input.asymLoad.getValue() != -1) {
        input.asymLoad.setValue(-1);
      }
    } else {
      # left wing pylon has more load than right
      if (input.asymLoad.getValue() != 1) {
        input.asymLoad.setValue(1);
      }
    }


    # automatic reverse thrust enabler

    var gear0 = input.wow0.getValue();
    var gear1 = input.wow1.getValue();
    var gear2 = input.wow2.getValue();

    if(input.autoReverse.getValue() == 1 and reversed == 0) {
      if(gear1 == 1) {
        #left boogie touching
        if(prevGear1 == 0) {
          touchdown1 = 1;
        }
      } else {
        touchdown1 = 0;
      }
      if(gear2 == 1) {
        #right boogie touching
        if(prevGear2 == 0) {
          touchdown2 = 1;
        }
      } else {
        touchdown2 = 0;
      }
      if(touchdown1 == 1 and touchdown2 == 1) {
        if(gear0 == 1) {
          #print("Auto-reversing the thrust");
          touchdown1 = 0;
          touchdown2 = 0;
          reversethrust.togglereverser();
        }
      }
    }

    prevGear0 = gear0;
    prevGear1 = gear1;
    prevGear2 = gear2;

    # Make sure have engine sound at reverse thrust

    var thrust = input.thrustLb.getValue();
     
    if(thrust != nil) {
      input.thrustLbAbs.setValue(abs(thrust));
    } else {
      input.thrustLbAbs.setValue(0);
    }

    # meter altitude property

    input.indAltMeter.setValue(input.indAltFt.getValue()*0.3048);

    # front gear compression calc for spinning of wheel
    # setprop("gear/gear/compression-wheel", (getprop("gear/gear/compression-ft")*0.3048-1.84812));

    # Master warning
    if(input.batteryOutput.getValue() > 23 ) {
      if (input.warnButton.getValue() == 1) {
        # test, should really be turn off sound
        input.warn.setValue(1);
      } elsif (input.engineRunning.getValue() == 0 and autostarting == 0 and input.wow0.getValue() == 0) {
        # Major warning
        if(input.hz10.getValue() == 1) {
          input.warn.setValue(1);
        } else {
          input.warn.setValue(0);
        }
      } elsif (1 == 0) {
        # minor warning
        if(input.hz05.getValue() == 1) {
          input.warn.setValue(1);
        } else {
          input.warn.setValue(0);
        }
      } else {
        input.warn.setValue(0);
      }
    } else {
      input.warn.setValue(0);
    }

    


    settimer(
      #func debug.benchmark("j37 loop", 
        update_loop
        #)
    , UPDATE_PERIOD);
  }
}


###########  listener for handling the trigger #########
    
var trigger_listener = func {
    var trigger = getprop("controls/armament/trigger");
    var armSelect = getprop("controls/armament/station-select");

    #if masterarm is on, propagate trigger to station
    if(getprop("/sim/ja37/hud/combat") == 1) {
      setprop("/controls/armament/station["~armSelect~"]/trigger", trigger);
    }

    if(armSelect != 0 and getprop("/controls/armament/station["~armSelect~"]/trigger") == 1) {
      if(getprop("payload/weight["~(armSelect-1)~"]/selected") != "none") { 
        # trigger is pulled, a pylon is selected, the pylon has a missile.
        if (armament.AIM9.active[armSelect-1] != nil and  armament.AIM9.active[armSelect-1].status == 1 ) {
          #missile locked, fire it.
          setprop("payload/weight["~ (armSelect-1) ~"]/selected", "none");# empty the pylon
          setprop("controls/armament/station["~armSelect~"]/released", 1);# setting the pylon as fired
          #print("firing missile: "~armSelect~" "~getprop("controls/armament/station["~armSelect~"]/released"));
        
          armament.AIM9.active[armSelect-1].release();#print("release "~(armSelect-1));
        }
      }
    }
}
setlistener("controls/armament/trigger", trigger_listener, 0, 0);

var cycle_weapons = func {
  var sel = getprop("controls/armament/station-select");
  sel += 1;
  if(sel > 4) {
    sel = 0;
  }
  click();
  setprop("controls/armament/station-select", sel)
}

###########  loop for handling the battery signal for cockpit sound #########

var battery_listener = func {
    if (getprop("controls/electric/battery-switch") == 1) {
      setprop("/systems/electrical/batterysignal", 1);

      settimer(func {
        setprop("/systems/electrical/batterysignal", 0);
        }, 6);
    }
}
setlistener("controls/electric/battery-switch", battery_listener, 0, 0);
                
###############  Test which system the flightgear version support.  ###########

var test_support = func {
 
  var versionString = getprop("sim/version/flightgear");
  var version = split(".", versionString);
  if (version[0] == "0" or version[0] == "1") {
    gui.popupTip("JA-37 is only supported in Flightgear version 2.8 and upwards. Sorry.");
      setprop("sim/ja37/supported/radar", 0);
      setprop("sim/ja37/supported/hud", 0);
      setprop("sim/ja37/supported/options", 0);
      setprop("sim/ja37/supported/old-custom-fails", 0);
  } elsif (version[0] == "2") {
    if(version[1] == "0" or version[1] == "2" or version[1] == "4" or version[1] == "6") {
      gui.popupTip("JA-37 is only supported in Flightgear version 2.8 and upwards. Sorry.");
      setprop("sim/ja37/supported/radar", 0);
      setprop("sim/ja37/supported/hud", 0);
      setprop("sim/ja37/supported/options", 0);
      setprop("sim/ja37/supported/old-custom-fails", 1);
    } elsif(version[1] == "8") {
      gui.popupTip("JA-37 Canvas Radar and HUD is only supported in Flightgear version 2.10 and upwards. They have been disabled.");
      setprop("sim/ja37/supported/radar", 0);
      setprop("sim/ja37/supported/hud", 0);
      setprop("sim/ja37/supported/options", 0);
      setprop("sim/ja37/supported/old-custom-fails", 1);
      setprop("sim/ja37/hud/mode", 0);
    } else {
      setprop("sim/ja37/supported/radar", 1);
      setprop("sim/ja37/supported/hud", 1);
      setprop("sim/ja37/supported/options", 0);
      setprop("sim/ja37/supported/old-custom-fails", 1);
    }
  } elsif (version[0] == "3" or version[0] == "4" or version[0] == "5" or version[0] == "6" or version[0] == "7") {
    setprop("sim/ja37/supported/options", 1);
    setprop("sim/ja37/supported/radar", 1);
    setprop("sim/ja37/supported/hud", 1);
    setprop("sim/ja37/supported/old-custom-fails", 0);
    if (version[1] == "0") {
      setprop("sim/ja37/supported/old-custom-fails", 1);
    }
  }
  setprop("sim/ja37/supported/initialized", 1);

  print("********************************************************************************");
  print("**  Initializing Saab JA-37 Viggen systems. Version "~getprop("sim/aircraft-version")~" on Flightgear "~version[0]~"."~version[1]~"."~version[2]~"  **");
  print("********************************************************************************");

}

############################# main init ###############


var main_init = func {
  setprop("sim/time/elapsed-at-init-sec", getprop("sim/time/elapsed-sec"));

  test_support();

  aircraft.data.add("sim/ja37/radar/enabled",
                    "sim/ja37/hud/units-metric",
                    "sim/ja37/hud/mode",
                    "sim/ja37/hud/bank-indicator",
                    "sim/ja37/autoReverseThrust");
  aircraft.data.save();

  setprop("/consumables/fuel/tank[8]/jettisoned", 0);

  total_fuel = getprop("/consumables/fuel/tank[0]/capacity-gal_us")
                + getprop("/consumables/fuel/tank[1]/capacity-gal_us")
                + getprop("/consumables/fuel/tank[2]/capacity-gal_us")
                + getprop("/consumables/fuel/tank[3]/capacity-gal_us")
                + getprop("/consumables/fuel/tank[4]/capacity-gal_us")
                + getprop("/consumables/fuel/tank[5]/capacity-gal_us")
                + getprop("/consumables/fuel/tank[6]/capacity-gal_us")
                + getprop("/consumables/fuel/tank[7]/capacity-gal_us");

  # Load exterior at startup to avoid stale sim at first external view selection. ( taken from TU-154B )
  print("Loading exterior, wait...");
  # return to cabin to next cycle
  settimer( load_interior, 0 );
  setprop("/sim/current-view/view-number", 1);
  setprop("/sim/gui/tooltips-enabled", 1);
  
  # inst. light

  setprop("/instrumentation/instrumentation-light/r", 1.0);
  setprop("/instrumentation/instrumentation-light/g", 0.3);
  setprop("/instrumentation/instrumentation-light/b", 0.0);

  # setup property nodes for the loop
  foreach(var name; keys(input)) {
      input[name] = props.globals.getNode(input[name], 1);
  }

  screen.log.write("Welcome to Saab JA-37 Viggen, version "~getprop("sim/aircraft-version"), 1.0, 0.0, 0.0);

  # start chronometer loop
  chrono_loop();

  # start the main loop
	settimer(func { update_loop() }, 0.1);
}

# re init
var re_init = func {
  print("Re-initializing JA-37 Viggen systems");
  
  setprop("sim/time/elapsed-at-init-sec", getprop("sim/time/elapsed-sec"));

  test_support();
}

var load_interior = func{
    setprop("/sim/current-view/view-number", 0);
    print("..Done!");
  }

var main_init_listener = setlistener("sim/signals/fdm-initialized", func {
	main_init();
	removelistener(main_init_listener);
 }, 0, 0);

var re_init_listener = setlistener("/sim/signals/reinit", func {
  re_init();
 }, 0, 0);

############ droptank #####################

var drop = func {
    if (getprop("/consumables/fuel/tank[8]/jettisoned") == 1) {
       gui.popupTip("Drop tank already jettisoned.");
       return;
    }  
    if (getprop("/gear/gear[0]/wow") > 0.05) {
       gui.popupTip("Can not eject drop tank while on ground!"); 
       return;
    }  
    click();
    setprop("payload/weight[4]/selected", "none");# empty the pylon
    gui.popupTip("Drop tank shut off and ejected. Using internal fuel.");
 }

############ strobes #####################

var strobe_switch = props.globals.getNode("controls/lighting/ext-lighting-panel/anti-collision", 1);
setprop("controls/lighting/ext-lighting-panel/anti-collision", 1);
aircraft.light.new("sim/model/lighting/strobe", [0.03, 1.9+rand()/5], strobe_switch);

var beacon_switch = props.globals.getNode("controls/switches/beacon", 2);
setprop("controls/switches/beacon", 1);
var beacon = aircraft.light.new( "sim/model/lighting/beacon", [0, 1], beacon_switch );

############ blinkers ####################

aircraft.light.new("sim/ja37/blink/five-Hz", [0.2, 0.2], "controls/electric/battery-switch");
aircraft.light.new("sim/ja37/blink/ten-Hz", [0.1, 0.1], "controls/electric/battery-switch");

############# workaround for removing default HUD   ##############

#setlistener("/sim/current-view/view-number", func(n) {
#        setprop("/sim/hud/visibility[1]", !n.getValue());
#}, 1, 0);

###################### autostart ########################

var autostarting = 0;
var start_count = 0;

#Default 's' button will set starter to false, so will start delayed.
var autostarttimer = func {
  if (autostarting == 0) {
    autostarting = 1;
    if (getprop("/engines/engine[0]/running") > 0) {
     gui.popupTip("Stopping engine. Turning off battery.");
     click();
     setprop("/controls/engines/engine[0]/cutoff", 1);
  	 setprop("/controls/engines/engine[0]/starter", 0);
     setprop("/controls/electric/engine[0]/generator", 0);
  	 setprop("/controls/electric/battery-switch", 0);
     autostarting = 0;
    } else {
      #print("autostarting");
      if (getprop("sim/ja37/damage/crashed") < 1) {
        setprop("/controls/electric/battery-switch", 1);
        click();
        gui.popupTip("Battery switch on. Check.");
    	  settimer(autostart, 2, 1);
      } else {
        gui.popupTip("Engine not reacting. Consider ejecting yourself.");
        autostarting = 0;
      }
    }
  }
}

#Simulating autostart function
var autostart = func {
  setprop("/controls/electric/engine[0]/generator", 0);
  if (getprop("controls/electric/engine[0]/generator") == 0) {
    gui.popupTip("Starting engine.");
    click();
    setprop("/controls/engines/engine[0]/cutoff", 1);
    setprop("/controls/engines/engine[0]/starter", 1);
    start_count = 0;
    settimer(waiting_n1, 0.5, 1);
  } else {
    gui.popupTip("Generator switch turned on. Engine restart aborted.");
    autostarting = 0;
  }
}

# Opens fuel valve in autostart
var waiting_n1 = func {
  start_count += 1;
  #print(start_count);
  if (start_count > 45) {
    if(bingoFuel == 0) {
      gui.popupTip("Autostart failed. Report bug to aircraft developer.");
    } else {
      gui.popupTip("Engine start failed. Check fuel.");
    }
    print("Autostart failed. n1="~getprop("/engines/engine[0]/n1")~" cutoff="~getprop("/controls/engines/engine[0]/cutoff")~" starter="~getprop("/controls/engines/engine[0]/starter")~" generator="~getprop("/controls/electric/engine[0]/generator")~" battery="~getprop("/controls/electric/battery-switch")~" fuel="~bingoFuel);
    setprop("/controls/engines/engine[0]/cutoff", 1);
    setprop("/controls/engines/engine[0]/starter", 0);
    setprop("/controls/electric/engine[0]/generator", 0);
    setprop("/controls/electric/battery-switch", 0);
    autostarting = 0;
  } elsif (getprop("/engines/engine[0]/n1") > 4.9) {
    if (getprop("/engines/engine[0]/n1") < 20) {
      if (getprop("/controls/engines/engine[0]/cutoff") == 1) {
        click();
        setprop("/controls/engines/engine[0]/cutoff", 0);
        if (getprop("/controls/engines/engine[0]/cutoff") == 0) {
          gui.popupTip("Engine igniting.");
          settimer(waiting_n1, 0.5, 1);
        } else {
          print("Autostart failed 2. n1="~getprop("/engines/engine[0]/n1")~" cutoff="~getprop("/controls/engines/engine[0]/cutoff")~" starter="~getprop("/controls/engines/engine[0]/starter")~" generator="~getprop("/controls/electric/engine[0]/generator")~" battery="~getprop("/controls/electric/battery-switch")~" fuel="~bingoFuel);
          setprop("/controls/engines/engine[0]/starter", 0);
          gui.popupTip("Engine not igniting. Aborting engine start.");
          autostarting = 0;
        }
      } else {
        settimer(waiting_n1, 0.5, 1);
      }
    }  elsif (getprop("/engines/engine[0]/n1") > 15) {
      #print("Autostart success. n1="~getprop("/engines/engine[0]/n1")~" cutoff="~getprop("/controls/engines/engine[0]/cutoff")~" starter="~getprop("/controls/engines/engine[0]/starter")~" generator="~getprop("/controls/electric/engine[0]/generator")~" battery="~getprop("/controls/electric/battery-switch"));
      click();
      setprop("controls/electric/engine[0]/generator", 1);
      gui.popupTip("Generator on.");
      settimer(final_engine, 0.5, 1);
    } else {
      settimer(waiting_n1, 0.5, 1);
    }
  } else {
    settimer(waiting_n1, 0.5, 1);
  }
}

var final_engine = func () {
  start_count += 1;
  if (start_count > 70) {
    if(bingoFuel == 0) {
      gui.popupTip("Autostart failed. If engine has not reported failure, report bug to aircraft developer.");
    } else {
      gui.popupTip("Engine start failed. Check fuel.");
    }    
    print("Autostart failed 3. n1="~getprop("/engines/engine[0]/n1")~" cutoff="~getprop("/controls/engines/engine[0]/cutoff")~" starter="~getprop("/controls/engines/engine[0]/starter")~" generator="~getprop("/controls/electric/engine[0]/generator")~" battery="~getprop("/controls/electric/battery-switch")~" fuel="~bingoFuel);
    setprop("/controls/engines/engine[0]/cutoff", 1);
    setprop("/controls/engines/engine[0]/starter", 0);
    setprop("/controls/electric/engine[0]/generator", 0);
    setprop("/controls/electric/battery-switch", 0);
    autostarting = 0;    
  } elsif (getprop("/engines/engine[0]/running") > 0) {
    gui.popupTip("Engine ready.");
    autostarting = 0;    
  } else {
    settimer(final_engine, 0.5, 1);
  }
}

var clicking = 0;
var click = func {
    if(clicking == 0) {
      clicking = 1;
      setprop("sim/ja37/sound/click-on", 1);
      settimer(clickOff, 0.15, 1);
    }
}

var clickOff = func {
    setprop("sim/ja37/sound/click-on", 0);
    clicking = 0;
}

var noop = func {
  #does nothing, but important
}

var toggleYawDamper = func {
  ja37.click();
  var enabled = getprop("fdm/jsbsim/fcs/yaw-damper-enable");
  setprop("fdm/jsbsim/fcs/yaw-damper-enable", !enabled);
  if(enabled == 0) {
    gui.popupTip("Yaw damper: ON");
  } else {
    gui.popupTip("Yaw damper: OFF");
  }
}

var toggleHook = func {
  ja37.click();
  var enabled = getprop("fdm/jsbsim/systems/hook/tailhook-cmd-norm");
  setprop("fdm/jsbsim/systems/hook/tailhook-cmd-norm", !enabled);
  if(enabled == 0) {
    gui.popupTip("Arrester hook: Extended");
  } else {
    gui.popupTip("Arrester hook: Retracted");
  }
}

var toggleNosewheelSteer = func {
  ja37.click();
  var enabled = getprop("fdm/jsbsim/systems/nose-wheel-steer/enable");
  setprop("fdm/jsbsim/systems/nose-wheel-steer/enable", !enabled);
  if(enabled == 0) {
    gui.popupTip("Nose Wheel Steering: ON", 1.5);
  } else {
    gui.popupTip("Nose Wheel Steering: OFF", 1.5);
  }
}

var follow = func () {
  setprop("/autopilot/target-tracking-ja37/enable", 0);
  if(canvas_HUD.selection != nil) {
    var target = canvas_HUD.selection[5];
    setprop("/autopilot/target-tracking-ja37/target-root", target.getPath());
    #this is done in -set file: /autopilot/target-tracking-ja37/min-speed-kt
    setprop("/autopilot/target-tracking-ja37/enable", 1);
    var range = 0.025;
    setprop("/autopilot/target-tracking-ja37/goal-range-nm", range);
    gui.popupTip("A/P follow: ON");

    setprop("autopilot/settings/target-altitude-ft", 10000);# set some default values until the follow script sets them.
    setprop("autopilot/settings/heading-bug-deg", 0);
    setprop("autopilot/settings/target-speed-kt", 200);

    setprop("/autopilot/locks/speed", "speed-with-throttle");
    setprop("/autopilot/locks/altitude", "altitude-hold");
    setprop("/autopilot/locks/heading", "dg-heading-hold");
  } else {
    setprop("/autopilot/target-tracking-ja37/enable", 0);
    gui.popupTip("A/P follow: no valid target.");
    setprop("/autopilot/locks/speed", "");
    setprop("/autopilot/locks/altitude", "");
    setprop("/autopilot/locks/heading", "");
  }
}

var unfollow = func () {
  setprop("/autopilot/target-tracking-ja37/enable", 0);
  gui.popupTip("A/P follow: OFF");
  setprop("/autopilot/locks/speed", "");
  setprop("/autopilot/locks/altitude", "");
  setprop("/autopilot/locks/heading", "");
}

var lostfollow = func () {
  setprop("/autopilot/target-tracking-ja37/enable", 0);
  gui.popupTip("A/P follow: lost target.");
  setprop("/autopilot/locks/speed", "");
  setprop("/autopilot/locks/altitude", "");
  setprop("/autopilot/locks/heading", "");
}

var applyParkingBrake = func(v) {
    controls.applyParkingBrake(v);
    if(!v) return;
    ja37.click();
    if (getprop("/controls/gear/brake-parking") == 1) {
      gui.popupTip("Parking brakes: ON");
    } else {
      gui.popupTip("Parking brakes: OFF");
    }
}

var cycleSmoke = func() {
    ja37.click();
    if (getprop("/sim/ja37/effect/smoke") == 1) {
      setprop("/sim/ja37/effect/smoke", 2);
      gui.popupTip("Smoke: Yellow");
    } elsif (getprop("/sim/ja37/effect/smoke") == 2) {
      setprop("/sim/ja37/effect/smoke", 3);
      gui.popupTip("Smoke: Blue");
    } else {
      setprop("/sim/ja37/effect/smoke", 1);#1 for backward compatibility to be off per default
      gui.popupTip("Smoke: OFF");
    }
}