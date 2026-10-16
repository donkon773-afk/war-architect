/* Departure requires the entire live party, adequate seats and a current assignment. */
params ["_party","_aboard","_capacity","_expired","_changed","_driver"];
if (_party<1 || {_capacity<_party} || {_expired} || {_changed} || {!_driver}) exitWith {"ABORT"};
if (_aboard==_party) then {"READY"} else {"WAIT"}
