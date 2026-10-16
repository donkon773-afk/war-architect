/* 11.10 Tactical AI without LLM — PURE sector utility for the side strategist.
 * No engine state is read here (SQF-VM tests execute this file as is).
 *
 *   [value, distM, enemyKnown, ownerKind, isEnemyBase, links, frontLinks,
 *    posture, incumbent, attrition] call NeroAI_fnc_rulesScoreSector -> score
 *
 * value      BIS_WL_value of the sector (income it brings)
 * distM      distance from the side's force centre to the sector
 * enemyKnown hostiles this side has seen near the sector (shared intel memory)
 * ownerKind  0 = neutral garrison (GREEN), 1 = enemy army
 * isEnemyBase the enemy HQ: winning move, but only for a strong, offensive side
 * links      connections of the sector (more options after capture)
 * frontLinks connections that touch enemy-army sectors (pressure on the enemy)
 * posture    0 defensive, 1 balanced, 2 offensive
 * incumbent  true = the side's current choice (hysteresis against flip-flopping)
 * attrition  own alive AI / own peak AI, 0..1 */
params [
    ["_value", 10, [0]], ["_distM", 0, [0]], ["_enemyKnown", 0, [0]], ["_ownerKind", 0, [0]],
    ["_isEnemyBase", false, [false]], ["_links", 0, [0]], ["_frontLinks", 0, [0]],
    ["_posture", 1, [0]], ["_incumbent", false, [false]], ["_attrition", 1, [0]]
];
_posture = (round _posture) max 0 min 2;
_value = (_value max 0) min 100;
_distM = _distM max 0;
_enemyKnown = _enemyKnown max 0;

private _score = 10 + _value * 2;
/* Distance costs time; a cautious side stays close to its own lines. */
_score = _score - (_distM / 1000) * ([12, 8, 5] # _posture);
/* Known defenders cost men; an offensive side accepts more of them. */
_score = _score - _enemyKnown * ([5, 4, 2.5] # _posture);
/* Taking a sector from the enemy army cuts its income twice over; a neutral
 * garrison is the cheaper, safer gain when the side is cautious. */
if (_ownerKind isEqualTo 1) then {
    _score = _score + ([5, 15, 22] # _posture);
} else {
    _score = _score + ([10, 6, 3] # _posture);
};
_score = _score + 3 * (_links min 6) + ([1, 3, 5] # _posture) * (_frontLinks min 4);
if (_isEnemyBase) then {
    /* The enemy HQ ends the match — only with an offensive, intact army.
     * Otherwise the native "always vote the HQ when reachable" suicide is avoided. */
    _score = if (_posture isEqualTo 2 && {_attrition >= 0.6}) then {_score + 45} else {_score - 70};
};
if (_incumbent) then {_score = _score + 12;};
round _score
