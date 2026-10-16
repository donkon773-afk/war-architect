/* All debits and freight receipts pass through one deterministic, idempotent ledger. */
params ["_stocks","_ledger","_event","_id","_source","_destination","_amount",["_cap",5000]];
private _s=+_stocks;private _l=_ledger apply {+_x};private _ok=false;private _entry=_l findIf {(_x#0)==_id};
if (_amount isEqualType 0 && {_amount>0} && {_amount<=_cap}) then {
 switch (_event) do {
  case "dispatch";case "spend": {if (_entry<0 && {_source>=0} && {_source<count _s} && {(_s#_source)>=_amount}) then {_s set [_source,(_s#_source)-_amount];_l pushBack [_id,if (_event=="dispatch") then {0} else {1}];_ok=true;};};
  case "restore": {if (_entry<0) then {_l pushBack [_id,0];_ok=true;};};
  case "deliver": {if (_entry>=0 && {((_l#_entry)#1)==0} && {_destination>=0} && {_destination<count _s}) then {_s set [_destination,((_s#_destination)+_amount) min _cap];_l set [_entry,[_id,1]];_ok=true;};};
  case "lost": {if (_entry>=0 && {((_l#_entry)#1)==0}) then {_l set [_entry,[_id,2]];_ok=true;};};
  case "produce": {if (_destination>=0 && {_destination<count _s}) then {_s set [_destination,((_s#_destination)+_amount) min _cap];_ok=true;};};
 };
};
[_s,_l,_ok]
