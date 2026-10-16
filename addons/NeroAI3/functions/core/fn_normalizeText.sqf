params ["_value", ["_maxLength", 240]];

private _text = if (_value isEqualType "") then {_value} else {str _value};
private _separators = toString [34, 59, 91, 93, 13, 10, 9];
_text = (_text splitString _separators) joinString " ";
_text = trim _text;
while {(_text find "  ") >= 0} do { _text = (_text splitString "  ") joinString " "; };
if ((count _text) > _maxLength) then { _text = _text select [0, _maxLength]; };
_text
