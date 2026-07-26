import { readFile, writeFile } from "node:fs/promises";

const packageManifest = JSON.parse(await readFile("package.json", "utf8"));
const pluginPath = ".claude-plugin/plugin.json";
const pluginManifest = JSON.parse(await readFile(pluginPath, "utf8"));

pluginManifest.version = packageManifest.version;

await writeFile(pluginPath, `${JSON.stringify(pluginManifest, null, 2)}\n`);
console.log(`Updated Claude plugin version to ${packageManifest.version}.`);
