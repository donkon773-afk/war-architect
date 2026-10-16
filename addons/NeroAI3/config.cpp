class CfgPatches {
    class NeroWL {
        name = "NeroAI Warlords Dual LLM [candidate]";
        author = "NeroAI project";
        requiredVersion = 2.18;
        requiredAddons[] = {"A3_Functions_F", "A3_Functions_F_Warlords"};
        units[] = {};
        weapons[] = {};
    };
};

#include "functions\CfgFunctions.hpp"

class CfgRemoteExec {
    class Functions {
        mode = 1;
        jip = 0;
        class NeroAI_fnc_receiveClientCommand { allowedTargets = 2; };
        class NeroAI_fnc_restorePlayerAuthority { allowedTargets = 2; };
        class NeroAI_fnc_restoreGroupLeaderLocal { allowedTargets = 0; };
        class NeroAI_fnc_restoreHighCommandLocal { allowedTargets = 0; };
        class NeroAI_fnc_clientNotice { allowedTargets = 1; };
        class NeroAI_fnc_clientSpeech { allowedTargets = 1; };
        class BIS_fnc_debugConsoleExec { allowedTargets = 0; };
    };
};
