"use strict";

// Confirmed by Posadkovo's live RPT: its placed objects reference
// rhsterracore models even though the map's CfgPatches omits that provider.
const missingDeclaredPatches = {
  m_36tuu484111s99: ["rhs_structures_data"]
};

function requiredPaths(world, mods) {
  return (missingDeclaredPatches[world] || []).map(patch => {
    const provider = mods.find(mod => mod.patches.some(name => name.toLowerCase() === patch));
    if (!provider) throw new Error(`Для карты ${world} не найден установленный мод с ${patch}.`);
    return provider.path;
  });
}

module.exports = { requiredPaths };
