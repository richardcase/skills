import { spawnSync } from "node:child_process";
import process from "node:process";

const executable = process.platform === "win32" ? "skills.cmd" : "skills";
const result = spawnSync(executable, ["add", ".", "--list"], {
  encoding: "utf8",
  env: {
    ...process.env,
    CI: "1",
    DISABLE_TELEMETRY: "1",
    NO_COLOR: "1",
  },
});

if (result.status !== 0) {
  process.stderr.write(result.stderr || result.stdout);
  process.exit(result.status ?? 1);
}

const output = `${result.stdout}\n${result.stderr}`;

if (!output.includes("hello-world")) {
  console.error("The Skills CLI did not discover hello-world.");
  process.stderr.write(output);
  process.exit(1);
}

console.log("The Skills CLI discovered hello-world.");
