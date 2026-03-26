;; Nick Ballingall
;; June 2025
;; github.com/NickBallingall

;; ===== VARIABLES =====

globals [                            ;; GLOBAL VARIABLES --------

  ;; --- Cars & Engines ---
  user-car                           ;; names & identifiers
  ai-driver-names

  base-acceleration                  ;; car performance parameters
  base-braking
  max-speed
  turn-angle-for-scaling
  min-speed-at-max-turn

  gear-ratios                        ;; engine & transmission [works, but needs more development to add meaningful agent decisions]
  peak-power-rpm
  redline-rpm
  upshift-rpm
  downshift-rpm

  ;; --- Starting Grid ---
  pole-x pole-y                      ;; pole position coordinates
  racing-line-angle                  ;; car starting direction (racing line angle) [probs redundant – could get from inverse of starting-grid-angle]
  starting-grid-angle                ;; grid spawn direction
  grid-row-spacing grid-col-spacing  ;; row & col spacing
  stagger-offset                     ;; grid coll offset amount

  ;; --- Race ---
  finishing-position-counter         ;; race results (1st, 2nd, 3rd, etc.)
  race-timeout-tick                  ;; start timer for race time-out after first car finishes (for stuck cars, DNF, etc.)
  collision-log                      ;; tracks collisions

  ;; --- Leaderboard ---
  time-update-interval               ;; update delay (too erratic otherwise)
  leaderboard-x leaderboard-y        ;; top position coordinates (start of grid)
  leaderboard-spacing                ;; leaderboard display spacing
]


breed [proxies proxy]                ;; leaderboard agents (linked to cars, store race data as proxies to help stuttering on new laps)


proxies-own [                        ;; PROXY AGENTS
                                     ;; car data for analysis [should probs track every lap, or at least also the worst lap for better insights]
  linked-car                         ;; 1:1 spawn order with starting grid
  race-id                            ;; for naming csv files (user input (date-id) + counter for this session)

  race-summary-data                  ;; summary csv

  best-line-for-logging              ;; detailed lap csv
  best-line-speeds
  best-line-healths
  best-line-turn-angles
  best-line-gears
  best-line-rpms

  all-laps-for-logging               ;; list of coords for every user-car lap
]


turtles-own [                        ;; CAR AGENTS --------

  ;; --- Name & State ---
  car-name                           ;; agent name ("VER", "HAM", etc. – named after actual drivers)
  state                              ;; dictates the car's behaviour ("idle", "racing", "cool-down", etc.)

  ;; --- Driving Parameters ---
  driving-style                      ;; rudimentary implementation of different car specs & drivers
                                     ;; "Balanced"  – mid straights, mid cornering (most development done on this setup)
                                     ;; "Aggresive" – faster straights, slower cornering
                                     ;; "Technical" – faster cornering, slower straights
                                     ;; "Dynamic"   – mid corners, mid straights, faster acceleration, faster tyre wear

  steering-responsiveness            ;; cornering abilty
  rpm                                ;; engine revs (affect acceleration, gear, and top speed)
  current-gear                       ;; current gear
  current-speed                      ;; current speed of car
  target-speed                       ;; target speed based on upcomign track conditions (straights, corners, other cars, etc.). Allows for smooth (& loosely realistic) acceleration & braking.


  ;; --- Race Parameters ---
  start-position                     ;; race start position
  finishing-position                 ;; race finish position (1st, 2nd, 3rd, etc.)
  final-race-time                    ;; race finish time (sum of all laps – all time in ticks)
  current-time-racing                ;; total time racing at this moment (for leaderboard)
  best-lap-time                      ;; fastest lap time
  laps-completed                     ;; number of laps completed
  lap-start-time                     ;; start time of lap (for calculating lap times)

  ;; --- Racing Line ---
  current-line                       ;; list of coordinates for the current lap (mutated during lap)
  best-line                          ;; coordinates of line from fastest lap (or first lap on lap 2)


  ;; --- Lap Tracking ---
  passed-tracking-point?             ;; tracking point mid-way around lap (helps stop cars comple laps by going wrong direction – serves as pit-stop zone)
  corner-A                           ;; silverstone hairpin turn, checks for cars getting confused and reversing [doesn't work particualrly well]
  staging-timer                      ;; time spent in staging area at sf-line (basically 'injury time' from football, as cars will sometimes briefly get caught between laps due to writing data or mild tracking hitches)
  lap-speed-sum lap-speed-count      ;; average speed per lap (for output data)

  ;; --- Tyres & Pit-Stops ---
  tyre-health                        ;; tyre health (wears down with use)
  health-at-lap-start                ;; starting health (for pit stop strategy)
  last-valid-lap-wear                ;; amount of wear in last lap (for pit stop strategy – this and tyre-health are used to calculate when to box)

  current-tyre-type                  ;; current tyes
                                     ;; "soft"   – high performance, low health
                                     ;; "medium" – mid performance, mid health
                                     ;; "hard"   – low performance, high health

  pit-stops-taken                    ;; number of pit stops in race
  planned-pit-lap                    ;; planned pit stop lap (based on tyre health vs. wear rate)
  pit-timer                          ;; time in pit-stop ("random" value within range)
  pitted-this-lap?                   ;; stops back-to-back pit stops in every lap
  planned-tyre-choice                ;; tyres at next pit stop (choice based on tyre wear rate, pit stop time, and remaining in race)
  is-emergency-pit?                  ;; emergency pit stops from excessive, unexpected tyre wear (usually too much time in penalty zones)

  ;; --- Driver Support ---
  penalty-zone-timer                 ;; penalty zone escape mechanism (reset to sf-line if car gets stuck)
  off-track-resets-this-lap          ;; count of sf-line resets (bad best-line, needs reset)
  force-explore-lap?                 ;; force explore state to create a completely fresh racing line

  ;; --- Overtaking ---
  overtake-manoeuvre-timer            ;; timer to control the duration of an overtake
  overtake-target-patch              ;; temporary patch to steer towards during an overtake
  is-drs-active?                     ;; mimics drag-reduction system for a brief power-boost

  ;; --- Data Collection ---
  current-line-speeds                ;; lists of variable values for each point on the racing line (for analysis)
  current-line-healths               ;; tyre health (no car damage mechanism except for high-speed crash = DNF)
  current-line-turn-angles
  current-line-gears
  current-line-rpms
]

patches-own [                        ;; PATCHES --------

  is-sf-line?                        ;; start-finish line
  is-tracking-point?                 ;; drawn geometry for tracking laps
  is-penalty-zone?                   ;; gravel banks, penalises corner cutting without reseting lap (speed limit + extra tyre wear)
  is-staging-zone?                   ;; track area just before sf-line (where grid starts)
  is-corner-A-trigger?               ;; sikverstone hairpin [not properly working, may remove]
]



;; --------------------------
;; ===== RUN SIMULATION =====

to start-race
  ;; starts the race

  ask turtles with [state = "idle"] [  ;; change car state
    set state "racing"
    set lap-start-time ticks
    set passed-tracking-point? false
    set health-at-lap-start item 0 get-tyre-stats current-tyre-type
    if self = user-car [ show "Race started!" ]  ;; print race start message (only one car needs to do this)
  ]

  ask turtles [ check-for-collisions ]  ;; check for collisions before cars move

  ask turtles with [state = "racing"] [  ;; racing cars should race
    update-drs-status
    drive-lap
    record-lap  ;; (and also record data)
  ]

  ask turtles with [state = "pitting"] [  ;; pitting > racing state
    set pit-timer (pit-timer - 1)
    if pit-timer <= 0 [
      set state "racing"
      show (word [car-name] of self " exits the pits")  ;; call-out completed pit-stops
    ]
  ]

  ask turtles with [state = "cool-down"] [  ;; run a cool-down lap once finished race (until race ends)
    drive-cool-down-lap
  ]

  if ticks mod time-update-interval = 0 [  ;; live tracking of time racing
    ask turtles with [state = "racing"] [
      set current-time-racing (current-time-racing + time-update-interval)
    ]
    update-leaderboard  ;; order leaderboard based on live times (with delay for ledgibility)
  ]

  let active-cars turtles with [state = "racing" or state = "pitting" or state = "forced-dnf"]  ;; don't count crashed or finished cars
  let first-car-finished? (race-timeout-tick != -1)
  let timeout-exceeded? false
  if first-car-finished? [

    ifelse dev-override [  ;; dev mode settings
      set timeout-exceeded? (ticks - race-timeout-tick > dev-timeout-ticks)  ;; slider
    ][
      set timeout-exceeded? (ticks - race-timeout-tick > 2000)  ;; forced race end 2000 ticks after first car finishes (standard)
    ]
  ]

  if (not any? active-cars) or timeout-exceeded? [  ;; forced finish state
    if timeout-exceeded? [
      ask active-cars [
        set state "finished"
        show (word [car-name] of self " did not finish (DNF)")  ;; DNF if race not completed
      ]
    ]
    show "Final car has finished or timeout exceeded – RACE COMPLETE"  ;; race complete message
    let user-proxy one-of proxies with [linked-car = user-car]
    if user-proxy != nobody [
      ask user-proxy [  ;; write race data to csv file
        write-race-summary-csv
        write-detailed-lap-csv
        write-collisions-csv
        ;; write-all-user-laps-csv  ;; [NOT WORKING]
        ;; write-final-results-csv
      ]
      if any? proxies [
      write-final-results-csv
    ]
    ]
    stop  ;; stop sim
  ]

  tick
  wait 0.005  ;; nice balance between stuttering and too-fast visuals
end



;; ----------------------------
;; ===== SETUP SIMULATION =====

to setup

  clear-all  ;; purge previous world
  clear-all-plots
  reset-ticks

  set dev-override false  ;; turn off dev override on world setup

  set ai-driver-names [  ;; list of dirvers names – 30 drivers max (extra for redundancy + it's the actual current F1 safety regulations)
    "VET    " "ALO    " "RAI    " "MSC    " "HAM    " "ROS    " "BUT    " "WEB    " "MAS    " "BOT    "
    "RIC    " "VER    " "PER    " "HUL    " "SAI    " "NOR    " "LEC    " "GAS    " "OCO    " "TSU    "
    "ALB    " "LAT    " "MAZ    " "ZHO    " "DEV    " "SAR    " "PIA    " "STR    " "MAG    " "SCH    "  ;; extra spaces after name because NetLogo labels are shit
  ]

  setup-track  ;; heavy setup procedure (draws geometry) for model initialisation
  reset-race   ;; lightweight procedure (only resets agents & variables) for new races

  set collision-log []  ;; empty crash data log
end

to reset-race
  ;; "lightweight" reset procedure – DOES NOT REDRAW TRACK GEOMETRY

  validate-user-inputs  ;; validates user-inputs (bascially just for user-car starting position, so it doesn't exceed the number of cars)

  clear-all-plots  ;; clear user-car plots
  reset-ticks
  ask turtles [ die ]  ;; kill previous agents
  ask proxies [ die ]

  set dev-override false  ;; turn off dev-override

  setup-physics  ;; set up variables for next race

  set pole-x 70  ;; starting grid setup for silverstone track
  set pole-y -275
  set racing-line-angle 330

  set finishing-position-counter 1
  set race-timeout-tick -1

  create-cars number-of-cars  ;; create cars & proxy (leaderboard) agents
  setup-proxies

  set collision-log []  ;; empty crash data log

  show "Race reset – Ready to start"

  if dev-override [  ;; dev settings are on
    show "For dev tools, use 'Reset Race [DEV]' button instead – dev-override turned off"
  ]

end

to dev-reset-race
  ;; "lightweight" reset procedure – DOES NOT REDRAW TRACK GEOMETRY
  ;; version used when dev-override is active

  validate-user-inputs  ;; validates user-inputs (bascially just for user-car starting position, so it doesn't exceed the number of cars)

  clear-all-plots  ;; clear user-car plots
  reset-ticks
  ask turtles [ die ]  ;; kill previous agents
  ask proxies [ die ]

  set dev-override true  ;; turn dev-override on [kinda makes the switch pointless]

  setup-physics  ;; set up variables for next race

  set pole-x 70  ;; starting grid setup for silverstone track
  set pole-y -275
  set racing-line-angle 330

  set finishing-position-counter 1
  set race-timeout-tick -1

  create-cars number-of-cars  ;; create cars & proxy (leaderboard) agents
  setup-proxies

  set collision-log []  ;; empty crash data log

  show "Race reset – Ready to start"

  if dev-override [  ;; dev settings are on
    show "WARNING: Dev tools are active [DEV]"
  ]
end

to validate-user-inputs
  ;; checks user input for starting position; corrects if exceeds acceptable range (<1 or > number of cars)

  if (user-start-pos > number-of-cars) [
    set user-start-pos number-of-cars
    show (word "Starting position too high – Starting in last place: " number-of-cars)
  ]
  if (user-start-pos < 1) [
    set user-start-pos 1
    show "Starting position was too low – Starting in pole position"
  ]
end

to setup-physics
  ;; sets driving & leadrboard variables
  ;; [change 'physics' name, it's not really physics anymore]

  ;; --- Gearbox ---
  set gear-ratios [24000 18000 14000 11000 9000 7500 6250 5250]
  set peak-power-rpm 10500
  set redline-rpm 14000
  set upshift-rpm 13000
  set downshift-rpm 8500

  ;; --- Driving & Cornering ---
  set base-acceleration 0.05  ;; these base parameters are modified by driving styles. Change them to tune all cars regardless of style.
  set base-braking 0.08
  set max-speed 2.0
  set turn-angle-for-scaling 30
  set min-speed-at-max-turn 0.15

  ;; --- Starting Grid ---
  set starting-grid-angle -34
  set grid-row-spacing -6
  set grid-col-spacing 12
  set stagger-offset 0.5

  ;; --- Leaderboard ---
  set time-update-interval 100  ;; update interval (visual chaos at 1)
  set leaderboard-x (world-width / 2 - 20)
  set leaderboard-y (world-height / 2 - 50)
  set leaderboard-spacing 20
end

to setup-track
  ;; draws track, penalty zone, and markers geometry (very, very slow) [could optimise through order of operations]
  import-pcolors "silverstone_alt.png"
  setup-track-markers
end



;; --------------------------
;; ===== CARS & PROXIES =====

to create-cars [ num-cars ]
  ;; spawn car agents on grid

  let min-stops calculate-min-stops
  let base-colours [15 25 53 65 75 103 125 115 96 77]
  let ai-name-index 0

  let i 0
  while [i < num-cars] [
    let grid-pos i + 1
    create-turtles 1 [
      setup-individual-car
      set start-position grid-pos  ;; record grid position at race start

      ;; --- Configure this Specific Car ---
      ifelse grid-pos = user-start-pos [
        ;; user-car
        set user-car self
        set car-name "-> YOU    "
        set color 9.9  ;; user car is white for visibility
        set driving-style user-driving-style  ;; user input
        set current-tyre-type starting-tyre-type ;; user input
      ][
        ;; other cars
        set car-name item (ai-name-index mod length ai-driver-names) ai-driver-names  ;; name from list
        set color item (ai-name-index mod length base-colours) base-colours  ;; colour from list

        ifelse dev-override [  ;; dev override for diriving style
          set driving-style dev-driving-style
        ][
          set driving-style one-of ["Technical" "Aggressive" "Balanced" "Dynamic"]  ;; get driving style from list (if not [DEV])
        ]

        ifelse dev-override [  ;; dev override for tyres
          set current-tyre-type dev-starting-tyres
        ][
          ifelse min-stops = 0
            [ set current-tyre-type "soft" ]  ;; soft default on short races
            [ set current-tyre-type one-of ["soft" "medium" "hard"] ]  ;; else, get from list
        ]
        set ai-name-index (ai-name-index + 1)
      ]

      ;; --- Positioning Logic ---
      ifelse grid-pos = 1 [
        setxy pole-x pole-y  ;; pole position spaws with set coordinates
      ][
        let temp-grid-row (grid-pos - 1)  ;; use trig to spawn grid at any angle (saves confidguring each coordinate)
        let temp-grid-col ((grid-pos - 1) mod 2)
        if (temp-grid-col = 1) [ set temp-grid-row (temp-grid-row + stagger-offset) ]
        let across-angle (starting-grid-angle + 90)
        let col-offset-x (temp-grid-col * grid-col-spacing * sin(across-angle))
        let col-offset-y (temp-grid-col * grid-col-spacing * cos(across-angle))
        let row-offset-x (temp-grid-row * grid-row-spacing * sin(starting-grid-angle))
        let row-offset-y (temp-grid-row * grid-row-spacing * cos(starting-grid-angle))
        setxy (pole-x + col-offset-x + row-offset-x) (pole-y + col-offset-y + row-offset-y)
      ]

      ;; --- Tyre Stat Assignment ---
      ;; This will also now run for ALL cars.
      set tyre-health item 0 get-tyre-stats current-tyre-type
      set health-at-lap-start item 0 get-tyre-stats current-tyre-type
    ] ;; This is the closing bracket for 'create-turtles 1'

    set i (i + 1)
  ]
end

to setup-proxies
  ;; isolate cars from general turtle population

  let cars-to-process turtles with [breed != proxies]   ;; get car agents
  if not any? cars-to-process [stop] ;; stop if no cars

  ;; --- Create Proxies ---
  create-proxies (count cars-to-process)  ;; 1:1 with cars

  ;; --- Get SORTED List of Cars & Proxies
  let car-list sort cars-to-process  ;; [optimisation – new list may not be needed]
  let proxy-list sort proxies

  ;; --- Link Cars & Proxies ---
  let i 0
  while [i < length car-list] [  ;; loop through both lists in parallel
    let this-car item i car-list
    let this-proxy item i proxy-list

    ask this-proxy [  ;; ask proxies to link themselves to cars, then copy properties
      set linked-car this-car
      set label [car-name] of linked-car
      set color [color] of linked-car
      set shape "square"
      set size 8

      ifelse show-leaderboard?  ;; set visibility based on switch (leaderboard can be... erratic)
        [ show-turtle ]
        [ hide-turtle ]

      setxy leaderboard-x (leaderboard-y - (i * leaderboard-spacing))  ;; set position on leaderboard

      ;; --- Initialise Data Variables ---
      set race-id 1
      set race-summary-data []
      set best-line-for-logging []
      set best-line-speeds []
      set best-line-healths []
      set best-line-turn-angles []
      set best-line-gears []
      set best-line-rpms []
      set all-laps-for-logging []
    ]

    set i (i + 1)
  ]
end


to setup-individual-car
  ;; set base/common car paramaters (mostly startign at 0)

  set shape "circle"
  set size 5

  set heading racing-line-angle
  set state "idle"

  set finishing-position 0
  set current-time-racing 0
  set laps-completed 0
  set final-race-time 0
  set best-lap-time 999999  ;; arbitrarily high so first lap line becomes best lap
  set lap-start-time 0
  set passed-tracking-point? false
  set steering-responsiveness (0.44 + random-float 0.1 - 0.05)  ;; set with random for driving diversity [should modify to be included in driving style]
  set corner-A false
  set pit-stops-taken 0
  set planned-pit-lap 0
  set planned-tyre-choice ""  ;; blank until race starts
  set pit-timer 0
  set staging-timer 0
  set last-valid-lap-wear 15  ;; low setting, helps with cars that hit a lot of penalty zones in lap 1
  set pitted-this-lap? false
  set penalty-zone-timer 0
  set off-track-resets-this-lap 0
  set force-explore-lap? false
  set is-emergency-pit? false

  set lap-speed-sum 0
  set lap-speed-count 0
  set current-speed 0
  set current-gear 1
  set rpm 0
  set target-speed 0

  set best-line []
  set current-line []
  set current-line-speeds []
  set current-line-healths []
  set current-line-turn-angles []
  set current-line-gears []
  set current-line-rpms []

  set overtake-manoeuvre-timer 0
  set overtake-target-patch nobody
  set is-drs-active? false
end


;; -------------------------------------
;; ===== DRIVE LOGIC & LEADERBOARD =====

to check-track-direction
  ;; help prevent cars going wrong direction [could work a LOT better]
  ;; tracking point at hairpin & staging zone need to be passed in specific order or lap is reset

  if [is-staging-zone?] of patch-here [ set corner-A false ]
  if [is-corner-A-trigger?] of patch-here [
    ifelse corner-A = true [
      if self = user-car [ show "Wrong way! – Resetting car to start of lap" ]
      setxy pole-x pole-y  ;; start at pole position spawn point
      set heading racing-line-angle
      set current-speed 0
      set current-gear 1
      set rpm 0
      set target-speed 0
      set corner-A false
    ][
      set corner-A true
    ]
  ]
end

to check-for-collisions
  ;; logs collisions
  ;; if crashes enabled, DNF collided cars

  ;; --- Detect Collision ---
  if state = "racing" [
    let cars-on-patch other turtles-here with [state = "racing"]  ;; cars don't actually "collide", it's calculated based on whether they share the same patch simultaniously
    if any? cars-on-patch [
      let other-car one-of cars-on-patch
      if who > [who] of other-car [
         show (word [car-name] of self " and " [car-name] of other-car " have collided!")

         ;; --- Log Collision Data ---
         let collision-data (list
           (laps-completed + 1)
           [car-name] of self
           [car-name] of other-car
           (precision current-speed 2)
           (precision [current-speed] of other-car 2)
           pxcor
           pycor
           crashing-enabled?
         )
         set collision-log lput collision-data collision-log

         ;; --- Crash Parameters ---
         let crash-speed-threshold ifelse-value (crashing-enabled?) [ 1.2 ] [ 999 ]
         if current-speed > crash-speed-threshold or [current-speed] of other-car > crash-speed-threshold [
            show "It's a high-speed crash! – Both cars are out of the race!"
            set state "finished"
            ask other-car [ set state "finished" ] ;; set both cars' state to finished. Counts as DNF on race completion
         ]
      ]
    ]
  ]
end

to drive-lap
  ;; set race mode or explore mode
  ;; (mutate best racing line or navigate puely by 'vision'; setting new 'best line')

  check-track-direction
  ifelse (empty? best-line) or (force-explore-lap?)
    [ explore-logic ]
    [ race-logic ]
  update-car-physics
  fd current-speed
  log-tick-data
end

to drive-cool-down-lap
  ;; slow lap after race finish (until other cars finish)

  if not empty? best-line [
    let best-line-patches patch-set best-line  ;; bets line at end of race is logged best line (as would be overall best line)
    let closest-patch min-one-of best-line-patches [distance myself]
    let closest-index position closest-patch best-line
    let target-index (closest-index + 8)  ;; target 8 points ahead for smoother driving
    if target-index >= length best-line [ set target-index target-index - (length best-line) ]
    let target-patch item target-index best-line
    let desired-heading towards target-patch
    let turn-needed subtract-headings desired-heading heading
    rt (turn-needed * steering-responsiveness)
  ]
  fd 0.5
end

to update-car-physics
  ;; apply dirivng style modifiers

  let style-mods get-style-multipliers driving-style
  let accel-mod item 1 style-mods
  let brake-mod item 2 style-mods

  ;; Get DRS boosts if active
  let drs-accel-boost ifelse-value (is-drs-active?) [1.20] [1.0] ;; 20% accel boost
  let drs-speed-boost ifelse-value (is-drs-active?) [1.10] [1.0] ;; 10% speed boost

  let acceleration 0
  let braking 0
  ifelse current-speed < 0.1 and target-speed > current-speed [  ;; launch acceleration
    set acceleration (base-acceleration * 0.75 * accel-mod)
  ][
    if current-speed < target-speed [ set acceleration (base-acceleration * (calculate-power-modifier) * accel-mod) ]  ;; driving acceleration
    if current-speed > target-speed [ set braking (base-braking * brake-mod) ]  ;; braking ability
  ]
  set current-speed (max (list 0 (current-speed + acceleration - braking)))
  if current-speed > (max-speed * item 0 style-mods) [ set current-speed (max-speed * item 0 style-mods) ]  ;; max speed
  update-gears
end

to update-gears
  ;; transmission and engine rev calcilations

  if rpm > upshift-rpm and current-gear < 8 [ set current-gear current-gear + 1 ]
  if rpm < downshift-rpm and current-gear > 1 [ set current-gear current-gear - 1 ]
  ifelse current-speed < 0.1
    [ set rpm 900 ]  ;; engine idle revs
    [ set rpm (current-speed * (item (current-gear - 1) gear-ratios)) ]
  if rpm > redline-rpm [ set rpm redline-rpm ]  ;; virtual rev limiter (not really functional, just mild added realism)
end

to-report calculate-power-modifier
  if rpm <= 900 [ report 0 ]  ;; engine off
  if rpm > 900 and rpm <= peak-power-rpm [ report ((rpm - 900) / (peak-power-rpm - 900)) ]  ;; 'idle' revs don't contribute any power – power curve based only on "useful revs" (allows for idle cars to not have instant torque/motion at race start)
                                                                                            ;; [could be changed for more realism & accurate data analysis but doesn't really matter. Numbers are pretty arbitrary anyway]
  if rpm > peak-power-rpm [ report (1 - 0.2 * ((rpm - peak-power-rpm) / (redline-rpm - peak-power-rpm))) ]
  report 0
end

to explore-logic
  ;; exploration laps – no racing line, car uses 'vision' to find route around track
  ;; sets initial best racing line

  let style-mods get-style-multipliers driving-style
  let speed-mod item 0 style-mods

  let turn-angle 0
  ifelse [is-staging-zone?] of patch-here [
    set target-speed 0.5
    set staging-timer staging-timer + 1
    set penalty-zone-timer 0
  ]
  [
    ifelse [is-penalty-zone?] of patch-here [
      set target-speed 0.3
      set penalty-zone-timer penalty-zone-timer + 1
      if penalty-zone-timer >= 60 [ face min-one-of patches with [not is-penalty-zone? and pcolor != black] [distance myself] ]
    ][

     ;; --- Vision 'Whiskers' & Other Variables ---
      set penalty-zone-timer 0
      let look-ahead-distance 40
      let whisker-angle 45
      let whisker-headings (list 0 (- whisker-angle) whisker-angle)
      let whisker-lengths map [ h -> distance-to-track-edge-at-angle h look-ahead-distance ] whisker-headings
      let max-length max whisker-lengths
      let best-whisker-index position max-length whisker-lengths
      let chosen-heading item best-whisker-index whisker-headings
      let heading-difference subtract-headings (heading + chosen-heading) heading
      set turn-angle heading-difference
      rt (heading-difference * steering-responsiveness)
      let max-explore-speed 1.6
      let min-explore-speed 0.7
      let path-clarity (max-length / look-ahead-distance)
      let speed-multiplier (min-explore-speed + ((1 - min-explore-speed) * (path-clarity ^ 2)))
      set target-speed (max-explore-speed * speed-multiplier * speed-mod)
    ]
  ]
  if self = user-car [ set current-line-turn-angles lput turn-angle current-line-turn-angles ]
end

to race-logic
  ;; racing laps – car follows fastest (or first) racing line, but mutates it to find faster routes

  ;; --- Driving Style Application ---
  let style-mods get-style-multipliers driving-style
  let speed-mod item 0 style-mods
  let cornering-mod item 3 style-mods
  let wear-mod item 4 style-mods

  let grip-modifier (calculate-grip-modifier self)
  let wear (0.002 * wear-mod)
  let turn-angle 0

  let is-interacting? handle-interactions  ;; check for car-car interactions

  if not is-interacting? [  ;; if not interacting (braking or overtaking), continue as normal

    if [is-staging-zone?] of patch-here [
      set target-speed 0.5
      set wear 0
      set staging-timer staging-timer + 1
      set penalty-zone-timer 0
    ]
    ;; --- Penalty Zones ---
    ifelse [is-penalty-zone?] of patch-here [
      set target-speed (0.9 * grip-modifier)
      set penalty-zone-timer penalty-zone-timer + 1
      set wear wear + 0.1
      if penalty-zone-timer >= 60 [ face min-one-of patches with [not is-penalty-zone? and pcolor != black] [distance myself] ]
    ][
      ;; --- Pathfinding ---
      set penalty-zone-timer 0
      let best-line-patches patch-set best-line
      let closest-patch min-one-of best-line-patches [distance myself]
      let closest-index position closest-patch best-line
      let target-index (closest-index + 8)
      if target-index >= length best-line [ set target-index target-index - (length best-line) ]
      let target-patch item target-index best-line

      ;; [DRS change will go here in the next step]
      let preview-index (closest-index + 12)
      if preview-index >= length best-line [ set preview-index preview-index - (length best-line) ]
      let preview-patch item preview-index best-line
      set turn-angle abs (subtract-headings (towards target-patch) (towards preview-patch))

      let drs-corner-nerf ifelse-value (is-drs-active?) [0.95] [1.0] ;; We'll add is-drs-active? next
      let normalised-angle (min (list 1 (turn-angle / (turn-angle-for-scaling / cornering-mod) )))
      let speed-multiplier ((min-speed-at-max-turn ^ normalised-angle) * drs-corner-nerf)

      set target-speed ((max-speed * speed-mod) * speed-multiplier * grip-modifier)
      if turn-angle > 10 [ set wear wear + (0.03 * (turn-angle / turn-angle-for-scaling)) ]
      let desired-heading towards target-patch
      let turn-needed subtract-headings desired-heading heading
      rt (turn-needed * steering-responsiveness)
    ]
  ]

  ;; --- Tyre Manegement ---
  set tyre-health (tyre-health - wear)
  if run-flat and tyre-health < 10 [ set tyre-health 10 ]  ;; minim 10 health in run-flat mode
  if tyre-health <= 0 [ set state "finished" if self = user-car [ show "CRASH! – Tyre failure" ] ]  ;; when not in run-flat mode, tyre failure = crash = DNF
  if self = user-car [ set current-line-turn-angles lput turn-angle current-line-turn-angles ]
end

to handle-off-track
  ;; crash or reset cars that leave the track (based on crashing toggle)

  ifelse crashing-enabled?
  [
    ;; --- Crashing On ---
    show (word [car-name] of self " has gone off track and is out of the race! (DNF)")  ;; leaving track treated as crash, result is DNF
    set state "finished"
    hide-turtle  ;; hide car from track
  ]
  [
    ;; --- Crashing Off ---
    set off-track-resets-this-lap (off-track-resets-this-lap + 1)  ;; reset car to lap start
    if self = user-car [ show (word "Off track! – Resetting lap (Reset " off-track-resets-this-lap " this lap)") ]  ;; display message for user-car inc. number of resets

    if off-track-resets-this-lap > 3 [  ;; >3 resets caused forced exploration mode (current line is clearly flawed
      set force-explore-lap? true
      if self = user-car [ show "SAFETY WARNING: Too many resets – Re-exploring track on the next lap" ]  ;; only show message for user-car (but actions are the same for all cars)
    ]

    setxy pole-x pole-y  ;; reset parameters as if new lap
    set heading racing-line-angle
    set lap-start-time ticks
    set current-line []
    set passed-tracking-point? false
    set penalty-zone-timer 0
    set current-speed 0
    set current-gear 1
    set rpm 0
    set lap-speed-sum 0
    set lap-speed-count 0
    set current-line-speeds []
    set current-line-healths []
    set current-line-turn-angles []
    set current-line-gears []
    set current-line-rpms []
  ]
end

to-report handle-interactions
  ;; Report whether or not a car-car interaction is happenign
  ;; (assists main drive logic with overtaking)

  ;; --- Look for nearby cars ---
  let cars-ahead other turtles-here with [state = "racing"] in-cone 12 30  ;; check for other cars within 12 using 30º vision cone
  let car-in-front nobody
  if any? cars-ahead [ set car-in-front min-one-of cars-ahead [distance myself] ]

  if overtake-manoeuvre-timer > 0 [  ;; if already overtaking, continue the manoeuvre
    set overtake-manoeuvre-timer (overtake-manoeuvre-timer - 1)
    let desired-heading towards overtake-target-patch
    let turn-needed subtract-headings desired-heading heading
    rt (turn-needed * steering-responsiveness * 1.5)  ;; more aggressive turn for overtake
    report true  ;; report that we are busy interacting
  ]

  if car-in-front = nobody [ report false ]  ;; if no car ahead, do nothing

  let front-distance distance car-in-front  ;; decision based on distance of car in front

  ;; --- Collision Avoidance (braking) ---
  if front-distance < 4 [
    set target-speed max (list 0.2 ([current-speed] of car-in-front - 0.1))
    report true ;; car is braking to avoid collision, so this is an interaction
  ]

  ;; --- Overtake Logic ---
  if front-distance < 10 [

    ;; check for space to the left and right 'lanes'
    let check-dist 4 ;; how far to the side is checked for a clear 'lane'
    let target-dist 8 ;; how far ahead is targetted for overtake

    let left-check-patch patch-at-heading-and-distance (heading - 90) check-dist
    let right-check-patch patch-at-heading-and-distance (heading + 90) check-dist

    ;; --- SAFE Overtake Conditions ---
    let can-go-left? (left-check-patch != nobody and [pcolor] of left-check-patch != black and not any? turtles-on left-check-patch)
    let can-go-right? (right-check-patch != nobody and [pcolor] of right-check-patch != black and not any? turtles-on right-check-patch)

    ifelse can-go-left? [  ;; left overtake
      set overtake-target-patch patch-at-heading-and-distance (heading - 45) target-dist
      set overtake-manoeuvre-timer 15 ;; manoeuvre for 15 ticks
      report true
    ][
      if can-go-right? [  ;; right overtake
        set overtake-target-patch patch-at-heading-and-distance (heading + 45) target-dist
        set overtake-manoeuvre-timer 15 ;; manoeuvre for 15 ticks
        report true
      ]
    ]
  ]

  report false  ;; if no conditions met, report no interaction
end

to update-drs-status
  ;; determine if DRS conditions are met

  let should-drs-be-active? false
  if state = "racing" and not empty? best-line [  ;; must be racing (not exploring) to use DRS (could mess up initial 'best line')

    ;; --- Other Car Proximity Check ---
    let car-in-front nobody
    let potential-targets other turtles with [state = "racing"] in-cone 15 25
    if any? potential-targets [ set car-in-front min-one-of potential-targets [distance myself] ]

    if car-in-front != nobody [  ;; if next car close enough, check if road is straight [don't want to implement DRS zones as geometry is already super heavy to draw]

      ;; --- Track "Straightness" Check ---
      let is-straight-enough? false
      let best-line-patches patch-set best-line
      let closest-patch min-one-of best-line-patches [distance myself]
      let closest-index position closest-patch best-line

      let preview-index (closest-index + 25)
      if preview-index >= length best-line [ set preview-index preview-index - (length best-line) ]

      let current-heading-on-line towards (item ((closest-index + 1) mod length best-line) best-line)
      let preview-heading-on-line towards (item preview-index best-line)

      let turn-ahead abs (subtract-headings current-heading-on-line preview-heading-on-line)
      if turn-ahead < 10 [ set is-straight-enough? true ]

      ;; --- DRS Conditions Met ---
      if is-straight-enough? [
        set should-drs-be-active? true
      ]
    ]
  ]

  ;; --- Report DRS Activation ---
  if should-drs-be-active? and not is-drs-active? [
    show (word [car-name] of self " has activated DRS")
  ]

  ;; --- DRS Activation ---
  set is-drs-active? should-drs-be-active?
end


;; --------------------------
;; ===== DATA RECORDING =====

to log-tick-data
  ;; capture detailed lap data for analysis

  set lap-speed-sum (lap-speed-sum + current-speed)
  set lap-speed-count (lap-speed-count + 1)
  set current-line lput patch-here current-line
  set current-line-speeds lput current-speed current-line-speeds
  set current-line-healths lput tyre-health current-line-healths
  set current-line-gears lput current-gear current-line-gears
  set current-line-rpms lput rpm current-line-rpms
end

to update-leaderboard
  ;; update leaderboard throughout race [needs work]

  if count proxies < 1 [ stop ]  ;; can't run with 0 cars

  ;; --- Sorting Logic ---
  let unsorted-proxies proxies
  let sorted-proxies-list []

  while [any? unsorted-proxies] [
    let best-proxy min-one-of unsorted-proxies [ [current-time-racing] of linked-car ] ;; find the best remaining proxy (one with the lowest race time)
    set sorted-proxies-list lput best-proxy sorted-proxies-list ;; add best proxy to new sorted list
    set unsorted-proxies unsorted-proxies with [self != best-proxy] ;; remove best proxy from unsorted set so it's not added multiple times
  ]

  ;; --- Leaderboard Update Logic ---
  let i 0
  while [i < length sorted-proxies-list] [
    let p item i sorted-proxies-list
    ask p [
      setxy leaderboard-x (leaderboard-y - (i * leaderboard-spacing))
    ]
    set i (i + 1)
  ]
end


to record-lap
  ;; set best-line (next lap pathfinding coordinates), record lap data

  if pcolor = black [ handle-off-track ]
  if [is-tracking-point?] of patch-here and state = "racing" and not passed-tracking-point? [
    set passed-tracking-point? true
    let should-pit? false
    set is-emergency-pit? false
    if (laps-completed + 1) = planned-pit-lap [
      set should-pit? true
      show (word [car-name] of self " pitting on lap " (laps-completed + 1) ".")
    ]

    ifelse run-flat [
      if tyre-health <= 10 [ set should-pit? true set is-emergency-pit? true show (word "EMERGENCY PIT for " [car-name] of self "!") ]
    ][
      if tyre-health < last-valid-lap-wear [ set should-pit? true set is-emergency-pit? true show (word "EMERGENCY PIT for " [car-name] of self "!") ]
    ]
    if should-pit? [ perform-pit-stop ]
  ]

  ;; --- New Lap Logic ---
  if [is-sf-line?] of patch-here and passed-tracking-point? and (ticks-since-lap-start self) > 500 [
    let lap-time ((ticks-since-lap-start self) - staging-timer)
    set laps-completed (laps-completed + 1)
    set final-race-time (final-race-time + lap-time)
    let was-explore-lap? (laps-completed = 1 or force-explore-lap?)
    let health-loss (health-at-lap-start - tyre-health)

    if self = user-car [
      let my-proxy one-of proxies with [linked-car = user-car]
      ask my-proxy [
        log-lap-data lap-time health-loss was-explore-lap?
        if adv-path-log [  ;; log all coordinates if switch is on
          set all-laps-for-logging lput current-line all-laps-for-logging
        ]
      ]
      if was-explore-lap? [ show (word "Lap 1 complete! Racing line established in " lap-time " ticks.") ]
      if not was-explore-lap? [ show (word "Lap " laps-completed " / " number-of-laps " completed in " lap-time " ticks. Tyre Health: " precision tyre-health 2 " (" current-tyre-type ")") ]
    ]

    ;; --- Calculate Pit-Stop Strategy ---
    if not pitted-this-lap? [ set last-valid-lap-wear health-loss ]
    update-pit-strategy

    ;; --- Finish Forced Explore Lap (return to racing) ---
    if force-explore-lap? [
      if self = user-car [ show "Explore lap complete – Resuming use of new racing line" ]
      set force-explore-lap? false
    ]

    if lap-time < best-lap-time and not was-explore-lap? [
      set best-lap-time lap-time
      set best-line current-line

      ;; NEW: This logic now runs for EVERY car that sets a new best lap.
      ;; Each car finds its own linked proxy.
      let my-proxy one-of proxies with [linked-car = self]
      if my-proxy != nobody [
        ask my-proxy [
          update-best-lap-data  ;; tell proxy to save the new best lap data
        ]
      ]

      ;; The user-car still gets a special message in the command center.
      if self = user-car [
        show (word "--- NEW BEST LAP: " best-lap-time " ---")
      ]
    ]


    ;; --- Finish Race ---
    if laps-completed >= number-of-laps [
      if finishing-position-counter = 1 [ set race-timeout-tick ticks ]
      set finishing-position finishing-position-counter
      set finishing-position-counter (finishing-position-counter + 1)
      show (word [car-name] of self " finishes in position " finishing-position " with a total time of " final-race-time)
      set state "cool-down"
    ]
    ;; --- Cool-Down Lap ---
    if state != "cool-down" [
      set passed-tracking-point? false
      set lap-start-time ticks
      set staging-timer 0
      set current-line []
      set health-at-lap-start tyre-health
      set pitted-this-lap? false
      set off-track-resets-this-lap 0
      set lap-speed-sum 0
      set lap-speed-count 0
      set current-line-speeds []
      set current-line-healths []
      set current-line-turn-angles []
      set current-line-gears []
      set current-line-rpms []
    ]
  ]
end

to log-lap-data [ lap-time health-loss was-explore-lap? ]
  ;; collect car data (for race summary csv)

  set-current-plot "Lap Times"
  set-current-plot-pen "Lap Time"
  plotxy [laps-completed] of linked-car lap-time
  let avg-speed ifelse-value ([lap-speed-count] of linked-car = 0) [0] [([lap-speed-sum] of linked-car / [lap-speed-count] of linked-car)]
  set race-summary-data lput (list [laps-completed] of linked-car lap-time health-loss avg-speed [pitted-this-lap?] of linked-car [is-emergency-pit?] of linked-car was-explore-lap? [run-flat] of user-car ) race-summary-data
end

to update-best-lap-data
  ;; collect car data for best line csv

  set best-line-for-logging [best-line] of linked-car
  set best-line-speeds [current-line-speeds] of linked-car
  set best-line-healths [current-line-healths] of linked-car
  set best-line-turn-angles [current-line-turn-angles] of linked-car
  set best-line-gears [current-line-gears] of linked-car
  set best-line-rpms [current-line-rpms] of linked-car
end

to write-race-summary-csv
  ;; save race summary data for analysis

  if not any? proxies [stop]  ;; proxies are data source, can't write data if they don't exist
  let file-name (word date-id "_" race-id "_race_summary.csv")  ;; unique race ID – stops file being over-written every race (get date from user input + counter to produce unique filenames)
  file-open file-name
  file-print "car_name,lap_number,lap_time_ticks,tyre_health_loss,avg_speed,is_pit_lap,is_emergency_pit,is_explore_lap,is_run_flat_active,is_fastest_lap,is_slowest_lap,current_tyre_type"

  ask proxies [
    if not empty? race-summary-data [
      let my-name [car-name] of linked-car
      let my-tyre [current-tyre-type] of linked-car
      let lap-times map [ a-lap -> item 1 a-lap ] race-summary-data
      let fastest-t min lap-times
      let slowest-t max lap-times

      foreach race-summary-data [ a-lap ->
        let is-fastest? (item 1 a-lap) = fastest-t
        let is-slowest? (item 1 a-lap) = slowest-t

        ;; --- Write Data ---
        file-print (word  ;; populate csv columns
          my-name ","
          item 0 a-lap ","
          item 1 a-lap ","
          precision (item 2 a-lap) 4 ","
          precision (item 3 a-lap) 4 ","
          item 4 a-lap ","
          item 5 a-lap ","
          item 6 a-lap ","
          item 7 a-lap ","
          is-fastest? ","
          is-slowest? ","
          my-tyre
        )
      ]
    ]
  ]
  file-close
  show (word "Full race summary saved to " file-name)
end


to write-detailed-lap-csv
  ;; detailed data at each recorded racing line coordinate

  if not any? proxies [ stop ]
  let file-name (word  date-id "_best_laps.csv")  ;; race-id
  file-open file-name
  file-print "car_name,x_coord,y_coord,speed,tyre_health,turn_angle,gear,rpm"
  ask proxies [
    if not empty? best-line-for-logging [
      let my-name [car-name] of linked-car
      let i 0
      while [i < length best-line-for-logging] [
        let p item i best-line-for-logging
        let s item i best-line-speeds
        let h item i best-line-healths
        let a item i best-line-turn-angles
        let g item i best-line-gears
        let r item i best-line-rpms

        file-print (word  ;; populate csv columns
          my-name ","
          [pxcor] of p ","
          [pycor] of p ","
          precision s 4 ","
          precision h 4 ","
          precision a 4 ","
          g ","
          r
        )

        set i (i + 1)
      ]
    ]
  ]
  file-close
  show (word "All best lap data saved to " file-name)
  ask one-of proxies [ set race-id (race-id + 1) ]  ;; increase race-id counter
end


to write-collisions-csv
  ;; log of all race collisions

  if empty? collision-log [ stop ] ;; don't write an empty file

  let file-name (word date-id "_collisions.csv")
  file-open file-name

  file-print "lap_number,car_1,car_2,car_1_speed,car_2_speed,x_coord,y_coord,crashing_enabled"  ;; write header

  ;; --- Write Data ---
  foreach collision-log [ a-collision ->   ;; [neater format for this, should update above file-writing functions]

    file-print (word          ;; populate csv columns
      item 0 a-collision ","  ;; lap number
      item 1 a-collision ","  ;; car 1 name
      item 2 a-collision ","  ;; car 2 name
      item 3 a-collision ","  ;; car 1 speed
      item 4 a-collision ","  ;; car 2 speed
      item 5 a-collision ","  ;; x-coord
      item 6 a-collision ","  ;; y-coord
      item 7 a-collision      ;; crashing_enabled
    )
  ]

  file-close
  show (word "Collision log saved to " file-name)
end

to write-all-user-laps-csv  ;; [NOT WORKING]
  ;; writes the x/y coordinates for every user-car lap to a CSV file

  if not adv-path-log or empty? all-laps-for-logging [ stop ]  ; only run if the adv-path-log switch is on & data collected

  let file-name (word date-id "_all_laps.csv")
  file-open file-name

  ;; write header row
  file-print "lap_number,x_coord,y_coord"

  ;; loop through each lap recorded in the list
  let lap-num 1
  foreach all-laps-for-logging [ a-lap ->
    ;; Now loop through each patch (coordinate point) in that specific lap
    foreach a-lap [ a-patch ->
      file-print (word
        lap-num ","
        [pxcor] of a-patch ","
        [pycor] of a-patch
      )
    ]
    set lap-num (lap-num + 1)
  ]

  file-close
  show (word "User-car racing lines for every lap saved to " file-name)
end

to write-final-results-csv
  ;; writes the final finishing positions of all cars
  let file-name (word date-id "_race_results.csv")
  file-open file-name
  file-print "car_name,start_position,finishing_position,final_race_time" ;; header

  ask turtles [

    if finishing-position = 0 [ set finishing-position "DNF" ] ;; ensure a value of 0 is written for DNF cars
    file-print (word
      car-name ","
      start-position ","
      finishing-position ","
      final-race-time
    )
  ]
  file-close
  show (word "Final race results saved to " file-name)
end



;; ---------------------
;; ===== PIT-STOPS =====

to update-pit-strategy
  ;; targeted pit-stop lap updates live based on current rate of tyre wear

  ;; --- Calculate Tyre Lifespan ---
  if (laps-completed >= 2) and (last-valid-lap-wear > 0) and ((laps-completed + 1) != planned-pit-lap) and (laps-completed < number-of-laps) [
    let laps-remaining-in-race (number-of-laps - laps-completed)
    let current-max-health item 0 get-tyre-stats current-tyre-type
    let laps-left-on-tyres (tyre-health / last-valid-lap-wear)

    ;; --- Set Pit-Stop Lap ---
    if laps-left-on-tyres < laps-remaining-in-race [
      let target-health-for-pit (0.35 * current-max-health)
      let health-to-use-before-pit (tyre-health - target-health-for-pit)
      let laps-until-pit-window (health-to-use-before-pit / last-valid-lap-wear)
      let new-planned-lap (laps-completed + floor(laps-until-pit-window))

      ;; --- Update Pit-Stop Strategy ---
      if new-planned-lap <= laps-completed [ set new-planned-lap (laps-completed + 1) ]
      if new-planned-lap >= number-of-laps [ set new-planned-lap 0 ]
      if new-planned-lap != planned-pit-lap [
        set planned-pit-lap new-planned-lap

        ifelse planned-pit-lap > 0 [
          choose-next-tyres planned-pit-lap  ;; tyres to be applied next pit-stop
          show (word "Pit strategy for " [car-name] of self " updated: Plan to pit on lap " planned-pit-lap " for " planned-tyre-choice " tyres")
        ][
          set planned-tyre-choice ""
          show (word "Pit strategy for " [car-name] of self " updated: Final stint – no more stops needed")
        ]
      ]
    ]
  ]
end

to choose-next-tyres [ pit-lap ]
  ;; determine type of tyres to be used in pit-stops
  ;; (cars always want fastest tyres, but faster tyre = faster wear, and extra pit stops damage race performance more than slower tyres)

  ;; --- Caluclate Viable Tyre Types ---
  let stint-length (number-of-laps - pit-lap)
  if stint-length <= 0 [ stop ]
  let options ["soft" "medium" "hard"]
  let viable-options []

  foreach options [ tyre ->
    let tyre-max-health item 0 get-tyre-stats tyre
    let laps-possible (tyre-max-health / (last-valid-lap-wear * 1.05))
    if laps-possible >= stint-length [ set viable-options lput tyre viable-options ]
  ]

  ;; --- Apply Tyre Choice ---
  if empty? viable-options [ set planned-tyre-choice "hard" stop ]
  ifelse member? "soft" viable-options [ set planned-tyre-choice "soft" ][
    ifelse member? "medium" viable-options [ set planned-tyre-choice "medium" ][
      set planned-tyre-choice "hard"
    ]
  ]
end

to perform-pit-stop
  ;; do a pit-stop mid-race (no pitlanes or anything, car just stops in the zone for a few ticks)

  if planned-tyre-choice = "" [ choose-next-tyres (laps-completed + 1) ]
  let new-tyre planned-tyre-choice

  show (word [car-name] of self " pitting for new " new-tyre " tyres")

  set state "pitting"
  set pit-timer (150 + random 451)  ;; variable pit-stop time (150 base time)

  set current-tyre-type new-tyre
  set tyre-health item 0 get-tyre-stats new-tyre
  set pit-stops-taken (pit-stops-taken + 1)
  set pitted-this-lap? true
  set planned-pit-lap 0
  set planned-tyre-choice ""
end



;; -----------------------------
;; ===== SUPPORT FUNCTIONS =====

to setup-track-markers
  ;; specific patches on the track serve specific functions

  ;; --- Marker Types ---
  ask patches [
    set is-sf-line? false           ;; start/finish line
    set is-tracking-point? false    ;; mid-lap tracking point (and pit-zone)
    set is-penalty-zone? false      ;; penalty zones (gravel patches on corners)
    set is-staging-zone? false      ;; staging zone (under starting grid, just before start/finish line)
    set is-corner-A-trigger? false  ;; hairpin turn marker (cars often flip direction here)
  ]

  ;; --- Draw Markers ---
  ;; drawn as geometry (import-pcolors too imprecise (e.g. prominent black lines between track & penalty zones)
  let sf-line-vertices [ [55 -275] [52 -270] [78 -250] [82 -255] ]
  let staging-zone-vertices  [ [52 -270] [78 -250] [98 -275] [71 -295] ]
  let tracking-point-vertices [ [-233 368] [-182 356] [-189 324] [-240 335] ]
  let corner-A-vertices [ [0 190][1 190][1 160][0 160] ]

  ask patches with [pcolor != black] [  ;; ensure markers are only drawn on the track (except penalty zones)
    if is-inside-polygon? self tracking-point-vertices [ set is-tracking-point? true set pcolor 2 ]
    if is-inside-polygon? self staging-zone-vertices [ set is-staging-zone? true set pcolor 3 ]
    if is-inside-polygon? self sf-line-vertices [ set is-sf-line? true set pcolor 9.9 ]
    if is-inside-polygon? self corner-A-vertices [ set is-corner-A-trigger? true set pcolor 1 ]
  ]
  setup-penalty-zones
end

to setup-penalty-zones
  ;; penalty zones handled seperately as they are drawn off the track
  ;; [could probablt speed up initialisation by drawing penalty lines first, then importing track (simpler geometry)]

  let all-penalty-zones (list
    [ [-44 -89]  [-20 -121] [-20 -65]  ] [ [-16 55]   [0 11]     [-17 -30]  ] [ [-37 165]  [-31 139]  [-9 169]   ]
    [ [16 200]   [11 180]   [34 181]   ] [ [-60 217]  [-35 233]  [-13 217]  ] [ [-387 17]  [-367 38]  [-363 -7]  ]
    [ [-352 -22][-314 -57] [-352 -94] [-385 -69] [-352 -76] [-335 -62] ] [ [-423 321] [-391 358] [-336 361] ]
    [ [-423 321] [-391 355] [-336 361] ] [ [-148 338] [71 289]   [117 282] [140 258]  [70 276]   [-14 301] [-91 315] ]
    [ [464 -140] [479 -173] [445 -221] [410 -221] [442 -200] [457 -181] ] [ [246 -320] [274 -281] [237 -297] ]
    [ [230 -301] [238 -347] [158 -366] [110 -325] [166 -348] [215 -337] ] )
  foreach all-penalty-zones [ a-penalty-zone ->
    ask patches with [pcolor != 6.1] [ if is-inside-polygon? self a-penalty-zone [ set is-penalty-zone? true set pcolor yellow ] ] ]  ;; track colour = 6.1
end

to-report get-tyre-stats [ type-string ]
  ;; tyre type health & base wear rate

  if type-string = "soft"   [ report [85 1.1] ]
  if type-string = "medium" [ report [100 1.0] ]
  if type-string = "hard"   [ report [115 0.9] ]
  report [100 1.0]  ;; if no tyre type, default to medium stats
end

to-report get-style-multipliers [ style-string ]
  ;; driving style multiplier figures
  ;; styles modify: top speed, acceleration, braking, cornering, tyre wear
  ;; each style gets a 1.5, 1.2, & 0.8 stat [stats are arbitrary, look into making more realistic]


  ;; --- Driving Style Values ---
                                        ;; spd  acc  brk  cnr  tyr
  if style-string = "Technical"  [ report [0.8  1.0  1.3  1.5  0.8] ]
  if style-string = "Aggressive" [ report [1.3  1.2  1.0  0.8  1.1] ]  ;; speed at 1.5 too OP (speed is king in sim)
  if style-string = "Dynamic"    [ report [1.0  1.5  1.2  1.0  1.3] ]  ;; 1.3 tyr basically makes up for missing 0.8 stat

  if style-string = "Custom"     [ report (list dev-speed dev-acceleration dev-braking dev-corner dev-tyre-wear) ]   ;; controlled with sliders in dev panel

  report [1.0 1.0 1.0 1.0 1.0]  ;; default for "balanced"
end

to-report calculate-grip-modifier [ an-agent ]
  ;; tyre wear does NOT have a linear relationship with performance
  ;; slightly worn tyres are 'warmed up' and therefore perform better than fresh tyres (loose realism)
  ;; after goldilocks 'warmed up' wear state, tyre performance degrades with tyre wear

  let health [tyre-health] of an-agent
  let tyre-info get-tyre-stats [current-tyre-type] of an-agent
  let max-health item 0 tyre-info
  let base-performance item 1 tyre-info
  let health-percent (health / max-health) * 100
  let wear-modifier 1.0
  let max-grip-bonus 0.1

  ;; --- Tyre Wear & Performance Relationship ---
  ifelse health-percent > 70 [
    let x (100 - health-percent) / 30
    set wear-modifier (1.0 + (x * max-grip-bonus))
  ][

    ifelse health-percent >= 40 [
      let x (health-percent - 40) / 29
      set wear-modifier (1.0 + (x * max-grip-bonus))
    ][

      ifelse health-percent < 10 [ set wear-modifier 0.80 ]
      [ ifelse health-percent < 20 [ set wear-modifier 0.85 ]
        [ ifelse health-percent < 30 [ set wear-modifier 0.90 ]
          [ report 0.95 ]
        ]
      ]
    ]
  ]
  report (base-performance * wear-modifier)
end

to-report ticks-since-lap-start [ an-agent ]
  ;; tracks lap-time in ticks
  report ticks - [lap-start-time] of an-agent
end

to-report distance-to-track-edge-at-angle [scan-angle max-dist]
  ;; helps car 'vision' in cornering with an angle modifier

  let dist 1
  while [dist <= max-dist] [
    let p patch-at-heading-and-distance (heading + scan-angle) dist
    if p = nobody or [pcolor] of p = black or [is-penalty-zone?] of p or any? other turtles-on p [  ;; account for other cars (avoid collisions)
      report dist
    ]
    set dist dist + 1
  ]
  report max-dist
end

to-report is-inside-polygon? [ a-patch vertices ]
  ;; support function for drawing geometry for track markers & penalty zones
  ;; if patch is within the area of 3+ points, it's part of the geometry [works fairly well as patch size = 1px, but is very slow]

  let patch-x [pxcor] of a-patch
  let patch-y [pycor] of a-patch
  let num-vertices length vertices
  let is-inside? false
  let j (num-vertices - 1)

  foreach vertices [ vertex-i ->
    let vertex-j item j vertices
    let xi item 0 vertex-i
    let yi item 1 vertex-i
    let xj item 0 vertex-j
    let yj item 1 vertex-j
    let intersects? (((yi > patch-y) != (yj > patch-y)) and (patch-x < (xj - xi) * (patch-y - yi) / (yj - yi) + xi))

    if intersects? [ set is-inside? (not is-inside?) ]
    set j position vertex-i vertices
  ]
  report is-inside?
end

to-report calculate-min-stops
  ;; support function for calculating pit-stop strategy
  ;; specifically, the minimum amount a car can get away with (assuming no excess/unexpected tyre wear) – 'Plan A'

  let wear-per-lap 15  ;; base tyre wear per lap
  let health-per-stint (100 - 35)
  let laps-per-stint (health-per-stint / wear-per-lap)
  if laps-per-stint >= number-of-laps [ report 0 ]
  report floor(number-of-laps / laps-per-stint)
end


;; -----------------------------
;; ===== USER INSTRUCTIONS =====

to show-instructions
  ;; show brief user instructions

  print ""  ;; blank line
  print "     --- Welcome to the NetLogo Grand Prix ---"  ;; spaces at start for legibility [should add to other prints]
  print ""

  print "     MODEL SUMMARY"
  print "     Up to 18 cars use computer vision to navigate their way around real-world racetracks before iteratively mutating their"
  print "     path to find the fastest possible racing line. Whilst doing this, they are actively trying to avoid collisions with"
  print "     one-another, manage their tyre-health, and strategtically time their pit-stops to get the best time and win the race!"
  print ""
  print "     The cars are independent agents, but you have some influence over the white user-car. It's starting position, tyres,"
  print "     and driving style are set by the user. Hopefully you can give an edge over the other cars. Good luck!"
  print ""

  print "     --- User Manual ---"
  print ""

  print "     INITALISE WORLD"
  print "     1. Enter date in date-id & race title in 'race-title' for data recording purposes"
  print "     2. Select track option from 'track' menu (currently only Silverstone is supported)"
  print "     3. Press 'Setup World' to load track geometry"
  print ""

  print "     USER CAR SETUP"
  print "     1. Use the drop-down menu to choose your driving style:"
  print "            i. 'Balanced'  – mid straights, mid cornering"
  print "           ii. 'Aggresive' – faster straights, slower cornering"
  print "          iii. 'Technical' – faster cornering, slower straights"
  print "           iv. 'Dynamic'   – mid corners, mid straights, faster acceleration, faster tyre wear"
  print ""

  print "     2. Use the drop-down menu to choose your starting tyre compound:"
  print "            i. 'Soft'  – highest performance, fastest wear-rate"
  print "           ii. 'Medium' – moderate performance, moderate wear-rate"
  print "          iii. 'Hard' – lowest performance, slowest wear-rate"
  print ""

  print "     3. Use the 'user-start-pos' box to input your drivers starting position (cannot exceed number of cars in race)"
  print ""

  print "     RACE SETUP"
  print "     1. Adjust the sliders for number of cars & laps in the race"
  print "     2. Use the 'show-leaderboard' switch to toggle leadrboard visibility in the top-right corner of the world"
  print "     3. Manage 'Safety Parameters' for the race"
  print "            i. 'run-flat'  – if ON, cars can continue racing after tyre failure through an emergency pit-stop"
  print "           ii. 'crashing-enabled' – if ON, high-speed collisions will result in a crash, and the cars involved will exit the race"
  print ""
end



;; -------------------------
;; ===== DEV FUNCTIONS =====

to dev-force-pit
  let car-to-pit one-of turtles with [car-name = dev-choose-car]

  if car-to-pit != nobody [
    ask car-to-pit [
      set state "pitting"
      set is-emergency-pit? true

      set pit-timer (150 + random 451)
      set pitted-this-lap? true

      show (word car-name " has been forced into an emergency pit stop! [DEV]")
    ]
  ]
end

to dev-force-tyres
let car-to-stop one-of turtles with [car-name = dev-choose-car]

  if car-to-stop != nobody [
    ask car-to-stop [
      set tyre-health 0

      show (word car-name " tyres have been sabotaged [DEV]")
    ]
  ]
end

to dev-dnf-car
  let car-to-dnf one-of turtles with [car-name = dev-choose-car]

  if car-to-dnf != nobody [
    ask car-to-dnf [
      set state "forced-dnf"
      set current-speed 0
      set target-speed 0

      show (word car-name " will not finish the race (DNF) [DEV]")
    ]
  ]
end

to dev-kill-car
  let car-to-kill one-of turtles with [car-name = dev-choose-car and breed != proxies]

  if car-to-kill != nobody [
    let proxy-to-kill one-of proxies with [linked-car = car-to-kill]

    if proxy-to-kill != nobody [
      ask proxy-to-kill [ die ]
    ]

    ask car-to-kill [
      show (word car-name " has been removed from the race. [DEV]")
      die
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
10
10
1019
1020
-1
-1
1.0
1
10
1
1
1
0
0
0
1
-500
500
-500
500
0
0
1
ticks
60.0

BUTTON
1029
199
1288
232
Setup World
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1162
633
1285
670
Start Race
start-race
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1027
492
1284
525
number-of-laps
number-of-laps
1
100
5.0
1
1
NIL
HORIZONTAL

BUTTON
1027
633
1157
670
Reset Race
reset-race\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
1026
566
1127
599
run-flat
run-flat
0
1
-1000

CHOOSER
1028
351
1186
396
starting-tyre-type
starting-tyre-type
"soft" "medium" "hard"
1

INPUTBOX
1029
48
1128
108
date-id
H2-B2
1
0
String

MONITOR
1302
251
1386
296
Speed
[current-speed] of user-car * 100
2
1
11

MONITOR
1452
251
1531
296
RPM
[rpm] of user-car
2
1
11

MONITOR
1392
251
1446
296
Gear
[current-gear] of user-car
0
1
11

MONITOR
1600
251
1683
296
Tyre Health
[tyre-health] of user-car
2
1
11

MONITOR
1303
48
1389
93
Lap Counter
(word ([laps-completed] of user-car) \" / \" number-of-laps)
0
1
11

MONITOR
1395
48
1467
93
Fastest Lap
[best-lap-time] of user-car
0
1
11

MONITOR
1687
251
1771
296
Tyre Type
[current-tyre-type] of user-car
0
1
11

TEXTBOX
1030
14
1208
48
Initialise World
22
0.0
1

TEXTBOX
1027
418
1194
447
Race Controls
22
0.0
1

SLIDER
1027
453
1284
486
number-of-cars
number-of-cars
1
18
3.0
1
1
NIL
HORIZONTAL

CHOOSER
1029
112
1287
157
track
track
"Silverstone" "Monza" "Bahrain" "Monaco"
0

TEXTBOX
1029
267
1196
296
Car Controls
22
0.0
1

TEXTBOX
1301
14
1486
40
Race Telemetry\n
22
0.0
1

BUTTON
1029
162
1287
195
Instructions
show-instructions
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1301
491
1772
670
Engine Telemetry
Time (ticks)
Value
0.0
2500.0
0.0
20.0
true
true
"" ""
PENS
"RPM (x1000)" 1.0 0 -7500403 true "" "plot [rpm] of user-car / 1000"
"Gear" 1.0 0 -2674135 true "" "plot [current-gear] of user-car"

PLOT
1303
101
1773
233
Lap Times
Time
Lap
0.0
1.0
1000.0
2000.0
true
false
"" ""
PENS
"Lap Time" 1.0 0 -7500403 true "" ""

PLOT
1301
304
1772
482
Speed
Time (ticks)
Speed (mph)
0.0
1.0
0.0
1.0
true
false
"" ""
PENS
"Speed (mph)" 1.0 0 -16777216 true "" "plot [current-speed] of user-car * 100"

MONITOR
1674
49
1773
94
Total Race Time
[current-time-racing] of user-car
0
1
11

CHOOSER
1028
302
1186
347
user-driving-style
user-driving-style
"Balanced" "Aggressive" "Technical" "Dynamic" "Custom"
0

SWITCH
1131
566
1283
599
crashing-enabled?
crashing-enabled?
1
1
-1000

SWITCH
1027
529
1284
562
show-leaderboard?
show-leaderboard?
0
1
-1000

INPUTBOX
1191
301
1288
396
user-start-pos
1.0
1
0
Number

INPUTBOX
1132
48
1286
108
race-title
NIL
1
0
String

TEXTBOX
1033
244
1288
262
––––––––––––––––––––––––––––––––––––––––––
11
0.0
1

TEXTBOX
1030
609
1291
627
––––––––––––––––––––––––––––––––––––––––––
11
0.0
1

MONITOR
1536
251
1593
296
DRS
[is-drs-active?] of user-car
17
1
11

SWITCH
1027
780
1155
813
dev-override
dev-override
1
1
-1000

TEXTBOX
1027
722
1221
748
Developer Tools
22
0.0
1

CHOOSER
1027
819
1155
864
dev-driving-style
dev-driving-style
"Balanced" "Aggressive" "Technical" "Dynamic" "Custom"
0

CHOOSER
1160
819
1286
864
dev-starting-tyres
dev-starting-tyres
"soft" "medium" "hard"
1

TEXTBOX
1029
755
1265
777
Variable Override – AI Cars
16
0.0
1

TEXTBOX
1028
707
1771
725
––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
11
0.0
1

TEXTBOX
1413
753
1587
777
Custom Driving Style
16
0.0
1

SLIDER
1412
779
1584
812
dev-speed
dev-speed
0.1
2
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
1412
818
1584
851
dev-acceleration
dev-acceleration
0.1
2
0.9
0.1
1
NIL
HORIZONTAL

SLIDER
1411
857
1583
890
dev-braking
dev-braking
0.1
2
0.2
0.1
1
NIL
HORIZONTAL

SLIDER
1589
778
1761
811
dev-corner
dev-corner
0.1
2
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
1589
818
1761
851
dev-tyre-wear
dev-tyre-wear
0.1
2
1.0
0.1
1
NIL
HORIZONTAL

TEXTBOX
1030
875
1180
895
Force Behaviour
16
0.0
1

CHOOSER
1028
899
1287
944
dev-choose-car
dev-choose-car
"-> YOU    " "VET    " "ALO    " "RAI    " "MSC    " "HAM    " "ROS    " "BUT    " "WEB    " "MAS    " "BOT    " "RIC    " "VER    " "PER    " "HUL    " "SAI    " "NOR    " "LEC    " "GAS    " "OCO    " "TSU    " "ALB    " "LAT    " "MAZ    " "ZHO    " "DEV    " "SAR    " "PIA    " "STR    " "MAG    " "SCH    "
4

BUTTON
1027
988
1155
1021
DNF
dev-dnf-car
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1027
950
1155
983
Pit-Stop
dev-force-pit
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1160
988
1286
1021
Kill
dev-kill-car
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1161
950
1286
983
Pop Tyres
dev-force-tyres
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1292
780
1325
1022
dev-timeout-ticks
dev-timeout-ticks
0
10000
5500.0
100
1
NIL
VERTICAL

TEXTBOX
1415
902
1761
972
NOTE: user-car will only use custom driving style if \"Custom\" is chosen above. Can use it independent of dev mode being active.
11
0.0
1

BUTTON
1160
780
1286
813
Reset Race [DEV]
dev-reset-race
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
888
32
1006
52
LEADERBOARD
16
9.9
1

SWITCH
1413
965
1552
998
adv-path-log
adv-path-log
1
1
-1000

TEXTBOX
1559
963
1772
1021
Logs user-car coordinates for every single lap. Doesn't require dev-override. [NOT WORKING – unsure why, was working in previous versions]
11
0.0
1

@#$#@#$#@
## PURPOSE
Simulation of multi-car races, accounting for various factors such as car set-ups/driver ‘styles’; overtaking and crash avoidance; drag-reduction systems (DRS); pit-stops; and tyre management. The user has control over the starting parameters of a single agent (‘user-car’), beyond which the agents act entirely independently, including in their navigation of the track.

To achieve this, the agents deploy a form of computer vision to establish a path around the track (‘racing-line’), which is then randomly mutated in each subsequent lap. Mutations that lead to better lap times are kept, which others are discarded. The goal of this ‘iterative evolution’ is to find the optimal racing line. 

This creates emergent, complex race outcomes from both agent-agent and agent-world interactions. The current version of the model uses a vector map of Silverstone as the racetrack.


## ENTITIES, VARIABLES, & SCALES
### ENTITIES
*Turtles (cars):* The primary agents in the model, with each representing a single car competing in the race.

*Proxies (leaderboard & data collection):* A secondary breed of agent, each linked one-to-one with a car. Proxies manage and store data for the leaderboard display and final data export, which helps to reduce computational load during the main simulation loop (race). When cars were handling the entire data reporting process, there would often be stuttering on lap-changes that could cause significant issues with pathfinding.

*Patches (track environment):* The static environment representing the Silverstone racetrack. Patches have various properties that influence agent behaviour, such as “penalty zones” that act like gravel would in a real race-track, or the “pit-zone” for pit-stops (in place of the complex pathfinding required of a proper pit-lane).


### VARIABLES
*[SEE TOP SECTION OF CODE OR ODD IN REPORT APPENDIX]*Z

### SCALES
*Spatial:* The world is a 2D 1000x1000px grid representing the Silverstone circuit, with a patch-size of 1px. The Silverstone circuit was originally a vector image with generally accurate anatomy, but the road-width and penalty-zones (gravel) was adjusted for the simulation.

*Temporal:* Time is discrete, advancing in ticks that have no connection to a real unit of time. There is a 0.0075 second delay between ticks, but this only pauses the simulation for visual enhancement, and does not affect recorded times.


## PROCESS OVERVIEW & SCHEDULING
The simulation proceeds via the ‘start-race’ procedure, which is executed once per tick. The order-of-operations within a tick is:
*1.	Agent state updates:* Cars in the "racing", "pitting", or "cool-down" states perform their respective actions:
“Racing” Cars: Execute drive-lap (pathfinding, speed calculation, movement) and record-lap (data logging, lap completion checks).
“Pitting” Cars: Wait through their pit-timer. Once the timer reaches zero, their state changes back to "racing".
Cool-down Cars: Drive a slow lap (‘drive-cool-down-lap’) until the race ends.

*2.	Collision Checks:* All cars check if they are on the same patch as another car (‘check-for-collisions’).

*3.	Leaderboard Update:* Periodically (‘time-update-interval’ number of ticks), the live race time for each car is updated, and the leaderboard is re-sorted to reflect the current standings.

*4.	End-of-Race Check:* The model checks if the race should conclude, either because all cars have finished or because the ‘completion timer’ – which starts after the first car finishes its final lap (‘race-timeout-tick’) – has ran through its set number of ticks.

*5.	Data Export & Stop:* If the race is complete, race summary data, detailed best-lap data, and collision logs are written to .csv files, and the simulation stops

*6.	Tick Advance:* The global tick counter is incremented.


## DESIGN CONCEPTS
### EMERGENCE
The overall race result – finishing positions, final times, and the number of DNFs – is an emergent property of the system, arising from the cumulative effect of low-level decisions and interactions made by each car at every tick. The optimal racing line (best-line) for each car is also an emergent feature, discovered and refined over successive laps rather than being pre-programmed or set by the user.

### HETERGOHENEOUS AGENT INTERACTION
Agents are not identical (but can be very similar with the right settings), and act independently; with their actions both directly and indirectly influencing other agents. Cars differ from one another through:
*1.	Performance Profiles:* each ‘AI’ car is randomly assigned a driving-style ("Aggressive", "Technical", "Dynamic", or "Balanced"), which carry different multipliers for top speed, acceleration, braking, cornering ability, and tyre wear.
"Aggressive" cars will excel on straights but struggle more in corners
"Technical" cars trade top speed and acceleration for significantly better cornering ability
“Dynamic” cars have enhanced acceleration and braking for better overtaking ability, but wear through its tyres at a faster rate
“Balanced” cars have no significant strengths or weaknesses 

*2.	Strategic Variation:* Cars start with different tyre compounds ("soft", "medium", or "hard") and dynamically calculate unique pit stop strategies (‘update-pit-strategy’) based on their individual tyre wear rates (‘last-valid-lap-wear’). A car with a "Dynamic" style, which has high acceleration but also high tyre wear, will likely need to adopt a different pit strategy than a "Balanced" car. Tyre compounds can also be changed during any pit-stop, adding a further layer of strategic ability.

*3.	Initial Conditions:* Cars start the race at different positions on the grid.

### ADAPTATION
*1.	Speed Modulation:* Cars calculate their target-speed by looking ahead on the track (‘explore-logic’) or at upcoming points on their best-line (‘race-logic’). They slow down for upcoming turns or to avoid collisions, and accelerate on straights.

*2.	Racing Line Improvement:* The first lap is an "explore" lap to establish an initial racing line. On subsequent laps, both random mutations and movement from environmental factors alter that racing line. If a car achieves a new best-lap-time, its current-line is saved as the new best-line, allowing it to iteratively find faster routes.

*3.	Pit Strategy Adaptation:* Cars can dynamically re-calculate their target pit-stop lap based on the rate of tyre wear from the previous lap (‘update-pit-strategy’). If wear is higher [lower] than expected (e.g. from spending time in penalty zones), the car will plan to pit sooner [later] or enter an emergency pit state (‘emergency-pit-stop?’) to pit ASAP.

*4.	Error Correction:* If a car goes off-track multiple times in one lap (‘off-track-resets-this-lap’ > 3), it concludes its best-line is flawed and re-enters the “explore” state (‘force-explore-lap?’) to find a completely new route on its next lap.

### SENSING
Cars can perceive their environment at the local scale, enabling them to:

1.	Identify the properties of the patch they are currently on (‘is-pentalty-zone?’, ‘is-sf-line?’, etc.)

2.	Understand their distance to the track edges and other cars using three splayed forward-facing “whiskers”.

3.	"Sense" upcoming turn severity by examining the change in heading between future points on their best-line.

### STOCHASTICITY
Intentional randomness is used to introduce a further degree of variation and unpredictability to the simulation:

1.	“AI” cars are assigned a random driving style and starting tyre compound.

2.	Each cars’ steering responsiveness is initialised with a small random component to create minor differences in handling.

3.	The duration of a pit-stop includes a random element to simulate the performance variability of real-life pit-crews


## INITIALISATION
The model is initialised using the ‘setup’ procedure, which clears any previous world state and calls on the ‘setup-track’ and ‘reset-race’ procedures.

1.	‘setup-track’ imports the track geometry from a .png image and draws the complex geometry for the penalty-zones, pit-zone, start-finish line.

2.	‘reset-race’ initialises the race conditions, and can be called independently to reset those conditions at any point without having to fully clear the world state and reload the complex geometry (very time-consuming). It calls on multiple other procedures to:

	i.	Setup race parameters (‘setup-physics’)
	ii.	Create agents (‘create-cars’, ‘create-proxies’)


## INPUT DATA
The primary input for the model is a PNG file for the track geometry (‘silverstone_alt.png’ – “alt” because multiple versions were created before getting track width, colour, etc. right). All other world components and model parameters are set using internal logic. However, there was an initial ‘input’ for different geometries, where vector image software was used to design and map the geometry, but directly importing those images led to unexpected (and unresolved) alignment issues.

## SUB-MODELS
*1.	drive-lap:* The main decision-making procedure for a racing car. It determines whether to use the explore-logic (if no ‘best-line’ exists) or race-logic. After choosing a logic, it calls update-car-physics to adjust speed and moves the car forward.

*2.	explore-logic:* A navigation algorithm for when a car has no racing line to follow. It uses three "whiskers" to find the longest clear path ahead, avoiding track edges, penalty zones, and other cars. The car's target-speed is proportional to how clear the path ahead is.

*3.	race-logic:* The primary racing algorithm – the car attempts to follow its stored best-line. It looks ahead on this line to anticipate turns – adjusting its target-speed based on the corner's severity – and other cars, braking or overtaking them (‘check-for-collisions’). Speed is also modified by tyre grip (‘calculate-grip-modifier’).

*4.	update-car-physics:* This sub-model calculates the car's new current-speed. It applies acceleration or braking to move the current-speed towards the target-speed. These forces are modified by multipliers from the car's driving-style and a power curve based on the current rpm and gear of a rudimentary engine simulation (‘update-gears’, ‘calculate-power-modifier’).

*5.	calculate-grip-modifier:* A function that models tyre performance. It returns a grip multiplier based on tyre-health. Grip is optimal when tyres are slightly worn ("warmed up"; 70 - 100% health) and degrades significantly as health drops below 40%.

*6.	update-pit-strategy:* How a car plans its pit-stops. After each valid lap, it calculates its tyre wear rate, and if the projected lifespan of its current tyres is insufficient to finish the race, it calculates an optimal ‘planned-pit-lap’ and chooses the best compound for the next stint (‘choose-next-tyres’).

*7.	record-lap:* This procedure is called continually, checking if the car has crossed a mid-lap tracking marker (‘is-tracking-point?’) or the start/finish line (‘is-sf-line?’). Upon crossing the marker and start/finish line in the correct sequence, it logs the lap time, updates performance data, determines if the lap was a new best-lap-time, and resets lap-specific variables for the next lap. It also handles the logic for finishing the race if the required number of laps is complete.

*8.	check-for-collisions:* A simple collision model. It reports a collision if two racing cars are on the same patch in the same tick. If crashing is enabled and speed is above a threshold, it changes the state of both cars to "finished", and they’re marked DNF at the end of the race.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
