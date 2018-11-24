//VERSION 0.77
//===============================FUNCTIONS==========================


function _init_lib_pid{
    global pids is lexicon().		//shared lexicon of PIDs
}


//PID add function. Parameters: pids_lex: lexicon,
//pid_name:string, setpoint: KOSDelegate, curr_setpoint: KOSDelegate,
//get_val_driver: KOSDelegate, set_val_driver: KOSDelegate(1 patameter),
//[active: boolean], [kp: float], [ki: float], [kd: float], [minoutput: float],
//[maxoutput: float].
//Example: pid_add(pids, "speed", {return 6.}, {return ship:groundspeed.},
//{return ship:control:wheelthrottle.},
//{parameter a. set SHIP:CONTROL:WHEELTHROTTLE to a.}, true, 2/10, 0, 1/10, -1, 1).
function pid_add{
    parameter pids_lex.		//lexicon of PIDs
    parameter pid_name.		//PID name
    parameter setpoint.		//KOSDelegate. Returns value to wich aspire
    parameter curr_setpoint.	//KOSDelegate. Returns current value
    parameter get_val_driver.	//KOSDelegate. Returns current driver force
    parameter set_val_driver.	//KOSDelegate. Set force to driver
    parameter active is true.	//If false, PID will be not updating in mainloop
    parameter kp is 1.
    parameter ki is 0.
    parameter kd is 0.
    parameter minout is 0.
    parameter maxout is 1.

    local pid is lexicon().
    set pid["active"] to active.
    set pid["setpoint"] to setpoint.
    set pid["pid"] to pidloop(kp, ki, kd, minout, maxout).
    set pid["pid"]:setpoint to pid["setpoint"]:call.
    set pid["curr_setpoint"] to curr_setpoint.
    set pid["set_val_driver"] to set_val_driver.
    set pid["get_val_driver"] to get_val_driver.

    set pids_lex[pid_name] to pid.
    return pids_lex.
}


function pid_mode{
    parameter pids_lex.
    parameter pid_name.
    parameter mode is 0.	//mode: 1 - unfreeze, 0 - freeze, -1 - del.

    if mode = 1{
        set pids[pid_name]["active"] to true.
    }
    else if mode = 0{
        set pids[pid_name]["active"] to false.
    }
    else if mode = -1{
        pids:remove(pid_name).
    }
    else{
        print "function pid_control: wrong command!".
    }
    return pids_lex.
}


//This function updating PIDs and set values to drivers
function pids_upd_and_apply{
    parameter pids_lex.
    local df is 0.          //Force delta since last update
    local force is 0.       //Force for apply on driver
    if pids:length < 1{
        return pids_lex.
    }
    for pid in pids:keys{
        if pids[pid]["active"] = true{	//Update only active PIDs
            //setpiont update
            set pids[pid]["pid"]:setpoint to pids[pid]["setpoint"]:call.
            //calculate delta between setpoint and current value thats we have
            set df to pids[pid]["pid"]:update(time:seconds, pids[pid]["curr_setpoint"]:call).
            //calculate new force
            set force to df + pids[pid]["get_val_driver"]:call.
            //apply force to driver
            pids[pid]["set_val_driver"]:call(force).
        }
    }

    return pids_lex.
}


//===============================TRIGGERS=========================


//===============================BODY====================


_init_lib_pid().

//===============================MAIN LOOP====================
