/* PURE: continuous work gate; a past permission is not a repair guarantee. */
params ["_current","_knownNear","_sinceHit","_cover",["_speed",0]];
_current && {_knownNear >= 200} && {_sinceHit >= 20} && {abs _speed < 1}
    && {_knownNear >= 600 || {_cover}}
