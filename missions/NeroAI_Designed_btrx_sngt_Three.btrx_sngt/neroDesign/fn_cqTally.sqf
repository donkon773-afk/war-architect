/* Pure vote resolution. A tied incumbent stays selected; otherwise the first sector wins. */
params ["_votes","_allowed",["_previous",-1]];
private _leader=-1;private _best=0;private _total=0;
{
 private _sector=_x;private _count={_x==_sector}count _votes;
 _total=_total+_count;
 if(_count>_best || {_count==_best && {_count>0} && {_sector==_previous}})then{_leader=_sector;_best=_count;};
}forEach _allowed;
[_leader,_best,_total]
