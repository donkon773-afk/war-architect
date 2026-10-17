/* Confirmed successes leave the cart; failures and unprocessed rows stay. */
params ["_sent","_results"];
private _remaining=[];private _bought=0;
{if (_forEachIndex<count _results && {((_results#_forEachIndex)#0) isEqualTo true}) then {_bought=_bought+1;} else {_remaining pushBack _x;};} forEach _sent;
[_remaining,_bought,count _sent-_bought]
