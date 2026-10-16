/* Pure order identity: two absent contacts are the same patrol, not a new attack. */
params ["_elapsed","_previousKey","_nextKey","_previousReturn","_return","_moved",["_interval",75]];
_elapsed>=_interval || {!(_previousKey isEqualTo _nextKey)} || {!(_previousReturn isEqualTo _return)} || {_moved>1500}
