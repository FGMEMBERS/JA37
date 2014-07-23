# ==============================================================================
# Head up display
#
# Nicked some code from the buccaneer and the wiki example to get started
#
# Made for the JA-37 by Necolatis
# ==============================================================================

var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }
var pow2 = func(x) { return x * x; };
var vec_length = func(x, y) { return math.sqrt(pow2(x) + pow2(y)); };
var round0 = func(x) { return math.abs(x) > 0.01 ? x : 0; };
var roundabout = func(x) {
  var y = x - int(x);

  return y < 0.5 ? int(x) : 1 + int(x) ;
};
var deg2rads = math.pi/180.0;
var blinking = 0; # how many updates the speed vector symbol has been turned off for blinking (convert to time when less lazy)
var alt_scale_mode = -1; # the alt scale is not liniar, this indicates which part is showed
var QFE = 0;
var countQFE = 0;
var QFEcalibrated = 0;
var centerOffset = -90; #pilot eye position up from vertical center of HUD. (in line from pilots eyes)
# HUD z is 0.864636-0.334795 (0.529841) to 0.967040-0.334795 (0.632245) and raised 0.06 up. Finally is 0.589841m to 0.692245m, height of HUD is 0.102404m
# Therefore each pixel is 0.102404 / 1024 = 0.00010000390625m or each meter is 9999.609390258193 pixels.
# View is 0.65m so 0.692245-0.65 = 0.042245m down from top of HUD, since Y in HUD increases downwards we get pixels from top:
# 512 - (0.042245 / 0.00010000390625) = 89.56650130854264 pixels up from center. Since -y is upward, result is -90.
var pixelPerDegree = 65; #vertical axis, view is tilted 10 degrees, zoom in on runway to check it hit the 10deg line
var slant = 35; #degrees the HUD is slanted away from the pilot.
var sidewindPosition = centerOffset+(2*pixelPerDegree); #should be 2 degrees under horizon.
var sidewindPerKnot = 450/30; # Max sidewind displayed is set at 30 kts. 450pixels is maximum is can move to the side.
var radPointerProxim = 60; #when alt indicater is too close to radar ground indicator, hide indicator
var scalePlace = 380; #horizontal placement of alt scales
var numberOffset = 100; #alt scale numbers horizontal offset from scale 
var indicatorOffset = -10; #alt scale indicators horizontal offset from scale (must be high, due to bug #1054 in canvas) 
var headScalePlace = 300; # vert placement of alt scale
var altimeterScaleHeight = 300; # the height of the low alt scale. Also used in the other scales as a reference height.
  var r = 0.0;
  var g = 1.0;
  var b = 0.0;#HUD colors
  var a = 1.0;
  var w = 10;  #line stroke width
  var ar = 0.9;#font aspect ratio
  var fs = 1.0;#font size factor
  var artifacts0 = nil;
  var artifacts1 = [];
#print("Starting JA-37 HUD");

var HUDnasal = {
  canvas_settings: {
    "name": "HUDnasal",
    "size": [2048, 2048],# width of texture to be replaced
	  "view": [1024, 1024],# width of canvas
    "mipmapping": 1
  },
  main: nil,
  new: func(placement)
  {
    if(HUDnasal.main == nil) {
      HUDnasal.main = {
        parents: [HUDnasal],
        canvas: canvas.new(HUDnasal.canvas_settings),
        text_style: {
          'font': "LiberationFonts/LiberationMono-Regular.ttf", 
          'character-size': 100,
        },
        place: placement
      };
    
 
      
    	
      HUDnasal.main.input = {
        pitch:    "/orientation/pitch-deg",
        roll:     "/orientation/roll-deg",
  #     hdg:      "/instrumentation/magnetic-compass/indicated-heading-deg",
  #      hdg:      "/instrumentation/gps/indicated-track-magnetic-deg",
        hdg:      "/orientation/heading-magnetic-deg",
        hdgReal:  "/orientation/heading-deg",
        speed_n:  "velocities/speed-north-fps",
        speed_e:  "velocities/speed-east-fps",
        speed_d:  "velocities/speed-down-fps",
        alpha:    "/orientation/alpha-deg",
        beta:     "/orientation/side-slip-deg",
        ias:      "/velocities/airspeed-kt",
        mach:      "/velocities/mach",
        gs:       "/velocities/groundspeed-kt",
        vs:       "/velocities/vertical-speed-fps",
        rad_alt:  "position/altitude-agl-ft",#/instrumentation/radar-altimeter/radar-altitude-ft",
        alt_ft:   "/instrumentation/altimeter/indicated-altitude-ft",
        wow_nlg:  "/gear/gear[0]/wow",
        Vr:       "/controls/switches/HUDnasal_rotation_speed",
        Bright:   "/controls/switches/HUDnasal_brightness",
        Dir_sw:   "/controls/switches/HUDnasal_director", 
        H_sw:     "/controls/switches/HUDnasal_height", 
        Speed_sw: "/controls/switches/HUDnasal_speed", 
        Test_sw:  "/controls/switches/HUDnasal_test",
        fdpitch:  "/autopilot/settings/fd-pitch-deg",
        fdroll:   "/autopilot/settings/fd-roll-deg",
        fdspeed:  "/autopilot/settings/target-speed-kt"

      };
   
      foreach(var name; keys(HUDnasal.main.input)) {
        HUDnasal.main.input[name] = props.globals.getNode(HUDnasal.main.input[name], 1);
      }
    }

    HUDnasal.main.redraw();
    return HUDnasal.main;
    
  },

  redraw: func() {
    HUDnasal.main.canvas.del();
    HUDnasal.main.canvas = canvas.new(HUDnasal.canvas_settings);
    HUDnasal.main.canvas.addPlacement(HUDnasal.main.place);
    HUDnasal.main.canvas.setColorBackground(0.36, g, 0.3, 0.02);
    HUDnasal.main.root = HUDnasal.main.canvas.createGroup()
                .set("font", "LiberationFonts/LiberationMono-Regular.ttf");# If using default font, horizontal alignment is not accurate (bug #1054), also prettier char spacing. 
    
    HUDnasal.main.root.setScale(math.sin(slant*deg2rads), 1);
    HUDnasal.main.root.setTranslation(512, 512);



  # digital airspeed kts/mach	
    HUDnasal.main.airspeed = HUDnasal.main.root.createChild("text")
    	.setText("000")
    	.setFontSize(100*fs, ar)
    	.setColor(r,g,b, a)
    	.setAlignment("center-center")
    	.setTranslation(0 , 400);

  # scale heading ticks
    HUDnasal.main.head_scale_grp = HUDnasal.main.root.createChild("group");
    HUDnasal.main.head_scale_grp.set("clip", "rect(62px, 587px, 262px, 437px)");#top,right,bottom,left
    HUDnasal.main.head_scale_grp_trans = HUDnasal.main.head_scale_grp.createTransform();
    HUDnasal.main.head_scale = HUDnasal.main.head_scale_grp.createChild("path")
        .moveTo(-100, 0)
        .vert(-60)
        .moveTo(0, 0)
        .vert(-60)
        .moveTo(100, 0)
        .vert(-60)
        .moveTo(-50, 0)
        .vert(-40)
        .moveTo(50, 0)
        .vert(-40)
        .setStrokeLineWidth(w)
        .setColor(r,g,b, a)
        .show();

  # scale heading end ticks
    HUDnasal.main.hdgLineL = HUDnasal.main.head_scale_grp.createChild("path")
    .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .moveTo(-150, 0)
      .vert(-40)
      .close();

    HUDnasal.main.hdgLineR = HUDnasal.main.head_scale_grp.createChild("path")
    .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .moveTo(150, 0)
      .vert(-40)
      .close();

  # headingindicator
    HUDnasal.main.head_scale_indicator = HUDnasal.main.root.createChild("path")
    .setColor(r,g,b, a)
    .setStrokeLineWidth(w)
    .moveTo(-30, -headScalePlace+30)
    .lineTo(0, -headScalePlace)
    .lineTo(30, -headScalePlace+30);

  # Heading middle number
    HUDnasal.main.hdgM = HUDnasal.main.head_scale_grp.createChild("text");
    HUDnasal.main.hdgM.setColor(r,g,b, a);
    HUDnasal.main.hdgM.setAlignment("center-bottom");
    HUDnasal.main.hdgM.setFontSize(50*fs, ar);

  # Heading left number
    HUDnasal.main.hdgL = HUDnasal.main.head_scale_grp.createChild("text");
    HUDnasal.main.hdgL.setColor(r,g,b, a);
    HUDnasal.main.hdgL.setAlignment("center-bottom");
    HUDnasal.main.hdgL.setFontSize(50*fs, ar);

  # Heading right number
    HUDnasal.main.hdgR = HUDnasal.main.head_scale_grp.createChild("text");
    HUDnasal.main.hdgR.setColor(r,g,b, a);
    HUDnasal.main.hdgR.setAlignment("center-bottom");
    HUDnasal.main.hdgR.setFontSize(50*fs, ar);

  # Altitude
    HUDnasal.main.alt_scale_grp=HUDnasal.main.root.createChild("group")
      .set("clip", "rect(150px, 1800px, 874px, 0px)");#top,right,bottom,left
    HUDnasal.main.alt_scale_grp_trans = HUDnasal.main.alt_scale_grp.createTransform();

  # alt scale high
    HUDnasal.main.alt_scale_high=HUDnasal.main.alt_scale_grp.createChild("path")
      .moveTo(0, -6*altimeterScaleHeight/2)
      .horiz(75)
      .moveTo(0, -5*altimeterScaleHeight/2)
      .horiz(50)
      .moveTo(0, -2*altimeterScaleHeight)
      .horiz(75)
      .moveTo(0, -3*altimeterScaleHeight/2)
      .horiz(50)
      .moveTo(0, -altimeterScaleHeight)
      .horiz(75)
      .moveTo(0, -altimeterScaleHeight/2)
      .horiz(50)
      .moveTo(0, 0)
      .horiz(75)
      .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .show();



  # alt scale medium
    HUDnasal.main.alt_scale_med=HUDnasal.main.alt_scale_grp.createChild("path")
      .moveTo(0, -5*altimeterScaleHeight/2)
      .horiz(50)
      .moveTo(0, -2*altimeterScaleHeight)
      .horiz(75)
      .moveTo(0, -3*altimeterScaleHeight/2)
      .horiz(50)
      .moveTo(0, -altimeterScaleHeight)
      .horiz(75)
      .moveTo(0, -4*altimeterScaleHeight/5)
      .horiz(25)
      .moveTo(0, -3*altimeterScaleHeight/5)
      .horiz(25)           
      .moveTo(0, -2*altimeterScaleHeight/5)
      .horiz(25)
      .moveTo(0, -1*altimeterScaleHeight/5)
      .horiz(25)           
      .moveTo(0, 0)
      .horiz(75)
      .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .show();

  # alt scale low
  	HUDnasal.main.alt_scale_low = HUDnasal.main.alt_scale_grp.createChild("path")
      .moveTo(0, -7*altimeterScaleHeight/4)
      .horiz(50)
      .moveTo(0, -6*altimeterScaleHeight/4)
      .horiz(75)
  		.moveTo(0, -5*altimeterScaleHeight/4)
      .horiz(50)
      .moveTo(0, -altimeterScaleHeight)
      .horiz(75)
      .moveTo(0,-4*altimeterScaleHeight/5)
      .horiz(25)
      .moveTo(0, -3*altimeterScaleHeight/5)
      .horiz(25)
  		.moveTo(0, -2*altimeterScaleHeight/5)
  		.horiz(25)					 
  		.moveTo(0,-1*altimeterScaleHeight/5)
  		.horiz(25)
  		.moveTo(0, 0)
  		.horiz(75)
  		.setStrokeLineWidth(w)
  		.setColor(r,g,b, a)
      .show();


      
  # vert line at zero alt if it is lower than radar zero
      HUDnasal.main.alt_scale_line = HUDnasal.main.alt_scale_grp.createChild("path")
      .moveTo(0, 30)
      .vert(-60)
      .setStrokeLineWidth(w)
      .setColor(r,g,b, a);
  # low alt number
    HUDnasal.main.alt_low = HUDnasal.main.alt_scale_grp.createChild("text")
      .setText(".")
      .setFontSize(75*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("left-center")
      .setTranslation(1, 0);
  # middle alt number	
  	HUDnasal.main.alt_med = HUDnasal.main.alt_scale_grp.createChild("text")
  		.setText(".")
      .setFontSize(75*fs, ar)
      .setColor(r,g,b, a)
  		.setAlignment("left-center")
      .setTranslation(1, 0);
  # high alt number			 
  	HUDnasal.main.alt_high = HUDnasal.main.alt_scale_grp.createChild("text")
  		.setText(".")
      .setFontSize(75*fs, ar)
      .setColor(r,g,b, a)
  		.setAlignment("left-center")
      .setTranslation(1, 0);

  # higher alt number     
    HUDnasal.main.alt_higher = HUDnasal.main.alt_scale_grp.createChild("text")
      .setText(".")
      .setFontSize(75*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("left-center")
      .setTranslation(1, 0);
  # alt scale indicator
  	HUDnasal.main.alt_pointer = HUDnasal.main.root.createChild("path")
      .setColor(r,g,b, a)
      .setStrokeLineWidth(w)
      .moveTo(0,0)
      .lineTo(-60,-60)
      .moveTo(0,0)
      .lineTo(-60,60)
      .setTranslation(scalePlace+indicatorOffset, 0);
  # alt scale radar ground indicator
    HUDnasal.main.rad_alt_pointer = HUDnasal.main.alt_scale_grp.createChild("path")
      .setColor(r,g,b, a)
      .setStrokeLineWidth(w)
      .moveTo(0,0)
      .lineTo(-60,0)
      .moveTo(0,0)
      .lineTo(-30,50)
      .moveTo(-30,0)
      .lineTo(-60,50);
    
  # QFE warning (inhg not properly set / is being adjusted)
    HUDnasal.main.qfe = HUDnasal.main.root.createChild("text");
    HUDnasal.main.qfe.setText("QFE");
    HUDnasal.main.qfe.hide();
    HUDnasal.main.qfe.setColor(r,g,b, a);
    HUDnasal.main.qfe.setAlignment("center-center");
    HUDnasal.main.qfe.setTranslation(-450, 175);
    HUDnasal.main.qfe.setFontSize(80*fs, ar);

  # Altitude number (Not shown in landing/takeoff mode. Radar at less than 100 feet)
    HUDnasal.main.alt = HUDnasal.main.root.createChild("text");
    HUDnasal.main.alt.setColor(r,g,b, a);
    HUDnasal.main.alt.setAlignment("center-center");
    HUDnasal.main.alt.setTranslation(-500, 300);
    HUDnasal.main.alt.setFontSize(85*fs, ar);

  # Flightpath/Velocity vector
    HUDnasal.main.vec_vel =
      HUDnasal.main.root.createChild("path")
      .setColor(r,g,b, a)
      .moveTo(-90, 0) # draw this symbol in flight when no weapons selected (always as for now)
      .lineTo(-30, 0)
      .lineTo(0, 30)
      .lineTo(30, 0)
      .lineTo(90, 0)
      .setStrokeLineWidth(w);
  # takeoff/landing symbol
    HUDnasal.main.takeoff_symbol = HUDnasal.main.root.createChild("path")
      .moveTo(210, 0)
      .lineTo(150, 0)
      .moveTo(90, 0)
      .lineTo(30, 0)
      .arcSmallCCW(30, 30, 0, -60, 0)
      .arcSmallCCW(30, 30, 0,  60, 0)
      .close()
      .moveTo(-30, 0)
      .lineTo(-90, 0)
      .moveTo(-150, 0)
      .lineTo(-210, 0)
      .setStrokeLineWidth(w)
      .setStrokeLineCap("round")
      .setColor(r,g,b, a);

  # Horizon
    HUDnasal.main.horizon_group = HUDnasal.main.root.createChild("group");
    HUDnasal.main.horizon_group2 = HUDnasal.main.horizon_group.createChild("group");
    HUDnasal.main.h_rot   = HUDnasal.main.horizon_group.createTransform();

  
  # pitch lines
    var distance = pixelPerDegree * 5;
    for(var i = -18; i <= -1; i += 1) {
      append(artifacts1, HUDnasal.main.horizon_group2.createChild("path")
                     .moveTo(200, -i * distance)
                     .horiz(50)
                     .moveTo(300, -i * distance)
                     .horiz(50)
                     .moveTo(400, -i * distance)
                     .horiz(50)
                     .moveTo(500, -i * distance)
                     .horiz(50)
                     .moveTo(600, -i * distance)
                     .horiz(50)

                     .moveTo(-200, -i * distance)
                     .horiz(-50)
                     .moveTo(-300, -i * distance)
                     .horiz(-50)
                     .moveTo(-400, -i * distance)
                     .horiz(-50)
                     .moveTo(-500, -i * distance)
                     .horiz(-50)
                     .moveTo(-600, -i * distance)
                     .horiz(-50)
                     
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a));
    }

    for(var i = 1; i <= 18; i += 1)
      append(artifacts1, HUDnasal.main.horizon_group2.createChild("path")
         .moveTo(650, -i * distance)
         .horiz(-450)

         .moveTo(-650, -i * distance)
         .horiz(450)
         
         .setStrokeLineWidth(w)
         .setColor(r,g,b, a));

    #pitch line numbers
    for(var i = -18; i <= 0; i += 1)
      append(artifacts1, HUDnasal.main.horizon_group2.createChild("text")
         .setText(i*5)
         .setFontSize(75*fs, ar)
         .setAlignment("right-bottom")
         .setTranslation(-200, -i * distance - 5)
         .setColor(r,g,b, a));
    for(var i = 1; i <= 18; i += 1)
      append(artifacts1, HUDnasal.main.horizon_group2.createChild("text")
         .setText("+" ~ i*5)
         .setFontSize(75*fs, ar)
         .setAlignment("right-bottom")
         .setTranslation(-200, -i * distance - 5)
         .setColor(r,g,b, a));
                 

  #Horizon line
    HUDnasal.main.horizon = HUDnasal.main.horizon_group2.createChild("path")
                     .moveTo(-850, 0)
                     .horiz(650)
                     .moveTo(-37, 0)#-35
                     .arcSmallCW(2, 2, 0, -4, 0)
                     .arcSmallCW(2, 2, 0, 4, 0)
                     .moveTo(-107, 0)#-105
                     .arcSmallCW(2, 2, 0, -4, 0)
                     .arcSmallCW(2, 2, 0, 4, 0)
                     .moveTo(-177, 0)#-175
                     .arcSmallCW(2, 2, 0, -4, 0)
                     .arcSmallCW(2, 2, 0, 4, 0)
                     .moveTo(177, 0)#175
                     .arcSmallCW(2, 2, 0, -4, 0)
                     .arcSmallCW(2, 2, 0, 4, 0)
                     .moveTo(107, 0)#105
                     .arcSmallCW(2, 2, 0, -4, 0)
                     .arcSmallCW(2, 2, 0, 4, 0)
                     .moveTo(37, 0)#35
                     .arcSmallCW(2, 2, 0, -4, 0)
                     .arcSmallCW(2, 2, 0, 4, 0)
                     .moveTo(200, 0)
                     .horiz(650)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);

artifacts0 = [HUDnasal.main.airspeed, HUDnasal.main.head_scale, HUDnasal.main.hdgLineL,
             HUDnasal.main.hdgLineR, HUDnasal.main.head_scale_indicator, HUDnasal.main.hdgM, HUDnasal.main.hdgL,
             HUDnasal.main.hdgR, HUDnasal.main.alt_scale_high, HUDnasal.main.alt_scale_med, HUDnasal.main.alt_scale_low,
             HUDnasal.main.alt_scale_line, HUDnasal.main.alt_low, HUDnasal.main.alt_med, HUDnasal.main.alt_high,
             HUDnasal.main.alt_higher, HUDnasal.main.alt_pointer, HUDnasal.main.rad_alt_pointer, HUDnasal.main.qfe,
             HUDnasal.main.alt, HUDnasal.main.vec_vel, HUDnasal.main.takeoff_symbol, HUDnasal.main.horizon];


    },
    setColorBackground: func () { 
  		#me.texture.getNode('background', 1).setValue(_getColor(arg)); 
  		me; 
  		},

      ############################################################################
      #############             main loop                         ################
      ############################################################################
    update: func()
    {
      verbose = 0;
      if(getprop("/systems/electrical/outputs/inst_ac") < 40) {
        me.root.hide();
        me.root.update();
        settimer(func me.update(), 1);
       } elsif (getprop("/instrumentation/head-up-display/serviceable") == 0) {
        # The HUD has failed, due to the random failure system or crash, it will become frozen.
        # if it also later loses power, and the power comes back, the HUD will not reappear.
        settimer(func me.update(), 1);
       } else {
      # digital speed
      var mach = me.input.mach.getValue();
      if (mach >= 0.5) 
      {
        me.airspeed.setText(sprintf("%.2f", mach));
      } else {
        me.airspeed.setText(sprintf("%03d", me.input.ias.getValue() * 1.852));
      }
            
      # heading scale
      var heading = me.input.hdg.getValue();
      var headOffset = heading/10 - int (heading/10);
      var headScaleOffset = headOffset;
      var middleText = roundabout(me.input.hdg.getValue()/10);
      if(middleText == 36) {
        middleText = 0;
      }
      var leftText = middleText == 0?35:middleText-1;
      var rightText = middleText == 35?0:middleText+1;
      if (headOffset > 0.5) {
        me.head_scale_grp_trans.setTranslation(-(headScaleOffset-1)*100, -headScalePlace);
        me.head_scale_grp.update();
        me.hdgLineL.show();
        #me.hdgLineR.hide();
      } else {
        me.head_scale_grp_trans.setTranslation(-headScaleOffset*100, -headScalePlace);
        me.head_scale_grp.update();
        me.hdgLineR.show();
        #me.hdgLineL.hide();
      }
      me.hdgR.setTranslation(100, -65);
      me.hdgR.setText(sprintf("%02d", rightText));
      me.hdgM.setTranslation(0, -65);
      me.hdgM.setText(sprintf("%02d", middleText));
      me.hdgL.setTranslation(-100, -65);
      me.hdgL.setText(sprintf("%02d", leftText));
      
  	  var alt = me.input.alt_ft.getValue() * 0.305;
      var radAlt = me.input.rad_alt.getValue() * 0.305;
      # determine which scale to use
      if (alt_scale_mode == -1) {
        if (alt < 45) {
          alt_scale_mode = 0;
        } elsif (alt < 90) {
          alt_scale_mode = 1;
        } else {
          alt_scale_mode = 2;
        }
      } elsif (alt_scale_mode == 0) {
        if (alt < 45) {
          alt_scale_mode = 0;
        } else {
          alt_scale_mode = 1;
        }
      } elsif (alt_scale_mode == 1) {
        if (alt < 90 and alt >= 40) {
          alt_scale_mode = 1;
        } else if (alt >= 90) {
          alt_scale_mode = 2;
        } else if (alt < 40) {
          alt_scale_mode = 0;
        } else {
          alt_scale_mode = 1;
        }
      } elsif (alt_scale_mode == 2) {
        if (alt >= 85) {
          alt_scale_mode = 2;
        } else {
          alt_scale_mode = 1;
        }
      }
      if(verbose > 1) print("Alt scale mode = "~alt_scale_mode);
      if(verbose > 1) print("Alt = "~alt);
      #place the scale
      me.alt_pointer.setTranslation(scalePlace+indicatorOffset, 0);
      if (alt_scale_mode == 0) {
        var offset = altimeterScaleHeight/50 * alt;
        if(verbose > 1) print("Alt offset = "~offset);
        me.alt_scale_grp_trans.setTranslation(scalePlace, offset);
        me.alt_scale_med.hide();
        me.alt_scale_high.hide();
        me.alt_scale_low.show();
        me.alt_higher.hide();
        me.alt_high.show();
        me.alt_med.show();
        me.alt_low.show();
        me.alt_low.setTranslation(numberOffset, 0);
        me.alt_med.setTranslation(numberOffset, -altimeterScaleHeight);
        me.alt_high.setTranslation(numberOffset, -6*altimeterScaleHeight/4);
        me.alt_low.setText("0");
        me.alt_med.setText("50");
        me.alt_high.setText("100");
        if (radAlt < alt) {
          me.alt_scale_line.show();
        } else {
          me.alt_scale_line.hide();
        }
        # Show radar altimeter ground height
        var rad_offset = altimeterScaleHeight/50 * radAlt;
        me.rad_alt_pointer.setTranslation(indicatorOffset, rad_offset - offset);
        me.rad_alt_pointer.show();
        if (radPointerProxim < rad_offset - offset or rad_offset - offset < -radPointerProxim) {
          me.alt_pointer.show();
        } else {
          me.alt_pointer.hide();
        }
        me.alt_scale_grp.update();
        if(verbose > 2) print("alt " ~ sprintf("%3d", alt) ~ " radAlt:" ~ sprintf("%3d", radAlt) ~ " rad_offset:" ~ sprintf("%3d", rad_offset));
      } elsif (alt_scale_mode == 1) {
        me.alt_scale_med.show();
        me.alt_scale_high.hide();
        me.alt_scale_low.hide();
        me.alt_higher.hide();
        me.alt_high.show();
        me.alt_med.show();
        me.alt_low.show();
        var offset = 2*altimeterScaleHeight/100 * alt;
        if(verbose > 1) print("Alt offset = "~offset);
        me.alt_scale_grp_trans.setTranslation(scalePlace, offset);
        me.alt_low.setTranslation(numberOffset, 0);
        me.alt_med.setTranslation(numberOffset, -altimeterScaleHeight);
        me.alt_high.setTranslation(numberOffset, -altimeterScaleHeight*2);
        me.alt_low.setText("0");
        me.alt_med.setText("50");
        me.alt_high.setText("100");
        # Show radar altimeter ground height
        var rad_offset = 2*altimeterScaleHeight/100 * radAlt;
        me.rad_alt_pointer.setTranslation(indicatorOffset, rad_offset - offset);
        me.rad_alt_pointer.show();
        if (radAlt < alt) {
          me.alt_scale_line.show();
        } else {
          me.alt_scale_line.hide();
        }
        if (radPointerProxim > rad_offset - offset > -radPointerProxim) {
          me.alt_pointer.show();
        } else {
          me.alt_pointer.hide();
        }
        me.alt_scale_grp.update();
        #print("alt " ~ sprintf("%3d", alt) ~ " placing med " ~ sprintf("%3d", offset));
      } elsif (alt_scale_mode == 2) {
        me.alt_scale_med.hide();
        me.alt_scale_high.show();
        me.alt_scale_low.hide();
        me.alt_scale_line.hide();
        me.alt_higher.show();
        me.alt_high.show();
        me.alt_med.show();
        me.alt_low.show();
        var fact = int(alt / 100) * 100;
        var factor = alt - fact + 100;
        var offset = 2*altimeterScaleHeight/200 * factor;
        if(verbose > 1) print("Alt offset = "~offset);
        me.alt_scale_grp_trans.setTranslation(scalePlace, offset);
        me.alt_low.setTranslation(numberOffset , 0);
        me.alt_med.setTranslation(numberOffset , -altimeterScaleHeight);
        me.alt_high.setTranslation(numberOffset , -2*altimeterScaleHeight);
        me.alt_higher.setTranslation(numberOffset , -3*altimeterScaleHeight);
        var low = fact - 100;
        if(low > 1000) {
          me.alt_low.setText(sprintf("%.1f", low/1000));
        } else {
          me.alt_low.setText(sprintf("%d", low));
        }
        var med = fact;
        if(med > 1000) {
          me.alt_med.setText(sprintf("%.1f", med/1000));
        } else {
          me.alt_med.setText(sprintf("%d", med));
        }
        var high = fact + 100;
        if(high > 1000) {
          me.alt_high.setText(sprintf("%.1f", high/1000));
        } else {
          me.alt_high.setText(sprintf("%d", high));
        }
        var higher = fact + 200;
        if(higher > 1000) {
          me.alt_higher.setText(sprintf("%.1f", higher/1000));
        } else {
          me.alt_higher.setText(sprintf("%d", higher));
        }
        # Show radar altimeter ground height
        var rad_offset = 2*altimeterScaleHeight/200 * (radAlt);
        me.rad_alt_pointer.setTranslation(indicatorOffset, rad_offset - offset);
        me.rad_alt_pointer.show();
        if (radPointerProxim > rad_offset - offset > -radPointerProxim) {
          me.alt_pointer.show();
        } else {
          me.alt_pointer.hide();
        }
        me.alt_scale_grp.update();
        #print("alt " ~ sprintf("%3d", alt) ~ " radAlt:" ~ sprintf("%3d", radAlt) ~ " rad_offset:" ~ sprintf("%3d", rad_offset));
      }

      # digital altitude
      if (radAlt == nil) {
        me.alt.setText("");
        countQFE = 0;
        QFEcalibrated = 0;
      } elsif (radAlt < 100) {
        me.alt.setText("R " ~ sprintf("%3d", clamp(radAlt, 0, 100)));
        # check for QFE warning
        var diff = radAlt - alt;
        if (countQFE == 0 and (diff > 5 or diff < -5)) {
          #print("QFE warning " ~ countQFE);
          # is not calibrated, and is not blinking
          QFEcalibrated = 0;
          countQFE = 1;     
          #print("QFE not calibrated, and is not blinking");     
        } elsif (diff > -5 and diff < 5) {
            #is calibrated
          if (QFEcalibrated == 0 and countQFE < 11) {
            # was not calibrated before, is now.
            #print("QFE was not calibrated before, is now. "~countQFE);
            countQFE = 11;
          }
        } elsif (QFEcalibrated == 1 and (diff > 5 or diff < -5)) {
          # was calibrated before, is not anymore.
          #print("QFE was calibrated before, is not anymore. "~countQFE);
          countQFE = 1;
          QFEcalibrated = 0;
        }
      } else {
        # is above height for checking for calibration
        countQFE = 0;
        QFE = 0;
        QFEcalibrated = 1;
        #print("QFE not calibrated, and is not blinking");
        me.alt.setText(sprintf("%4d", clamp(alt, 0, 9999)));
      }

      # display and adjust QFE
      if (countQFE > 0) {
        # QFE is shown
        if(countQFE == 1) {
          countQFE = 2;
        }
        if(countQFE < 10) {
           # blink the QFE
          if (QFE < 1 and QFE != -5) {
              me.qfe.hide();
              QFE = QFE -1;
              #print("blink off");
          } elsif (QFE > 0) {
            if (QFE == 5) {
              QFE = -1;
              countQFE = countQFE + 1;
              #print("blink count")
            } else {
              QFE = QFE + 1;
            }
            me.qfe.show();
            #print("blink  on");
          } else {
              if (QFE == -5) {
                QFE = 0;
              }
              me.qfe.show();
              QFE = QFE + 1;
              #print("blink  on");
          }
        } elsif (countQFE == 10) {
          #if(me.input.ias.getValue() < 10) {
            # adjust the altimeter (commented out after placing altimeter in plane)
            # var inhg = getprop("systems/static/pressure-inhg");
            #setprop("instrumentation/altimeter/setting-inhg", inhg);
           # countQFE = 11;
            #print("QFE adjusted " ~ inhg);
          #} else {
            countQFE = -100;
          #}
        } elsif (countQFE < 125) {
          # QFE is steady
          countQFE = countQFE + 1;
          me.qfe.show();
          #print("steady on");
        } else {
          countQFE = -100;
          QFEcalibrated = 1;
          #print("off");
        }
      } else {
        me.qfe.hide();
        countQFE = clamp(countQFE+1, -101, 0);
        #print("hide  off");
      }
    #print("QFE count " ~ countQFE);

      # Sights/crosshairs
    if(getprop("gear/gear/position-norm") != nil and getprop("gear/gear/position-norm") == 0) {
      me.takeoff_symbol.hide();
      # flight path vector (FPV)
      var vel_gx = me.input.speed_n.getValue();
      var vel_gy = me.input.speed_e.getValue();
      var vel_gz = me.input.speed_d.getValue();
   
      var yaw = me.input.hdgReal.getValue() * math.pi / 180.0;
      var roll = me.input.roll.getValue() * math.pi / 180.0;
      var pitch = me.input.pitch.getValue() * math.pi / 180.0;
   
      var sy = math.sin(yaw);   var cy = math.cos(yaw);
      var sr = math.sin(roll);  var cr = math.cos(roll);
      var sp = math.sin(pitch); var cp = math.cos(pitch);
   
      var vel_bx = vel_gx * cy * cp
                 + vel_gy * sy * cp
                 + vel_gz * -sp;
      var vel_by = vel_gx * (cy * sp * sr - sy * cr)
                 + vel_gy * (sy * sp * sr + cy * cr)
                 + vel_gz * cp * sr;
      var vel_bz = vel_gx * (cy * sp * cr + sy * sr)
                 + vel_gy * (sy * sp * cr - cy * sr)
                 + vel_gz * cp * cr;
   
      var dir_y = math.atan2(round0(vel_bz), math.max(vel_bx, 0.001)) * 180.0 / math.pi;
      var dir_x  = math.atan2(round0(vel_by), math.max(vel_bx, 0.001)) * 180.0 / math.pi;
   
      me.vec_vel.setTranslation(clamp(dir_x * pixelPerDegree, -450, 450), clamp((dir_y * pixelPerDegree)+centerOffset, -450, 450));
      if (dir_y > 8) {
        # blink the flight vector cross hair if alpha is high
        if (blinking < 1 and blinking != -2) {
            me.vec_vel.hide();
            blinking = blinking -1;
        } elsif (blinking > 0) {
          if (blinking == 2) {
            blinking = -1;
          } else {
            blinking = blinking + 1;
          }
          me.vec_vel.show();
        } else {
            if (blinking == -2) {
              blinking = 0;
            }
            me.vec_vel.show();
            blinking = blinking + 1;
        }
      } else {
        me.vec_vel.show();
        blinking = 0;
      }
    } else {
      me.vec_vel.hide();
      me.takeoff_symbol.show();
      
      #move takeoff/landing symbol according to side wind:
      var wind_heading = getprop("environment/wind-from-heading-deg");
      var wind_speed = getprop("environment/wind-speed-kt");
      var heading = me.input.hdgReal.getValue();
      #var speed = me.input.ias.getValue();
      var angle = (wind_heading -heading) * (math.pi / 180.0); 
      var wind_side = math.sin(angle) * wind_speed;
      #print((wind_heading -heading) ~ " " ~ wind_side);
      me.takeoff_symbol.setTranslation(clamp(-wind_side * sidewindPerKnot, -450, 450), sidewindPosition);
    }

    # artificial horizon and pitch lines
    me.horizon_group2.setTranslation(0, pixelPerDegree * me.input.pitch.getValue());
    me.horizon_group.setTranslation(0, centerOffset);
    var rot = -me.input.roll.getValue() * deg2rads;
    me.h_rot.setRotation(rot);


    if (getprop("fcs/fbw-override") == 1) 
     {
	     #tmp debug stuff
		   #print("HUD removed");
	   } else {
		   #print("HUD repainted");

        if(reinitHUD == 1) {
          me.redraw();
          reinitHUD = 0;
          me.update();
        } else {
          me.root.show();
          me.root.update();          
        }
        settimer(func me.update(), 0.05);
       
	     
       setprop("sim/hud/visibility[1]", 0);
	   }
   }
  }
};

var id = 0;

var reinitHUD = 0;
var init = func() {
  removelistener(id); # only call once
  if(getprop("sim/ja37/supported/hud") == 1) {
    var hud_pilot = HUDnasal.new({"node": "HUDobject", "texture": "hud.png"});
    setprop("sim/hud/visibility[1]", 0);
    
    #print("HUD initialized.");
    hud_pilot.update();
  }
};

var init2 = setlistener("/sim/signals/reinit", func() {
  setprop("sim/hud/visibility[1]", 0);
});

#setprop("/systems/electrical/battery", 0);
id = setlistener("sim/ja37/supported/initialized", init);

var reinit = func() {#mostly called to change HUD color
  #reinitHUD = 1;

 foreach(var item; artifacts0) {
  item.setColor(r, g, b, a);
 }

 foreach(var item; artifacts1) {
  item.setColor(r, g, b, a);
 }

 HUDnasal.main.canvas.setColorBackground(0.36, g, 0.3, 0.02);

  #print("HUD being reinitialized.");
};