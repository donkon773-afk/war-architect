/* Shared player/AI accounting gate; engine ownership is checked by the caller. */
params ["_price","_stock","_reserve","_issued","_budget","_fleet","_limit","_already","_ready","_air",["_units",0],["_pilots",0]];
_price>0 && {_price<=2000} && {_stock-_price>=_reserve} && {_issued<_budget} && {_fleet<_limit} && {!_already} && {_ready} && {!_air || {_pilots>=1 && {_pilots<=2} && {_units-_pilots>=2}}}
