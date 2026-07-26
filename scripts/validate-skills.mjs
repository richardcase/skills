import { readFile, readdir } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { parse } from "yaml";

const skillsDirectory = path.resolve("skills");
const kebabCase = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const entries = await readdir(skillsDirectory, { withFileTypes: true });
const skillDirectories = entries
  .filter((entry) => entry.isDirectory() && !entry.name.startsWith("."))
  .sort((left, right) => left.name.localeCompare(right.name));

if (skillDirectories.length === 0) {
  fail("No skills were found in skills/.");
}

const names = new Set();

for (const directory of skillDirectories) {
  const skillPath = path.join(skillsDirectory, directory.name, "SKILL.md");
  let source;

  try {
    source = await readFile(skillPath, "utf8");
  } catch {
    fail(`Missing skills/${directory.name}/SKILL.md.`);
  }

  const frontmatter = readFrontmatter(source, directory.name);

  if (!kebabCase.test(directory.name)) {
    fail(`Skill directory "${directory.name}" must be kebab-case.`);
  }

  if (frontmatter.name !== directory.name) {
    fail(
      `Skill "${directory.name}" must declare name: ${directory.name}; found ${JSON.stringify(frontmatter.name)}.`,
    );
  }

  if (names.has(frontmatter.name)) {
    fail(`Duplicate skill name "${frontmatter.name}".`);
  }

  if (
    typeof frontmatter.description !== "string" ||
    frontmatter.description.trim().length === 0
  ) {
    fail(`Skill "${directory.name}" must have a non-empty description.`);
  }

  names.add(frontmatter.name);
}

console.log(`Validated ${names.size} skill${names.size === 1 ? "" : "s"}.`);

function readFrontmatter(source, skillName) {
  const match = source.match(/^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/);

  if (!match) {
    fail(`Skill "${skillName}" must begin with YAML frontmatter.`);
  }

  let frontmatter;

  try {
    frontmatter = parse(match[1]);
  } catch (error) {
    fail(`Skill "${skillName}" has invalid YAML: ${error.message}`);
  }

  if (!frontmatter || typeof frontmatter !== "object" || Array.isArray(frontmatter)) {
    fail(`Skill "${skillName}" frontmatter must be a YAML mapping.`);
  }

  return frontmatter;
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
