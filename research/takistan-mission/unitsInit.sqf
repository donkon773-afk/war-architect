////init code
//set unit base skill and other traits

_unit= (_this # 0);


_unit setSkill 0.8;

//specops
_unitCheck= specop_list findIf {typeOf _unit == _x};

	if (_unitCheck > -1) then
	{
		_unit setSkill 1;
	};

//low skilled soldiers
_unitCheck= lowSkill_list findIf {typeOf _unit == _x};

	if (_unitCheck > -1) then
	{
		_unit setSkill 0.2;
	};
