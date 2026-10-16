//////// artillery radar
//mark the position of artillery fire




_arty_unit_radar_target= (_this # 0);
_arty= artillery_list findIf {typeOf _arty_unit_radar_target == _x};

	if (_arty> -1) then 
	{
		deleteMarker format ["CONTACT %1",(marker_number-3)];
		marker_number=marker_number+1;
		_marker = createMarker [format ["CONTACT %1",marker_number], _arty_unit_radar_target]; 
		_marker setMarkerType "mil_warning";
		_marker setMarkerColor "ColorRed";
		_now = date; 
		_hour = _now # 3; 
		_min  = _now # 4;
		_marker setMarkerText format ["INDIRECT FIRE - %1:%2",_hour,_min];
	};	
