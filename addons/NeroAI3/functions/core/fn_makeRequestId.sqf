private _ticks = floor (diag_tickTime * 1000);
private _entropy = floor (random 1000000);
format ["n3_%1_%2", _ticks toFixed 0, _entropy toFixed 0]
