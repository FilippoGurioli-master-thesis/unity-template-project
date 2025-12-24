const fs = require("fs");
const path = require("path");
const isTemplate = fs.existsSync(path.join(__dirname, ".template"));
console.log(`Semantic-release running in ${isTemplate ? "TEMPLATE" : "PACKAGE"} mode`);
const config = require("semantic-release-preconfigured-conventional-commits");
// TEMPLATE MODE
if (isTemplate) {
  config.plugins.push(
    ["@semantic-release/npm", { npmPublish: false }],
    "@semantic-release/github",
    "@semantic-release/git"
  );
  module.exports = config;
  return;
}
// PACKAGE MODE
config.plugins.push(
  ["@semantic-release/exec", {
    prepareCmd: "node Tools/update-unity-package-version.js ${nextRelease.version}"
  }],
  ["@semantic-release/changelog", {
    changelogFile: "__NAMESPACE__/CHANGELOG.md"
  }],
  "@semantic-release/github",
  ["@semantic-release/git", {
    assets: [
      "__NAMESPACE__/package.json",
      "__NAMESPACE__/CHANGELOG.md"
    ],
    message: "chore(release): ${nextRelease.version}\n\n${nextRelease.notes}"
  }]
);
module.exports = config;
