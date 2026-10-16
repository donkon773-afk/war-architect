// Verified against the installed RHS troop configs, not a vanilla fallback.
class CfgWLRequisitionPresets {
    class NeroWL_RHSStart {
        class WEST {
            class Infantry {
                class rhsusf_army_ocp_rifleman {cost=60; requirements[]={};};
                class rhsusf_army_ocp_grenadier {cost=80; requirements[]={};};
                class rhsusf_army_ocp_autorifleman {cost=100; requirements[]={};};
                class rhsusf_army_ocp_medic {cost=90; requirements[]={};};
            };
            class Vehicles {}; class Aircraft {}; class Defences {}; class Naval {};
        };
        class EAST {
            class Infantry {
                class rhs_msv_emr_rifleman {cost=60; requirements[]={};};
                class rhs_msv_emr_grenadier {cost=80; requirements[]={};};
                class rhs_msv_emr_machinegunner {cost=100; requirements[]={};};
                class rhs_msv_emr_medic {cost=90; requirements[]={};};
            };
            class Vehicles {}; class Aircraft {}; class Defences {}; class Naval {};
        };
    };
};
