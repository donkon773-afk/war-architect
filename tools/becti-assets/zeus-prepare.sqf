/* Cache actual loaded patch records, not legacy dependency names which can
   appear in activatedAddons/configSourceAddonList without a CfgPatches class.
   Zeus reads each patch's units array; patches without that array are skipped. */
WA_BECTI_filterCuratorAddons={
    params ["_addons"];
    _addons select {isClass(configFile >> "CfgPatches" >> _x) && {isArray(configFile >> "CfgPatches" >> _x >> "units")}}
};
WA_BECTI_curatorAddons=[("true" configClasses (configFile >> "CfgPatches")) apply {configName _x}] call WA_BECTI_filterCuratorAddons;
activateAddons WA_BECTI_curatorAddons;
