// Пресеты закупки Warlords (меню «Запрос»). Сгенерировано generate.py.
// BFX_RHS_D — пустынный камуфляж (OCP), BFX_RHS_WD — лесной (UCP).
// Если сборщик (tools\wl_build.sqf) сообщил об отсутствующих классах — удалите их отсюда.
class CfgWLRequisitionPresets
{
    class BFX_RHS_D
    {
        class WEST
        {
            class Infantry
            {
                class rhsusf_army_ocp_rifleman { cost = 60; requirements[] = {}; };
                class rhsusf_army_ocp_grenadier { cost = 80; requirements[] = {}; };
                class rhsusf_army_ocp_autorifleman { cost = 100; requirements[] = {}; };
                class rhsusf_army_ocp_machinegunner { cost = 120; requirements[] = {}; };
                class rhsusf_army_ocp_medic { cost = 90; requirements[] = {}; };
                class rhsusf_army_ocp_engineer { cost = 100; requirements[] = {}; };
                class rhsusf_army_ocp_riflemanat { cost = 120; requirements[] = {}; };
                class rhsusf_army_ocp_marksman { cost = 150; requirements[] = {}; };
                class rhsusf_army_ocp_sniper { cost = 250; requirements[] = {}; };
                class rhsusf_army_ocp_javelin { cost = 300; requirements[] = {}; };
                class rhsusf_army_ocp_aa { cost = 300; requirements[] = {}; };
                class rhsusf_army_ocp_teamleader { cost = 100; requirements[] = {}; };
            };
            class Vehicles
            {
                class rhsusf_m1025_d { cost = 150; requirements[] = {}; };
                class rhsusf_m1025_d_m2 { cost = 300; requirements[] = {}; };
                class rhsusf_m1025_d_Mk19 { cost = 400; requirements[] = {}; };
                class rhsusf_m113d_usarmy { cost = 600; requirements[] = {}; };
                class rhsusf_stryker_m1126_m2_d { cost = 900; requirements[] = {}; };
                class RHS_M2A2 { cost = 1500; requirements[] = {}; };
                class RHS_M2A3_BUSKIII { cost = 1800; requirements[] = {}; };
                class RHS_M6 { cost = 2000; requirements[] = {}; };
                class rhsusf_m1a1aimd_usarmy { cost = 3000; requirements[] = {}; };
                class rhsusf_m1a2sep1d_usarmy { cost = 3500; requirements[] = {}; };
                class rhsusf_m1a2sep1tuskiid_usarmy { cost = 4000; requirements[] = {}; };
                class rhsusf_m109d_usarmy { cost = 3500; requirements[] = {}; };
            };
            class Aircraft
            {
                class RHS_MELB_MH6M { cost = 500; requirements[] = {"H"}; };
                class RHS_MELB_AH6M { cost = 1500; requirements[] = {"H"}; };
                class RHS_UH60M_d { cost = 900; requirements[] = {"H"}; };
                class RHS_CH_47F { cost = 1200; requirements[] = {"H"}; };
                class RHS_AH64D { cost = 5000; requirements[] = {"H"}; };
                class RHS_A10 { cost = 6000; requirements[] = {"A"}; };
                class JS_JC_FA18E { cost = 8000; requirements[] = {"A"}; };
                class rhsusf_f22 { cost = 9000; requirements[] = {"A"}; };
            };
            class Naval
            {
                class B_Boat_Transport_01_F { cost = 100; requirements[] = {"W"}; };
                class B_Boat_Armed_01_minigun_F { cost = 600; requirements[] = {"W"}; };
                class rhsusf_mkvsoc { cost = 1500; requirements[] = {"W"}; };
            };
            class Defences
            {
                class RHS_M2StaticMG_D { cost = 200; requirements[] = {}; };
                class RHS_MK19_TriPod_D { cost = 300; requirements[] = {}; };
                class RHS_TOW_TriPod_D { cost = 500; requirements[] = {}; };
                class RHS_Stinger_AA_pod_D { cost = 600; requirements[] = {}; };
                class RHS_M252_D { cost = 800; requirements[] = {}; };
                class RHS_M119_D { cost = 1500; requirements[] = {}; };
            };
        };
        class EAST
        {
            class Infantry
            {
                class rhs_msv_emr_rifleman { cost = 60; requirements[] = {}; };
                class rhs_msv_emr_grenadier { cost = 80; requirements[] = {}; };
                class rhs_msv_emr_machinegunner { cost = 120; requirements[] = {}; };
                class rhs_msv_emr_medic { cost = 90; requirements[] = {}; };
                class rhs_msv_emr_engineer { cost = 100; requirements[] = {}; };
                class rhs_msv_emr_LAT { cost = 120; requirements[] = {}; };
                class rhs_msv_emr_at { cost = 200; requirements[] = {}; };
                class rhs_msv_emr_marksman { cost = 150; requirements[] = {}; };
                class rhs_msv_emr_aa { cost = 300; requirements[] = {}; };
                class rhs_msv_emr_junior_sergeant { cost = 100; requirements[] = {}; };
            };
            class Vehicles
            {
                class rhs_tigr_msv { cost = 200; requirements[] = {}; };
                class rhs_tigr_sts_msv { cost = 350; requirements[] = {}; };
                class rhs_btr80_msv { cost = 700; requirements[] = {}; };
                class rhs_btr80a_msv { cost = 900; requirements[] = {}; };
                class rhs_bmp2_msv { cost = 1300; requirements[] = {}; };
                class rhs_bmp3_msv { cost = 1800; requirements[] = {}; };
                class rhs_zsu234_aa { cost = 2000; requirements[] = {}; };
                class rhs_t72bd_tv { cost = 3000; requirements[] = {}; };
                class rhs_t80u_tv { cost = 3200; requirements[] = {}; };
                class rhs_t90a_tv { cost = 3500; requirements[] = {}; };
                class rhs_2s3_tv { cost = 3500; requirements[] = {}; };
                class rhs_bm21_msv_01 { cost = 3000; requirements[] = {}; };
            };
            class Aircraft
            {
                class RHS_Mi8AMT_vvsc { cost = 900; requirements[] = {"H"}; };
                class RHS_Mi8MTV3_vvsc { cost = 2000; requirements[] = {"H"}; };
                class RHS_Mi24P_vvsc { cost = 4000; requirements[] = {"H"}; };
                class rhs_mi28n_vvsc { cost = 5000; requirements[] = {"H"}; };
                class RHS_Ka52_vvsc { cost = 5500; requirements[] = {"H"}; };
                class RHS_Su25SM_vvsc { cost = 6000; requirements[] = {"A"}; };
                class JS_JC_SU35 { cost = 8000; requirements[] = {"A"}; };
                class RHS_T50_vvs_generic { cost = 9000; requirements[] = {"A"}; };
            };
            class Naval
            {
                class O_Boat_Transport_01_F { cost = 100; requirements[] = {"W"}; };
                class O_Boat_Armed_01_hmg_F { cost = 600; requirements[] = {"W"}; };
            };
            class Defences
            {
                class rhs_KORD_high_MSV { cost = 200; requirements[] = {}; };
                class RHS_AGS30_TriPod_MSV { cost = 300; requirements[] = {}; };
                class rhs_Kornet_9M133_2_msv { cost = 500; requirements[] = {}; };
                class rhs_Igla_AA_pod_msv { cost = 600; requirements[] = {}; };
                class RHS_ZU23_MSV { cost = 500; requirements[] = {}; };
                class rhs_2b14_82mm_msv { cost = 800; requirements[] = {}; };
                class rhs_D30_msv { cost = 1500; requirements[] = {}; };
            };
        };
    };
    class BFX_RHS_WD
    {
        class WEST
        {
            class Infantry
            {
                class rhsusf_army_ucp_rifleman { cost = 60; requirements[] = {}; };
                class rhsusf_army_ucp_grenadier { cost = 80; requirements[] = {}; };
                class rhsusf_army_ucp_autorifleman { cost = 100; requirements[] = {}; };
                class rhsusf_army_ucp_machinegunner { cost = 120; requirements[] = {}; };
                class rhsusf_army_ucp_medic { cost = 90; requirements[] = {}; };
                class rhsusf_army_ucp_engineer { cost = 100; requirements[] = {}; };
                class rhsusf_army_ucp_riflemanat { cost = 120; requirements[] = {}; };
                class rhsusf_army_ucp_marksman { cost = 150; requirements[] = {}; };
                class rhsusf_army_ucp_sniper { cost = 250; requirements[] = {}; };
                class rhsusf_army_ucp_javelin { cost = 300; requirements[] = {}; };
                class rhsusf_army_ucp_aa { cost = 300; requirements[] = {}; };
                class rhsusf_army_ucp_teamleader { cost = 100; requirements[] = {}; };
            };
            class Vehicles
            {
                class rhsusf_m1025_w { cost = 150; requirements[] = {}; };
                class rhsusf_m1025_w_m2 { cost = 300; requirements[] = {}; };
                class rhsusf_m1025_w_mk19 { cost = 400; requirements[] = {}; };
                class rhsusf_m113_usarmy { cost = 600; requirements[] = {}; };
                class rhsusf_stryker_m1126_m2_wd { cost = 900; requirements[] = {}; };
                class RHS_M2A2_wd { cost = 1500; requirements[] = {}; };
                class RHS_M2A3_BUSKIII_wd { cost = 1800; requirements[] = {}; };
                class RHS_M6_wd { cost = 2000; requirements[] = {}; };
                class rhsusf_m1a1aimwd_usarmy { cost = 3000; requirements[] = {}; };
                class rhsusf_m1a2sep1wd_usarmy { cost = 3500; requirements[] = {}; };
                class rhsusf_m1a2sep1tuskiiwd_usarmy { cost = 4000; requirements[] = {}; };
                class rhsusf_m109_usarmy { cost = 3500; requirements[] = {}; };
            };
            class Aircraft
            {
                class RHS_MELB_MH6M { cost = 500; requirements[] = {"H"}; };
                class RHS_MELB_AH6M { cost = 1500; requirements[] = {"H"}; };
                class RHS_UH60M { cost = 900; requirements[] = {"H"}; };
                class RHS_CH_47F { cost = 1200; requirements[] = {"H"}; };
                class RHS_AH64D_wd { cost = 5000; requirements[] = {"H"}; };
                class RHS_A10 { cost = 6000; requirements[] = {"A"}; };
                class JS_JC_FA18E { cost = 8000; requirements[] = {"A"}; };
                class rhsusf_f22 { cost = 9000; requirements[] = {"A"}; };
            };
            class Naval
            {
                class B_Boat_Transport_01_F { cost = 100; requirements[] = {"W"}; };
                class B_Boat_Armed_01_minigun_F { cost = 600; requirements[] = {"W"}; };
                class rhsusf_mkvsoc { cost = 1500; requirements[] = {"W"}; };
            };
            class Defences
            {
                class RHS_M2StaticMG_WD { cost = 200; requirements[] = {}; };
                class RHS_MK19_TriPod_WD { cost = 300; requirements[] = {}; };
                class RHS_TOW_TriPod_WD { cost = 500; requirements[] = {}; };
                class RHS_Stinger_AA_pod_WD { cost = 600; requirements[] = {}; };
                class RHS_M252_WD { cost = 800; requirements[] = {}; };
                class RHS_M119_WD { cost = 1500; requirements[] = {}; };
            };
        };
        class EAST
        {
            class Infantry
            {
                class rhs_msv_emr_rifleman { cost = 60; requirements[] = {}; };
                class rhs_msv_emr_grenadier { cost = 80; requirements[] = {}; };
                class rhs_msv_emr_machinegunner { cost = 120; requirements[] = {}; };
                class rhs_msv_emr_medic { cost = 90; requirements[] = {}; };
                class rhs_msv_emr_engineer { cost = 100; requirements[] = {}; };
                class rhs_msv_emr_LAT { cost = 120; requirements[] = {}; };
                class rhs_msv_emr_at { cost = 200; requirements[] = {}; };
                class rhs_msv_emr_marksman { cost = 150; requirements[] = {}; };
                class rhs_msv_emr_aa { cost = 300; requirements[] = {}; };
                class rhs_msv_emr_junior_sergeant { cost = 100; requirements[] = {}; };
            };
            class Vehicles
            {
                class rhs_tigr_msv { cost = 200; requirements[] = {}; };
                class rhs_tigr_sts_msv { cost = 350; requirements[] = {}; };
                class rhs_btr80_msv { cost = 700; requirements[] = {}; };
                class rhs_btr80a_msv { cost = 900; requirements[] = {}; };
                class rhs_bmp2_msv { cost = 1300; requirements[] = {}; };
                class rhs_bmp3_msv { cost = 1800; requirements[] = {}; };
                class rhs_zsu234_aa { cost = 2000; requirements[] = {}; };
                class rhs_t72bd_tv { cost = 3000; requirements[] = {}; };
                class rhs_t80u_tv { cost = 3200; requirements[] = {}; };
                class rhs_t90a_tv { cost = 3500; requirements[] = {}; };
                class rhs_2s3_tv { cost = 3500; requirements[] = {}; };
                class rhs_bm21_msv_01 { cost = 3000; requirements[] = {}; };
            };
            class Aircraft
            {
                class RHS_Mi8AMT_vvsc { cost = 900; requirements[] = {"H"}; };
                class RHS_Mi8MTV3_vvsc { cost = 2000; requirements[] = {"H"}; };
                class RHS_Mi24P_vvsc { cost = 4000; requirements[] = {"H"}; };
                class rhs_mi28n_vvsc { cost = 5000; requirements[] = {"H"}; };
                class RHS_Ka52_vvsc { cost = 5500; requirements[] = {"H"}; };
                class RHS_Su25SM_vvsc { cost = 6000; requirements[] = {"A"}; };
                class JS_JC_SU35 { cost = 8000; requirements[] = {"A"}; };
                class RHS_T50_vvs_generic { cost = 9000; requirements[] = {"A"}; };
            };
            class Naval
            {
                class O_Boat_Transport_01_F { cost = 100; requirements[] = {"W"}; };
                class O_Boat_Armed_01_hmg_F { cost = 600; requirements[] = {"W"}; };
            };
            class Defences
            {
                class rhs_KORD_high_MSV { cost = 200; requirements[] = {}; };
                class RHS_AGS30_TriPod_MSV { cost = 300; requirements[] = {}; };
                class rhs_Kornet_9M133_2_msv { cost = 500; requirements[] = {}; };
                class rhs_Igla_AA_pod_msv { cost = 600; requirements[] = {}; };
                class RHS_ZU23_MSV { cost = 500; requirements[] = {}; };
                class rhs_2b14_82mm_msv { cost = 800; requirements[] = {}; };
                class rhs_D30_msv { cost = 1500; requirements[] = {}; };
            };
        };
    };
};
