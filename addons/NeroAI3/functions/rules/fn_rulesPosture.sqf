/* 11.10 Tactical AI without LLM — PURE side posture.
 *
 *   [aggression, incomeRatio, attrition, threatenedBase] call NeroAI_fnc_rulesPosture -> 0|1|2
 *
 * aggression     lobby NeroWL_Aggression: 0 cautious, 1 balanced, 2 offensive
 * incomeRatio    own sector income / enemy sector income (public map state)
 * attrition      own alive AI / own peak AI (own losses, no enemy omniscience)
 * threatenedBase the enemy has voted our HQ — never offensive while it stands
 * Result: 0 DEFENSIVE, 1 BALANCED, 2 OFFENSIVE. */
params [["_aggression", 1, [0]], ["_incomeRatio", 1, [0]], ["_attrition", 1, [0]], ["_threatenedBase", false, [false]]];
private _score = ((round _aggression) max 0 min 2) - 1;
if (_incomeRatio >= 1.4) then {_score = _score + 1;};
if (_incomeRatio <= 0.7) then {_score = _score - 1;};
if (_attrition < 0.5) then {_score = _score - 1;};
if (_attrition >= 0.85 && {_incomeRatio >= 1.2}) then {_score = _score + 1;};
private _posture = if (_score >= 1) then {2} else {if (_score <= -1) then {0} else {1}};
if (_threatenedBase) then {_posture = _posture min 1;};
_posture
