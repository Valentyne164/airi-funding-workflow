# AIRI — AI-Powered Funding Opportunity Evaluation & Approval System

**An end-to-end n8n automation that evaluates grant opportunities for a nonprofit, makes an AI-driven pursue/reject decision, routes strong matches to a human reviewer, and generates a first-draft application — with persistent state so nothing is ever processed twice.**

Built for **AIRI Foundation**, a Canadian AI-literacy nonprofit.

---

## The problem

Nonprofits receive far more funding opportunities than they can realistically evaluate. Manually
reading each one, checking eligibility, judging mission fit, and deciding what to pursue is slow
and inconsistent. AIRI wanted more than a grant *collector* — they wanted a system that actually
*decides*.

## What I built

A production n8n workflow that takes a funding opportunity from intake to an actionable decision:

1. **Intake (webhook)** — receives an opportunity (title, funder, amount, deadline, description).
2. **Duplicate detection (state machine)** — keyed by a stable opportunity ID; already-seen grants
   are skipped so the system never re-processes, re-emails, or re-drafts the same opportunity.
3. **Deterministic eligibility gate** — country, organisation type, funding range, and deadline are
   checked as hard rules. Ineligible grants are rejected instantly, before any AI call is spent.
4. **AI evaluation (Google Gemini)** — the opportunity is scored against AIRI's mission, values,
   focus areas, and explicit *red lines*, producing a structured assessment with reasons and risks.
5. **Values/mission veto** — a grant that conflicts with what AIRI stands for is auto-rejected even
   if it's otherwise eligible and topically about AI. Alignment is treated as a veto, not an average.
6. **Score threshold** — only genuinely strong, aligned opportunities advance to a human.
7. **Human-in-the-loop approval** — the reviewer receives a detailed decision brief by email
   (summary, matched priorities, reasons to approve, risks to weigh) and approves or rejects with
   one click. The human decides *"do we want this?"* — not whether it's a bad fit.
8. **Application-draft generation** — on approval, a second AI call writes a full first-draft
   application (organisation overview, statement of need, objectives, funder alignment, budget
   rationale) and emails it, ready for a human to refine.
9. **Detailed rejection paths** — ineligible, misaligned, and low-fit grants each get a rejection
   email that explains *why*, names the specific values or pillars it conflicts with, and even
   suggests what kind of organisation the grant *would* suit.
10. **Internal record** — every approved opportunity generates an application-prep record; every
    rejection is logged with its reason for a full audit trail.

## Design decisions that mattered

- **Alignment as a veto, not an average.** The most important filter is whether a grant fits *what
  the organisation stands for*. I made mission/values misalignment an automatic rejection, so a
  logistically perfect but values-conflicting grant never reaches a human.
- **Deterministic gate before AI.** Objective eligibility checks (country, org type, deadline,
  amount) run first as hard rules — no AI call is wasted on something the org can't apply for.
- **The human's job is narrow by design.** Everything reaching a reviewer is already eligible and
  aligned, so the approval step is a fast, discretionary "yes/no on appetite," not a QA filter.
- **State machine for a real feed.** Because the system is designed to sit behind an automated
  grant scraper, duplicate detection isn't optional — it's what makes the system safe to run on a
  live stream of repeating opportunities.

## Tech

n8n (self-hosted) · Google Gemini (LLM evaluation + draft generation) · Webhooks ·
n8n Data Tables (persistent state) · SMTP · JavaScript · human-in-the-loop automation

## Engineering challenges solved

- **State routing under a real feed** — designed and debugged a duplicate-detection state machine
  (opportunity ID + stage tracking) so repeated grants are skipped, not reprocessed.
- **Reliability on a free LLM tier** — handled model-availability and rate-limit errors with
  auto-retry and stable model selection.
- **Structured LLM output** — prompted the model to return strict JSON, then parsed it defensively
  so a malformed response never breaks the pipeline.
- **Production vs. test execution** — learned and documented the deploy model (published version,
  webhook registration) to run the workflow as a live service.

## Roadmap (v2)

- **Funder research** — give the evaluation a web-search tool so it researches the actual funder,
  their real priorities, and past grants, making assessments funder-specific rather than
  description-only.
- **Document generation** — output the application draft as a formatted PDF / Google Doc attachment.
- **Automated intake** — a grant scraper front-end that feeds opportunities into the webhook on a
  schedule, turning this decision engine into a fully autonomous pipeline.

---

*Built and debugged end-to-end, from architecture to a live, published production workflow.*
