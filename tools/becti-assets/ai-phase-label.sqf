params ["_group"];
switch (_group getVariable ["WA_BECTI_phase",""]) do {
 case "PREPARE":{"Подготовка"};case "ASSEMBLE":{"Сбор"};case "WAIT_SUPPORT":{"Ожидает поддержки"};
 case "ADVANCE":{"Наступление"};case "ASSAULT":{"Атака"};case "COVER":{"Прикрытие"};
 case "WITHDRAW":{"Отход / ремонт"};case "RETURN":{"Возврат"};case "WAIT_ROAD":{"Проверка маршрута"};
 case "CLIMB":{"Набор высоты"};case "CAP":{"Воздушное прикрытие"};case "INTERCEPT":{"Перехват"};
 case "SUPPORT_STANDBY":{"Ожидает цели"};case "WAIT_AA_SUPPRESSION":{"Ожидает подавления ПВО"};
 case "CAS":{"Ударная поддержка"};case "STRIKE":{"Удар по технике"};default {""};
}
