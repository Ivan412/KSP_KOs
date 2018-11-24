//VERSION 0.4
//===============================ФУНКЦИИ==========================
//это библиотека для движений роверов


//инициализация глобальных переменных
function _init_lib_drive{
    runoncepath("lib/lib_pid.ks").
    global route is list().		//очередь точек маршрута
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


//вычисляет "знак" скорости
function _speed_sign{

    if vang(ship:facing:forevector, ship:srfprograde:forevector) > 90{
        return -1.
    }
    else{
        return 1.
    }
}


//вычисляет значение скорости при приближении, по формуле y=kx+b
function _closing_speed{
    parameter targ.						//цель
    parameter distance.					//дистанция приближения
    parameter speed.					//желаемое превышение скорости

    local ds is 0.
    local targ_gs is 0.
    local maxspeed is 25.					//максимальная скорость. если цель движется быстрее(прямо от нас), мы ее не догоним

								//устанавливаем локальные переменные в зависимости от типа 
    if targ:istype("vessel"){
        set ds to max(ship:groundspeed - targ:groundspeed, 0).	//разница скоростей, если цель быстрее, жмем на педаль )
        set targ_gs to targ:groundspeed.			//наземная скорость цели
    }
    else if targ:istype("geocoordinates"){
        set ds to ship:groundspeed.				//разница скоростей = нашей скорости, тк геокоординаты не могут двигаться
        set targ_gs to 0.					//тут и так понятно
    }
    else{
        return 0.
    }

    local k is (ds - 1) / (ds * 2).				//k
    local x is targ:distance - distance.		//x


								//если мы ближе чем планировали, сравниваем скорости.
    if targ:distance < distance{
        return round(targ_gs, 1).
    }
								//если до требуемой дальности осталось меньше чем две скорости превышения 
								//уменьшаем скорость по формуле y=kx+b, где скорость превышения(y) 
								//вычисляется из: k - коэффициент, x - расстояние до требуемой 
								//дистанции, b = 1.   
    else if targ:distance > distance and targ:distance < distance + 2 * ds{
        return round(k * x + 1, 1).
    }
								//если до требуемой дальности до цели больше, чем 2 скорости превышения, 
								//едем с желаемой скоростью превышения или максимальной
    else if targ:distance > 2 * ds + distance{
        return round(min((targ_gs + speed), maxspeed), 1).
    }
}


//функция добавления точек в маршрут.
function route_add_wp{
    parameter route_l.					//список точек маршрута
    parameter targ.					//цель
    parameter speed is 25.				//превышение скорости над целью
    parameter distance is 20.				//дистанция на которой скорость становится равна скорости цели
    parameter follow is false.				//нужно ли следавать за целью, если изменились ее координаты

    local wp is lexicon().		//точка маршрута. словарь. доступ по ключам: "targ": ссылка на функцию, возвращает место, куда 
					//едем, "speed": желаемое превышение скорости, "distance": расстояние при достижении которого 
					//происходит переключение на следующую точку маршрута или остановка(если точек больше нет), 
					//"follow": bool если true, то мы едем за целью. переключения на следующую точку маршрута не 
					//будет, "on_way": bool выполняется ли текущая точка маршрута .

    if not _target_type_ok(targ){
        print("Wrong type of target!").
        return route_l.
    }
    set wp["targ"] to targ.						//устанавливаем цель
    set wp["speed"] to _closing_speed@:bind(targ, distance, speed).	//устанавливаем желаемое превышение скорости над целью
    set wp["distance"] to max(distance, 20).				//устанавливаем желаемую дистанцию(точность) до цели
    if wp["targ"]:istype("vessel"){					//устанавливаем флаг приследования
        set wp["follow"] to follow.	
    }
    else{
        set wp["follow"] to false.
    }
    set wp["on_way"] to false.						//устанавливаем флаг текущей точки

    route_l:add(wp).							//добавляем waypoint в очередь
    return route_l.
}


function drive{
    parameter route_l.

    local current_waypoint is 0.
								//если маршрут пуст - ничего не делаем
    if route_l:empty{
        return route_l.
    }
								//если точка "не в пути", создаем пиды, помечаем точку как "в пути"
    else if not route_l[0]["on_way"]{
        brakes off.
        pid_add(pids, "speed", route_l[0]["speed"], {return ship:groundspeed * _speed_sign.}, {return ship:control:wheelthrottle.}, {parameter a. set SHIP:CONTROL:WHEELTHROTTLE to a.}, true, 1/10, 0, 1/10, -1, 1).
        pid_add(pids, "cource", {return 0.}, {return route_l[0]["targ"]:bearing.}, {return ship:control:wheelsteer.}, {parameter a. set ship:control:wheelsteer to max(min(a, 5/10), -5/10).}, true, 1/1000, 0, 5/10000, -5/10, 5/10).
        set route_l[0]["on_way"] to true.
    }
								//если мы достигли точки, удаляем ее из маршрута, удаляем пиды
    else if route_l[0]["targ"]:distance < route_l[0]["distance"] and not route_l[0]["follow"]{
        route_l:remove(0).
        pid_change(pids, "speed", -1).
        pid_change(pids, "cource", -1).
        brakes on.
        return route_l.
    } 
								//если мы не достигли точки, или она отдалилась отключаем тормоз
    else if route_l[0]["targ"]:distance > route_l[0]["distance"]{
        brakes off.
        return route_l.
    }
								//мы достигли точки за которой следуем, надо подождать на ручнике
    else if route_l[0]["targ"]:distance < route_l[0]["distance"] and route_l[0]["follow"]{
        brakes on.
        return route_l.
    }

    return route_l.
}


//===============================ТРИГГЕРЫ=========================
//===============================ОСНОВНОЕ ТЕЛО====================


_init_lib_drive().


//===============================ОСНОВНОЙ ЦИКЛ====================

