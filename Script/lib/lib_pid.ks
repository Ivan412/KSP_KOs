//VERSION 0.74
//===============================ФУНКЦИИ==========================

//инициализация глобальных переменных
function _init_lib_pid{
    global pids is lexicon().		//общий словарь пидов: доступ по именам ко вложенному словарю.
					
}

//функция добавления пида в коллекцию. параметры: pids_lex: lexicon, pid_name:string, setpoint: delegate, curr_setpoint: delegate, get_val_driver: delegate, set_val_driver: delegate(1 patameter), [active: boolean], [kp: float], [ki: float], [kd: float], [minoutput: float], [maxoutput: float].
//пример запуска: pid_add(pids, "speed", {return 6.}, {return ship:groundspeed.}, {return ship:control:wheelthrottle.}, {parameter a. set SHIP:CONTROL:WHEELTHROTTLE to a.}, true, 2/10, 0, 1/10, -1, 1).
function pid_add{
				//обязательные параметры
    parameter pids_lex.		//словарь пидов
    parameter pid_name.		//имя пида
    parameter setpoint.		//ссылка на функцию. возвращает значение желаемого параметра к которому стремится пид. например, 6.
    parameter curr_setpoint.	//ссылка на функцию. возвращает текущее значение желаемого параметра. например, скорость относительно земли = 3.
    parameter get_val_driver.	//ссылка на функцию. возвращает текущее усилие управляющего механизма. например, тяга = 0.1
    parameter set_val_driver.	//ссылка на функцию, имеет 1 обязательный параметер. устанавливает новое усилие управляющего механизма.
    				//не обязательные параметры
    parameter active is true.	//флаг пида. если false, то пид "заморожен". по умолчанию true. 
    parameter kp is 1.		//параметры пида с дефолтным значением
    parameter ki is 0.
    parameter kd is 0.
    parameter minout is 0.
    parameter maxout is 1.

    local pid is lexicon().	//создаем словарь с настройками и значениями для пида. доступ по ключам
				//"active" к флагу пида показывющий обсчитывается он или нет 
				//"pid" структура типа pidloop
				//"cur_setpoint" ссылка на функцию. значение желаемого параметра, например скорость к которой мы стремимся
				//"set_val_driver" ссылка на функцию, имеет 1 обязательный параметер. 
				//устанавливает новое усилие управляющего механизма.
				//"get_val_driver" ссылка на функцию. возвращает текущее усилие управляющего механизма.


    set pid["active"] to active.				//устанавливаем флаг
    set pid["setpoint"] to setpoint.				//добавляем ссылку на функцию в словарь для дальнейшего использования
    set pid["pid"] to pidloop(kp, ki, kd, minout, maxout).	//создаем объект типа pidloop
    set pid["pid"]:setpoint to pid["setpoint"]:call.		//устанавлиаем желаемое значение объекту pidloop
    set pid["curr_setpoint"] to curr_setpoint.			//добавляем ссылку на функцию в словарь для дальнейшего использования
    set pid["set_val_driver"] to set_val_driver.		//добавляем ссылку на функцию в словарь для дальнейшего использования
    set pid["get_val_driver"] to get_val_driver.		//добавляем ссылку на функцию в словарь для дальнейшего использования

    set pids_lex[pid_name] to pid.			//добавляем в ообщий словарь пидов словарь с настройками и значениями для пида.

    return pids_lex.
}


//функция которая замораживает/размораживает или удаляет пид ио общего словаря. параметры: имя, [mode]
function pid_change{
    parameter pids_lex.		//словарь пидов
    parameter pid_name.		//обязательный параметер
    parameter mode is 0.	//режим: 1 - разморозить, 0 - заморозить, -1 - удалить.
    
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


//функция которая обновляет рассчеты пидов и применяет новые значения.
function pids_upd_and_apply{
    parameter pids_lex.		//словарь пидов
    local dt is 0.		//дельта значений при последнем обновлении пида
    local thrott is 0.		//усилие управляющего механизма
    if pids:length < 1{		//если пидов нет, выходим
        return pids_lex.
    }
    for pid in pids:keys{							//перебор всех элементов в словаре по ключам
        if pids[pid]["active"] = true{						//отсеевание "замороженных" пидов
            set pids[pid]["pid"]:setpoint to pids[pid]["setpoint"]:call. 	//обновляем пиду setpiont
            set dt to pids[pid]["pid"]:update(time:seconds, pids[pid]["curr_setpoint"]:call).	//вычисляем дельту
            set thrott to dt + pids[pid]["get_val_driver"]:call.		//вычисляем новое усилие
            pids[pid]["set_val_driver"]:call(thrott).				//устанавливаем усилие на механизме.
        }
    }
    
    return pids_lex.
}


//===============================ТРИГГЕРЫ=========================


//===============================ОСНОВНОЕ ТЕЛО====================


_init_lib_pid().

//===============================ОСНОВНОЙ ЦИКЛ====================

