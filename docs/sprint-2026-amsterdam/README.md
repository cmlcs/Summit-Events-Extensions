# Amsterdam Community Sprint — AI Context Pack

**Dates:** 19–20 October 2026  
**Project:** [Summit Events App](https://github.com/SFDO-Community/Summit-Events-App)  
**Focus:** Targeted invitations using Salesforce Campaigns and Campaign Members

## Purpose

These six Markdown files give participants using different AI assistants a shared understanding of the Sprint. They are **planning context**, not a substitute for inspecting the current source code. The repository and its current branch are authoritative for implementation details; the Sprint board is authoritative for work status.

## Quick start (5–10 minutes)

1. Download this folder and open `SPRINT-GOALS.md`, `SUMMIT-EVENTS.md`, and `USER-STORIES.md`.
2. Add all six files to a ChatGPT Project, Claude Project, or another AI tool that supports file uploads. Alternatively, paste the relevant files into a conversation.
3. For a coding assistant, open a local clone of the [Summit Events App](https://github.com/SFDO-Community/Summit-Events-App) in your IDE and copy `AGENTS.md` into the workspace **only if appropriate for your tool and team workflow**. Avoid committing it to the upstream project without agreement.
4. Ask your assistant: **“Read these files. Summarize the Sprint objective, separate existing functionality from proposed functionality, and list the uncertainties to verify before implementing US-03.”**
5. Choose a user story and confirm its owner, scope, dependencies, and acceptance criteria with the team before changing code.

## File guide

| File | What it contains |
| --- | --- |
| `README.md` | Onboarding and how to use this pack |
| `SPRINT-GOALS.md` | Annual gala scenario, scope, outcomes, and working tracks |
| `SUMMIT-EVENTS.md` | Source-grounded application overview and technical discovery checklist |
| `USER-STORIES.md` | Proposed epic and seven user stories with acceptance criteria |
| `AGENTS.md` | Portable instructions for AI assistants |
| `SPRINT-DECISIONS.md` | Shared architectural decisions and open questions |

## How to work with AI

- Always ask the assistant to distinguish **verified facts**, **requirements**, **proposals**, and **unknowns**.
- Give it the relevant user story and actual code files before requesting an implementation.
- Review generated code, test cases, documentation, and security assumptions as a human team.
- Never paste production data, secrets, access tokens, or personally identifiable donor information into an AI tool.
- Record accepted decisions in `SPRINT-DECISIONS.md` and announce important changes in the Sprint's shared communication channel.

## Source material

- [Summit Events App source](https://github.com/SFDO-Community/Summit-Events-App)
- [Original invitation-processing enhancement request](https://trailhead.salesforce.com/trailblazer-community/feed/0D5KX00000pNKtJ0AW)
- Provided reference: `Enhancement-Request-Invitation-processing.txt`
- Provided reference: `Previous-Sprint-Plan.txt`
- Provided reference: `Virtual Sprint KBYG Deck - August 2026.pdf` (especially pages 12 and 41)

**Status:** Initial Sprint context draft. Story IDs and scope are proposed organizational labels; confirm against the actual Sprint board.
