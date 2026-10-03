---
name: grill-me
description: Relentlessly interview the user to sharpen a plan or design. Use on every Plan-mode turn and whenever asked to grill or stress-test an idea.
---

Interview the user relentlessly until you reach a shared understanding. Map the work as a **design tree**: every decision branches into the decisions that depend on it.

## Run the interview in rounds

The **frontier** is every decision whose prerequisites are settled. Ask the whole frontier in one round; defer questions that depend on answers in that round. Number every question, offer distinct options, and recommend an answer with a brief reason.

Use this format:

```text
❓ **Q1 — <question title>**: <question and options>

➡️ **Recommendation:** <recommended answer and why>

---

❓ **Q2 — <question title>**: <question and options>

➡️ **Recommendation:** <recommended answer and why>
```

Each answer reshapes the decision tree. Recompute the frontier and ask the next round. Keep asking until every branch has been visited and no decision remains silently assumed. Then summarize the shared understanding and ask the user to confirm it. Do not act on the plan before that confirmation.

## Investigate facts; ask about decisions

Find environmental and technical facts yourself with available tools. Delegate fact-finding to a sub-agent when the harness provides one; otherwise investigate directly. Never ask the user for facts that can be checked. An unresolved fact is a prerequisite: investigate it without blocking questions whose prerequisites are already settled.

The user owns decisions. Ask them about tradeoffs, priorities, and preferences, and include your recommendation for each open decision.
