/* Same resistance coefficients as installed ACE gforces. Pure helper. */
params ["_unitCoef","_suitCoef"];
5/(_unitCoef max .001)+5/(_suitCoef max .001)-5
