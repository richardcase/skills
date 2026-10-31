# Richard Case's skills

[![skills.sh](https://skills.sh/b/richardcase/skills)](https://skills.sh/richardcase/skills)

Reusable agent skills that work with the [Skills CLI](https://github.com/vercel-labs/skills) and Claude Code.

## Install with the Skills CLI

List the available skills:

```sh
npx skills@latest add richardcase/skills --list
```

Install a specific skill:

```sh
npx skills@latest add richardcase/skills --skill hello-world
```

The installer will prompt for the coding agents and installation scope to use. Pass `--global` to install for the current user or `--agent <agent>` to target an agent non-interactively.

## Install as a Claude Code plugin

Add this repository as a marketplace and install the managed plugin:

```sh
claude plugin marketplace add richardcase/skills
claude plugin install richardcase-skills@richardcase
```

Reload active plugins if Claude Code is already running:

```text
/reload-plugins
```

Plugin skills are namespaced. For example, invoke the starter skill with:

```text
/richardcase-skills:hello-world
```

## Available skills

| Skill | Description |
| --- | --- |
| [`create-pr`](skills/create-pr/SKILL.md) | Commit the current work and open a ready pull request: signed conventional commits, Simplified Technical English descriptions, no agent footers. |
| [`gh-issue-workflow`](skills/gh-issue-workflow/SKILL.md) | Take a GitHub issue from assignment to a merged pull request in a Herdr worktree: grilled plan, Claude and Codex reviews, signed conventional commits, review feedback, retro. |
| [`hello-world`](skills/hello-world/SKILL.md) | A minimal greeting skill that verifies installation and invocation. |

## Add a skill

Create a flat directory at `skills/<skill-name>/` containing a `SKILL.md`:

```markdown
---
name: my-skill
description: What the skill does and when an agent should use it.
---

# My skill

Instructions for the agent.
```

Skill names must be unique kebab-case identifiers and must match their directory names. Supporting files such as scripts, references, and assets may live inside the skill directory.

Install dependencies and validate the complete catalog locally:

```sh
npm ci
npm run check
```

`npm run check` validates skill metadata, confirms that the Skills CLI discovers the catalog, validates the Claude Code plugin, and checks that release versions remain synchronized.

## Evals

The `gh-issue-workflow` skill has an eval suite under `evals/`. Each case is a `prompt.md` with `graders/`, in the `claude plugin eval` layout. The cases drive stub `gh`, `herdr`, and `codex` binaries from `evals/stubs/`, and `claude plugin eval` does not let a case put stubs on PATH, so the suite runs through a local runner that uses `claude -p`. It makes real model calls on your account, so it is local only:

```sh
npm run eval            # all cases
npm run eval:nocodex    # the preflight case with codex hidden
npm run eval:plugin     # the same cases under claude plugin eval (stubs are not on PATH there)
```

The runner scores the regex graders and prints the LLM graders for you to judge. Each case leaves its workspace, reply, and `calls.log` in a temp directory that the output names. Results of `eval:plugin` land in `evals/results/` (ignored by git).

## Release

User-facing skill and plugin changes should include a Changeset:

```sh
npm run changeset
```

Choose the appropriate semantic-version bump and commit the generated Markdown file with the change. After changes reach `main`, the release workflow creates or updates a version pull request. Merging that pull request updates the changelog and both version fields, creates a `richardcase-skills@<version>` tag, and publishes a GitHub Release. Documentation-only maintenance may omit a Changeset.

This repository is metadata-only and is not published to npm.

## License

[Apache License 2.0](LICENSE)
