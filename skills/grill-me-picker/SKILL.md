---
name: grill-me-picker
description: A relentless interview to sharpen a plan or design, with each round of questions asked through the AskUserQuestion picker when it is available.
disable-model-invocation: true
---

<!--
Derived from mattpocock/skills `skills/productivity/grilling` at
4588b32ecab9ecc9fc8cc6b6c5e7d675b6004b0d (MIT, see LICENSE in this
directory). The method is the same. The change is how a round is
presented: the AskUserQuestion picker when the harness has it,
markdown otherwise. Compare with upstream for method changes.
-->

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round, giving your recommended answer for each. Then wait for the user's answers before the next round.

## Asking a round

### With the AskUserQuestion tool (Claude Code)

If the `AskUserQuestion` tool is available, use it for every question that has a small set of distinct answers:

- One question per entry, up to 4 per call. If the frontier holds more than 4 such questions, make several calls back to back in the same round; all are still part of one round.
- `question`: the full question, standing on its own. The user may see only the dialog, so include the context they need to decide (a short sentence on what you found or why it matters), not a reference to text above.
- `header`: a chip of 12 characters or less naming the decision.
- `options`: 2–4 mutually exclusive choices. Put your recommended answer **first** and end its label with " (Recommended)". Use `description` for the trade-off of each choice. Don't add an "Other" option; the picker provides it, and that is where the user gives a free-form answer.
- Use `preview` when options are concrete artifacts worth comparing side by side (snippets, config, layouts).
- `multiSelect: true` only when the choices genuinely combine.

Some questions don't fit a picker: open-ended ones ("what are the failure modes you care about?"), ones that need several paragraphs of setup, or ones where any short option list would be misleading. Ask those as markdown in a message (format below), together with the picker calls for the rest of the round.

### Without the tool (or for open-ended questions)

Number each question and give your recommended answer:

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

## Moving the frontier

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.
