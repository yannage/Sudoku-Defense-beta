const fs = require('node:fs');
const path = require('node:path');

// Packaged and development builds previously used these two name variants.
// Prefer actual saved progress over an empty profile created by another build.
function legacyProfilePath(appData) {
  const candidates = ['Gridfall', 'gridfall'].map(name => path.join(appData, name));
  const profile = candidates.find(folder => fs.existsSync(path.join(folder, 'game-storage.json')))
    || candidates.find(folder => fs.existsSync(folder))
    || candidates[0];
  fs.mkdirSync(profile, { recursive: true });
  return profile;
}

module.exports = { legacyProfilePath };
