import { readFile } from "node:fs/promises";
import process from "node:process";

const packageManifest = JSON.parse(await readFile("package.json", "utf8"));
const pluginManifest = JSON.parse(
  await readFile(".claude-plugin/plugin.json", "utf8"),
);

if (packageManifest.version !== pluginManifest.version) {
  console.error(
    `Version mismatch: package.json is ${packageManifest.version}, plugin.json is ${pluginManifest.version}.`,
  );
  process.exit(1);
}

console.log(`Release versions match at ${packageManifest.version}.`);
