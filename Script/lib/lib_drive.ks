//VERSION 0.51
//===============================FUNCTIONS==========================


function _init_lib_drive{
    runoncepath("lib/lib_pid.ks").
    global route is list().		                 //list of navpoints
}


function _target_type_ok{
    parameter targ.
    if targ:istype("vessel") or targ:istype("geocoordinates"){
        return true.
    }
    else{
        return false.
    }
}


function _speed_sign{
    if vang(ship:facing:forevector, ship:srfprograde:forevector) > 90{
        return -1.
    }
    else{
        return 1.
    }
}


//calculate approach speed(y=kx+b)
function _closing_speed{
    parameter targ.					  	//target
    parameter distance.					//distance to target to wich aspire
    parameter speed.				  	//excess over targ's speed(for approch to the targ)

    local ds is 0.              //speed delta
    local targ_gs is 0.         //targ's ground speed
    local maxspeed is 25.				//software speed limit

    if targ:istype("vessel"){
        set ds to round(max(ship:groundspeed - targ:groundspeed, 0), 2).
        set targ_gs to round(targ:groundspeed, 2).
    }
    else if targ:istype("geocoordinates"){
        set ds to ship:groundspeed.
        set targ_gs to 0.
    }
    else{
        return 0.
    }
    
    if targ:distance < distance{              //we are reached the goal distance
        return round(targ_gs, 1).             //equalize speed
    }
                //we are almost reached the goal distance. the excess speed decreasing
    else if targ:distance > distance and targ:distance < distance + 2 * ds{
        local k is (ds - 1) / (ds * 2).				    //k
        local x is targ:distance - distance.		  //x
        return round(k * x + 1, 1).
    }
                // we are far from targ
    else if targ:distance > 2 * ds + distance{
        return round(min((targ_gs + speed), maxspeed), 1).
    }
}


function route_add_wp{
    parameter route_l.					//route-list
    parameter targ.					    //target
    parameter speed is 25.			//excess over targ's speed
    parameter distance is 20.		//distance of speed equalization
    parameter follow is false.	//should we follow for the target?

    local wp is lexicon().  //waypoint. lexicon. keys are:
                            //"targ": KOSDelegate, returns geocoordinates where we are going
					                  //"speed": excess speed,
                            //"distance": distance to switch to the next waypoint
					                  //"follow": should we follow for the target?
					                  //"on_way": bool. to this piont we are going

    if not _target_type_ok(targ){
        print("Wrong type of target!").
        return route_l.
    }
    set wp["targ"] to targ.
    set wp["speed"] to _closing_speed@:bind(targ, distance, speed).
    set wp["distance"] to max(distance, 20).
    if wp["targ"]:istype("vessel"){
        set wp["follow"] to follow.
    }
    else{
        set wp["follow"] to false.
    }
    set wp["on_way"] to false.
    route_l:add(wp).
    return route_l.
}


function drive{
    parameter route_l.

    local current_waypoint is 0.

    if route_l:empty{
        return route_l.
    }
								//next waypoint is not "on_way". creating PIDs, set "on_way" on
    else if not route_l[0]["on_way"]{
        brakes off.
        pid_add(pids, "speed", route_l[0]["speed"], {return ship:groundspeed * _speed_sign.}, {return ship:control:wheelthrottle.}, {parameter a. set SHIP:CONTROL:WHEELTHROTTLE to a.}, true, 1/10, 0, 1/10, -1, 1).
        pid_add(pids, "cource", {return 0.}, {return route_l[0]["targ"]:bearing.}, {return ship:control:wheelsteer.}, {parameter a. set ship:control:wheelsteer to max(min(a, 5/10), -5/10).}, true, 1/1000, 0, 5/10000, -5/10, 5/10).
        set route_l[0]["on_way"] to true.
    }
								//waypoint reached. remove PIDs and waypiont
    else if route_l[0]["targ"]:distance < route_l[0]["distance"] and not route_l[0]["follow"]{
        route_l:remove(0).
        pid_mode(pids, "speed", -1).
        pid_mode(pids, "cource", -1).
        brakes on.
        return route_l.
    }
								//waypoint not reached yet, or moved away
    else if route_l[0]["targ"]:distance > route_l[0]["distance"]{
        brakes off.
        return route_l.
    }
								//waypoint reached in follow mode. brakes on
    else if route_l[0]["targ"]:distance < route_l[0]["distance"] and route_l[0]["follow"]{
        brakes on.
        return route_l.
    }

    return route_l.
}


//===============================TRIGGERS=========================
//===============================BODY====================


_init_lib_drive().


//===============================MAIN LOOP====================
