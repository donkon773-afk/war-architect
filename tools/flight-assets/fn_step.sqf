/* Pure time-scaled envelope and gameplay fuel surcharge. Speeds m/s, profile km/h. */
params ["_speed","_previousSpeed","_dt","_cruise","_limit","_boost","_power","_engine","_airborne","_fuel","_baseBurn"];
_dt=(_dt max .01) min .25;
private _ceiling=_limit/3.6;private _extra=0;
if (_engine && {_airborne} && {_fuel>0} && {_boost} && {_power>.9} && {_speed<_ceiling}) then {
 // Native booster acceleration counts against the same 3 m/s² assistance budget.
 private _nativeAcceleration=((_speed-_previousSpeed)/_dt) max 0;
 _extra=((3-_nativeAcceleration) max 0)*_dt min (_ceiling-_speed);
};
private _brake=if (_airborne && {_speed>_ceiling}) then {(_speed-_ceiling) min (6*_dt)} else {0};
private _fraction=((_speed*3.6-_cruise)/((_limit-_cruise) max 1)) max 0 min 1;
private _factor=1+4*_fraction*_fraction;
private _burn=if (_engine && {_airborne} && {_speed*3.6>_cruise}) then {(_baseBurn max .000025)*(_factor-1)*_dt} else {0};
[_extra,_brake,_burn,_factor]
