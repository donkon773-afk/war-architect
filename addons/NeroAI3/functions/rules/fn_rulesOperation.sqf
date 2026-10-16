/* PURE. One operation stage, no elapsed-time shortcut to an assault.
 * [ready infantry groups, staged infantry groups, required, known defenders,
 *  fresh intel, elapsed gathering, capture hold, AT needed, AT ready] */
params [["_ready",0,[0]],["_staged",0,[0]],["_required",1,[0]],
    ["_known",0,[0]],["_fresh",false,[false]],["_elapsed",0,[0]],
    ["_captureHold",false,[false]],["_needAT",false,[false]],["_readyAT",0,[0]],["_stagedStrength",-1,[0]]];
if (_captureHold) exitWith {["CONSOLIDATE","закрепление захваченного сектора"]};
if (_ready <= 0) exitWith {["REINFORCE","нет боеспособной штурмовой группы"]};
if (_needAT && {_readyAT <= 0}) exitWith {["PREPARE","нужна противотанковая поддержка"]};
if (_staged < (_required max 1)) exitWith {
    if (_elapsed >= 120) then {["REASSESS","пересмотр сбора: партнёры не готовы"]} else {["PREPARE","сбор штурмовых групп"]}
};
if (_stagedStrength >= 0 && {_known > (_stagedStrength * 1.25)}) exitWith {["REINFORCE","известный противник превосходит собранную пехоту"]};
if (!_fresh && {_known <= 0}) exitWith {["RECON","неизвестная обстановка у цели"]};
["ASSAULT","готовые группы собраны"]
