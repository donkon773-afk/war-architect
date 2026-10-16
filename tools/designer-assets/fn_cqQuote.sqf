/* Pure server quote: exact allowlist membership, quantities and complete affordability. */
params["_catalog","_classes","_funds"];
if(!(_classes isEqualType []) || {!(_funds isEqualType 0)} || {count _classes<1} || {count _classes>8} || {(_classes findIf{!(_x isEqualType "")})>=0})exitWith{[false,0,"Недопустимый заказ."]};
private _rows=[_catalog]call NeroWL_Design_fnc_cqCatalog;private _cost=0;private _valid=true;
{
 private _class=_x;private _index=_rows findIf{(_x#1)==_class};
 if(_index<0)exitWith{_valid=false;};_cost=_cost+((_rows#_index)#2);
}forEach _classes;
if(!_valid)exitWith{[false,0,"Класс отсутствует в каталоге вашей стороны."]};
if(_funds<_cost)exitWith{[false,_cost,format["Для заказа нужно %1 CP.",_cost]]};
[true,_cost,""]
