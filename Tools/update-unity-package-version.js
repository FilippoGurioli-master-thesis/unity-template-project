const fs = require("fs");
const path = require("path");
const version = process.argv[2];
const packageJsonPath = path.join(__dirname, "..", "__NAMESPACE__", "package.json");
const json = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
json.version = version;
fs.writeFileSync(packageJsonPath, JSON.stringify(json, null, 2) + "\n");
console.log(`Updated Unity package.json to version ${version}`);
