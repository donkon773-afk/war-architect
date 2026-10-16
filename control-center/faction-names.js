"use strict";
/* 8.10: readable side/faction names for every faction list of the panel.
 * The catalog only carries config class names (rhsgref_faction_cdf_ng, b_afougf…);
 * the selects show «Национальная гвардия Чернаруси (RHS GREF)» and keep the
 * class as the stored value. Unknown factions get a generated fallback. */
const NAMES = {
  BLU_F: "НАТО (Arma 3)", BLU_G_F: "Партизаны FIA (Arma 3, синие)", IND_F: "ААФ — армия Альтиса (Arma 3)", IND_G_F: "Партизаны FIA (Arma 3, зелёные)", OPF_F: "CSAT — Иран (Arma 3)", OPF_G_F: "Партизаны FIA (Arma 3, красные)",
  CUP_B_AFU: "Вооружённые силы Украины (CUP)", CUP_B_CDF: "Силы обороны Чернаруси (CUP)", CUP_B_CZ: "Армия Чехии (CUP)", CUP_B_GB: "Армия Великобритании (CUP)", CUP_B_GER: "Бундесвер — Германия (CUP)", CUP_B_HIL: "Хорватская армия — Хорватия (CUP)", CUP_B_USMC: "Морская пехота США (CUP)", CUP_B_US_Army: "Армия США (CUP)",
  CUP_I_NAPA: "НАПА — повстанцы Чернаруси (CUP)", CUP_I_PMC_ION: "ЧВК ION (CUP)", CUP_I_RACS: "Армия Саганы — RACS (CUP)", CUP_I_TK_GUE: "Такистанские партизаны (CUP)", CUP_I_UN: "Миротворцы ООН (CUP)",
  CUP_O_ChDKZ: "ChDKZ — коммунисты Чернаруси (CUP)", CUP_O_RU: "Вооружённые силы России (CUP)", CUP_O_SLA: "Армия Сахрани — SLA (CUP)", CUP_O_TK: "Армия Такистана (CUP)", CUP_O_TK_MILITIA: "Такистанское ополчение (CUP)",
  TMT_TR_Army: "Сухопутные войска Турции (TMT)", TMT_TR_DZKK: "Морская пехота Турции (TMT)",
  b_afougf: "ВСУ — современная форма (UFP)", b_afougf_oldarmy: "ВСУ — старая форма (UFP)", b_afougf_unbalkan: "ВСУ — миротворцы ООН, Балканы (UFP)", b_afougf_undesert: "ВСУ — миротворцы ООН, пустыня (UFP)", b_afougf_winter: "ВСУ — зимняя форма (UFP)", b_afougf_yt: "ВСУ — территориальная оборона (UFP)", b_afousf: "ССО Украины (UFP)", b_ngu: "Национальная гвардия Украины (UFP)", b_uapolice: "Национальная полиция Украины (UFP)",
  rhs_faction_msv: "Мотострелки ВС РФ (RHS)", rhs_faction_rva: "РВСН / артиллерия РФ (RHS)", rhs_faction_vdv: "ВДВ России (RHS)", rhs_faction_vdv_des: "ВДВ России — пустыня (RHS)", rhs_faction_vmf: "Морская пехота ВМФ России (RHS)", rhs_faction_vv: "Росгвардия / ВВ (RHS)", rhs_faction_vvs: "ВКС России — авиация (RHS)",
  rhs_faction_socom: "Спецназ США — SOCOM (RHS)", rhs_faction_usaf: "ВВС США (RHS)", rhs_faction_usarmy_d: "Армия США — пустыня (RHS)", rhs_faction_usarmy_wd: "Армия США — лес (RHS)", rhs_faction_usmc_d: "Морская пехота США — пустыня (RHS)", rhs_faction_usmc_wd: "Морская пехота США — лес (RHS)", rhs_faction_usn: "ВМС США (RHS)",
  rhsgref_faction_cdf_air: "ВВС Чернаруси (RHS GREF, зелёные)", rhsgref_faction_cdf_air_b: "ВВС Чернаруси (RHS GREF, синие)", rhsgref_faction_cdf_ground: "Армия Чернаруси (RHS GREF, зелёные)", rhsgref_faction_cdf_ground_b: "Армия Чернаруси (RHS GREF, синие)", rhsgref_faction_cdf_ng: "Национальная гвардия Чернаруси (RHS GREF, зелёные)", rhsgref_faction_cdf_ng_b: "Национальная гвардия Чернаруси (RHS GREF, синие)",
  rhsgref_faction_chdkz: "ChDKZ — коммунисты Чернаруси (RHS GREF, красные)", rhsgref_faction_chdkz_g: "ChDKZ — коммунисты Чернаруси (RHS GREF, зелёные)", rhsgref_faction_hidf: "Силы обороны Хорайзона — HIDF (RHS GREF)", rhsgref_faction_nationalist: "Националисты (RHS GREF)", rhsgref_faction_tla: "Армия освобождения Такистана (RHS GREF, красные)", rhsgref_faction_tla_g: "Армия освобождения Такистана (RHS GREF, зелёные)", rhsgref_faction_un: "Миротворцы ООН (RHS GREF)",
  rhssaf_faction_airforce: "ВВС Сербии (RHS SAF, зелёные)", rhssaf_faction_airforce_opfor: "ВВС Сербии (RHS SAF, красные)", rhssaf_faction_army: "Армия Сербии (RHS SAF, зелёные)", rhssaf_faction_army_opfor: "Армия Сербии (RHS SAF, красные)", rhssaf_faction_un: "Сербские миротворцы ООН (RHS SAF)"
};
const SIDE = ["красные", "синие", "зелёные"];
function fallback(id) {
  const raw = String(id || "");
  const mod = /^rhsgref_/i.test(raw) ? "RHS GREF" : /^rhssaf_/i.test(raw) ? "RHS SAF" : /^rhs_/i.test(raw) ? "RHS" : /^cup_/i.test(raw) ? "CUP" : /^uk3cb_/i.test(raw) ? "3CB" : /^tmt_/i.test(raw) ? "TMT" : "";
  const body = raw.replace(/^(?:rhsgref_|rhssaf_|rhs_|cup_|uk3cb_|tmt_)/i, "").replace(/^faction_/i, "").replace(/^[bio]_/i, "").replace(/_/g, " ").trim();
  return (body ? body.charAt(0).toUpperCase() + body.slice(1) : raw) + (mod ? ` (${mod})` : "");
}
function factionLabel(id) { return NAMES[id] || fallback(id); }
function labels(factions) { return Object.fromEntries((factions || []).map(f => [f, factionLabel(f)])); }
module.exports = { factionLabel, labels, NAMES, SIDE };
