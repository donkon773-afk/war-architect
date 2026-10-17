class WarArchitectBectiHub {
 idd=88200;movingEnable=0;enableSimulation=1;
 onLoad="['INIT'] spawn NeroOP_fnc_bectiHub;";
 class controlsBackground {
  class Background:NeroOPShopText {x="safeZoneX+.23*safeZoneW";y="safeZoneY+.17*safeZoneH";w=".54*safeZoneW";h=".68*safeZoneH";colorBackground[]={.035,.045,.03,.98};};
 };
 class controls {
  class Title:NeroOPShopText {x="safeZoneX+.25*safeZoneW";y="safeZoneY+.19*safeZoneH";w=".5*safeZoneW";h=".05*safeZoneH";text="WAR ARCHITECT · SECTOR COMMAND";sizeEx=".03*safeZoneH";};
  class State:NeroOPShopInfo {idc=88201;x="safeZoneX+.25*safeZoneW";y="safeZoneY+.25*safeZoneH";w=".5*safeZoneW";h=".09*safeZoneH";};
  class Arsenal:NeroOPShopButton {x="safeZoneX+.25*safeZoneW";y="safeZoneY+.36*safeZoneH";w=".24*safeZoneW";h=".055*safeZoneH";text="Арсенал / заказ";tooltip="Пехота, техника, ПВО и снаряжение из сетапа стороны. Заказ через корзину.";onButtonClick="['SHOP'] spawn NeroOP_fnc_bectiHub;";};
  class Command:NeroOPShopButton {x="safeZoneX+.51*safeZoneW";y="safeZoneY+.36*safeZoneH";w=".24*safeZoneW";h=".055*safeZoneH";text="Принять командование";tooltip="Назначение на своей базе. Командование другого игрока не перехватывается.";onButtonClick="closeDialog 0;[] spawn WA_BECTI_takeCommand;";};
  class Build:NeroOPShopButton {x="safeZoneX+.25*safeZoneW";y="safeZoneY+.43*safeZoneH";w=".24*safeZoneW";h=".055*safeZoneH";text="Строительство базы";onButtonClick="['BUILD'] spawn NeroOP_fnc_bectiHub;";};
  class Teams:NeroOPShopButton {x="safeZoneX+.51*safeZoneW";y="safeZoneY+.43*safeZoneH";w=".24*safeZoneW";h=".055*safeZoneH";text="Отряды / автономность";tooltip="Самостоятельные экипажи видны в списке отрядов. Автономность и приказы сохраняют правила BECTI.";onButtonClick="['TEAMS'] spawn NeroOP_fnc_bectiHub;";};
  class Map:NeroOPShopButton {x="safeZoneX+.25*safeZoneW";y="safeZoneY+.5*safeZoneH";w=".24*safeZoneW";h=".055*safeZoneH";text="Карта / задачи отрядам";onButtonClick="['MAP'] spawn NeroOP_fnc_bectiHub;";};
  class Upgrades:NeroOPShopButton {x="safeZoneX+.51*safeZoneW";y="safeZoneY+.5*safeZoneH";w=".24*safeZoneW";h=".055*safeZoneH";text="Развитие / улучшения";onButtonClick="['UPGRADES'] spawn NeroOP_fnc_bectiHub;";};
  class Service:NeroOPShopButton {x="safeZoneX+.25*safeZoneW";y="safeZoneY+.57*safeZoneH";w=".24*safeZoneW";h=".055*safeZoneH";text="Обслуживание техники";onButtonClick="['SERVICE'] spawn NeroOP_fnc_bectiHub;";};
  class Workers:NeroOPShopButton {x="safeZoneX+.51*safeZoneW";y="safeZoneY+.57*safeZoneH";w=".24*safeZoneW";h=".055*safeZoneH";text="Рабочие / стройка";onButtonClick="['WORKERS'] spawn NeroOP_fnc_bectiHub;";};
  class Funds:NeroOPShopButton {x="safeZoneX+.25*safeZoneW";y="safeZoneY+.64*safeZoneH";w=".24*safeZoneW";h=".055*safeZoneH";text="Бюджет / передача денег";onButtonClick="['FUNDS'] spawn NeroOP_fnc_bectiHub;";};
  class Options:NeroOPShopButton {x="safeZoneX+.51*safeZoneW";y="safeZoneY+.64*safeZoneH";w=".24*safeZoneW";h=".055*safeZoneH";text="Параметры BECTI";onButtonClick="['OPTIONS'] spawn NeroOP_fnc_bectiHub;";};
  class Help:NeroOPShopText {idc=88202;style=16;sizeEx=".018*safeZoneH";x="safeZoneX+.25*safeZoneW";y="safeZoneY+.71*safeZoneH";w=".5*safeZoneW";h=".06*safeZoneH";text="Сначала примите командование, затем постройте казарму и центр управления. Арсенал работает на своей базе и в захваченных секторах.";};
  class Close:NeroOPShopButton {x="safeZoneX+.61*safeZoneW";y="safeZoneY+.79*safeZoneH";w=".14*safeZoneW";h=".04*safeZoneH";text="Закрыть";onButtonClick="closeDialog 0;";};
  class Zeus:NeroOPShopButton {x="safeZoneX+.25*safeZoneW";y="safeZoneY+.79*safeZoneH";w=".24*safeZoneW";h=".04*safeZoneH";text="Zeus · хост / админ";tooltip="Сервер проверяет права администратора. Должность командира стороны не требуется.";onButtonClick="['ZEUS'] spawn NeroOP_fnc_bectiHub;";};
 };
};
