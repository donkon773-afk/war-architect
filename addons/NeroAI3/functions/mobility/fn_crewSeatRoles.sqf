/* PURE descriptors [role, personTurret, occupied]. Cargo/FFV are passengers. */
params [["_rows",[]]];
private _indices = [];
{
    if (!(_x param [1,false]) && {!(_x param [2,false])} && {(toLower (_x param [0,""])) in ["driver","gunner","commander","turret"]}) then {_indices pushBack _forEachIndex;};
} forEach _rows;
_indices
