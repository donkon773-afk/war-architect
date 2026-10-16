// Spread each new formation horizontally and vertically; no random collision pile.
params ["_entry","_heading","_slot","_altitude"];
private _column=(_slot mod 4)-1.5;
private _row=floor (_slot/4);
private _lateral=_column*650;
private _back=-_row*700;
[(_entry#0) + sin _heading*_back + cos _heading*_lateral,
 (_entry#1) + cos _heading*_back - sin _heading*_lateral,
 _altitude+(_slot mod 3)*150]
