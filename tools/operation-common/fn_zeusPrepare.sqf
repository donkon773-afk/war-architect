/* preInit: activate loaded addon classes before curator modules are created. */
activateAddons (("true" configClasses (configFile >> "CfgPatches")) apply {configName _x});
