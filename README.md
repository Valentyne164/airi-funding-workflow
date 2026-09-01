# AIRI Funding Workflow — Autonomous AI Grant Evaluation Pipeline

An end-to-end, cloud-hosted system that **discovers**, **evaluates**, and **drafts
applications for** grant funding opportunities on behalf of the AIRI Foundation — a Canadian
AI-literacy nonprofit. It runs 24/7 with no laptop and no manual data entry. The only human
action in the entire pipeline is clicking **Approve** or **Reject** in an email.

Built and debugged from scratch with n8n, Google Gemini, Docker, and Oracle Cloud.

---

## What it does

Every day, on its own:

1. **Finds** current, open grant opportunities across all of AIRI's focus areas, using
   AI web search grounded in real sources.
2. **Screens** each against hard eligibility rules (country, org type, funding range,
   deadline).
3. **Evaluates** the rest against AIRI's mission, six pillars, and thirty focus areas with
   an LLM, including a values/mission veto for red-line conflicts.
4. **Routes** strong fits to a human for approval by email; rejects poor fits automatically
   with a clear, specific reason.
5. **Drafts** a first-pass application (AI-generated) when a human approves, emails it to
   the team, and writes a prep record.
6. **Remembers** everything it has seen, so re-discovered grants are silently skipped.

---

## Architecture

```
┌──────────────────────── Oracle Cloud (free-tier Linux server, 24/7) ────────────────────────┐
│  Docker                                                                                       │
│    └── n8n (self-hosted, always on)                                                           │
│                                                                                               │
│    ┌── Scraper workflow (scheduled) ──┐        ┌── Evaluation workflow (webhook) ──────────┐  │
│    │  Schedule → Gemini SEARCH         │  POST  │  intake → dedupe → eligibility gate →      │  │
│    │  (Google Search grounding)        │ ─────► │  AI evaluation → values veto → score →     │  │
│    │  → Gemini STRUCTURE (JSON)        │        │  human approval (email) → AI draft →       │  │
│    │  → split → POST each grant        │        │  prep record                               │  │
│    └───────────────────────────────────┘        └────────────────────────────────────────────┘  │
└───────────────────────────────────────────────┬───────────────────────────────────────────────┘
                                                 │
                         ┌───────────────────────┴───────────────────────┐
                         │                                               │
                   Google Gemini API                              Human reviewer
              (search grounding, evaluation,                   (Approve / Reject by email —
               and application drafting)                        the ONLY manual step)
```

---

## The six outcome paths

Every opportunity resolves to exactly one of these, all built and tested end-to-end:

| Outcome | Trigger | Result |
|---|---|---|
| **Approved** | Passes gate, veto, score; human approves | AI-drafted application emailed + prep record written |
| **Ineligible** | Fails the hard eligibility gate | Rejection email explaining which rule failed |
| **Misaligned** | AI values/mission veto | Rejection email citing the values/red-line conflict |
| **Does not qualify** | Passes veto but weak fit | Rejection email explaining why it doesn't fit |
| **Declined by human** | Human rejects in the email | Short "declined by team" email |
| **Duplicate** | Already seen before | Silently skipped |

---

## Tech stack

- **Orchestration:** n8n (self-hosted, Community Edition)
- **AI:** Google Gemini — evaluation and drafting via `generateContent`; grant discovery via
  Gemini with **Google Search grounding** (live, cited web results)
- **Hosting:** Oracle Cloud Always Free (Ubuntu 22.04), Docker, persistent volume
- **State:** n8n Data Tables (opportunity tracking + application prep records)
- **Email:** SMTP (Gmail) for human-in-the-loop approval and notifications

---

## Design decisions worth noting

- **Grounded search over a plain LLM call.** A model with no web access will confidently
  invent fake grants — unacceptable for a funding tool. Google Search grounding ties every
  result to a real source URL.
- **Two Gemini calls in the scraper, not one.** The API doesn't allow search grounding and
  JSON-output mode in the same request, so the design splits cleanly: one call *finds* real
  grants (grounding on), a second *structures* them into strict JSON (grounding off).
- **Scraper is a separate workflow.** It POSTs into the evaluation workflow's webhook rather
  than modifying it, keeping the tested evaluation engine untouched.
- **Discover broadly, filter precisely.** The scraper searches across all focus areas; the
  evaluation engine does the precise scoring. Filtering happens once, downstream.
- **Runs on a 1 GB server.** All heavy AI runs on Google's side, so the box stays light — a
  2 GB swap file covers the tiny instance under load.

---

## Repository contents

- `airi-funding-workflow.json` — the importable evaluation workflow
- `Grant Scraper.json` — the importable scraper workflow (API keys redacted)
- `HOW-IT-WORKS.md` — node-by-node walkthrough of the evaluation workflow
- `CLOUD-AND-SCRAPER.md` — cloud deployment + scraper design
- `CHALLENGES-SOLVED.md` — the debugging journey
- `PROJECT-COMPLETE-REFERENCE.md` — full configuration reference

> **Note:** The workflow JSON files contain no live credentials. To run them, import into
> n8n and add your own Gemini API key and SMTP credentials.

---

## What this project demonstrates

An autonomous AI decision system built and shipped end-to-end: deterministic gating, LLM
evaluation with a values veto, safely-parsed structured AI output, human-in-the-loop
approval, AI document generation, persistent state with duplicate detection, live grounded
web search for discovery, and a full self-hosted cloud deployment — designed, debugged, and
deployed from scratch.
