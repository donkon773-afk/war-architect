/* Pure catalog projection: prices and classes always come from the side's preset. */
params ["_catalog", ["_category", -1], ["_query", ""]];
if(!(_catalog isEqualType []))exitWith{[]};
private _rows=[];
private _needle=toLower _query;
{
 private _bucket=_forEachIndex;
 if(_x isEqualType [] && {_category<0 || {_category==_bucket}})then{
  {
   if(_x isEqualType [] && {count _x>=4})then{
    _x params["_class","_cost","_requirements","_name"];
    if(_class isEqualType "" && {_cost isEqualType 0} && {_cost>0} && {_name isEqualType ""} && {_requirements isEqualType []})then{
     if(_needle=="" || {(toLower(_name+" "+_class))find _needle>=0})then{_rows pushBack[_bucket,_class,_cost,+_requirements,_name];};
    };
   };
  }forEach _x;
 };
}forEach _catalog;
_rows
