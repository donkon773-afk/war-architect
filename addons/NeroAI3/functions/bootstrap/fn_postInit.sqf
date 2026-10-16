[] call NeroAI_fnc_extendWarlordsShop;
[] call NeroAI_fnc_warlordsMissionSetup;
if (isServer) then {
    [] spawn NeroAI_fnc_wlFrontlineWatch;
    [] call NeroAI_fnc_initServer;
};
if (hasInterface) then {
    [] call NeroAI_fnc_initClient;
};
