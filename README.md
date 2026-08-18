# AIRI — Funding Opportunity Evaluation & Approval

An [n8n](https://n8n.io) automation that takes a funding opportunity from intake to an
actionable decision. It screens eligibility, uses an LLM to judge whether the opportunity
fits the organisation's mission and values, auto-rejects poor fits, routes strong matches to
a human for email sign-off, and files an internal application-preparation record — while
keeping persistent state so no opportunity is ever processed twice.

Built for **AIRI Foundation**, a Canadian AI-literacy nonprofit.

---

## Why this is more than a grant collector

Anyone can collect funding opportunities into a list. The value here is everything that
happens *after* intake: the workflow **decides**. It applies a deterministic eligibility
gate, an AI evaluation against the organisation's actual mission and values, a hard veto for
anything that conflicts with what the organisation stands for, a human approval step, and a
generated prep record — with every decision logged and every opportunity tracked by stage.

---

## How it works

```
Webhook (intake)
   -> Normalize + attach org profile
   -> Look up existing record  -- seen before? -> Already Handled (stop)
   -> Eligibility gate (deterministic)  -- fail -> Rejected: Ineligible (logged)
   -> AI evaluation (Gemini) vs mission/values
   -> Mission/values veto  -- misaligned -> Rejected: Misaligned (logged)
   -> Score >= 80?  -- no -> Rejected: Low Fit (logged)
   -> Mark Pending Approval
   -> Human approval email (pause until Approve/Reject)
        -- declined -> Logged
        -- approved -> Create application-prep record -> mark stage -> Done
```

### Node by node

1. **Funding Intake (Webhook)** — the front door. Waits for an opportunity to be sent to it
   (title, funder, amount, deadline, country, description) and starts the run when one arrives.
2. **Normalize + AIRI Profile** — standardises the incoming data and attaches the org profile
   (mission, values, focus areas, red lines, eligibility rules). Builds a stable
   `opportunity_id` from funder + title so the same grant always maps to the same ID.
3. **Get Existing Record** — searches the `funding_opportunities` table by `opportunity_id`
   to check whether this opportunity has been seen before.
4. **Resolve Stage** — if nothing was found it's new; if a record exists it carries that
   opportunity's current stage forward.
5. **Route by Stage** — the state machine. New opportunities go down the processing path;
   already-handled ones are routed to a no-op and stop, so nothing is reprocessed.
6. **Hard Eligibility Gate** — deterministic checks, no AI: correct country, eligible org
   type, funding in range, deadline far enough out. Outputs pass/fail with a reason.
7. **Passed Gate?** — routes failures to a logged rejection; passes continue to the AI.
8. **Evaluate Opportunity + Google Gemini Chat Model** — the AI evaluation. Gemini receives
   the opportunity *and* the org profile and returns structured JSON: a mission-alignment
   verdict, a 0-100 score, reasons to approve, and risk flags.
9. **Parse Evaluation** — turns the model's response into clean fields the workflow can use.
10. **Values/Mission Misaligned?** — the veto. Anything Gemini flags as conflicting with the
    org's values is auto-rejected, even if otherwise eligible.
11. **Score >= 80?** — the quality bar. Below 80 is logged as low-fit; 80+ proceeds to a human.
12. **Mark Pending Approval** — saves the `pending_approval` stage *before* waiting on a human
    (who may take days), so state is never lost.
13. **Human Approval (Email)** — sends the reviewer a decision brief (summary, score, reasons,
    risks) with Approve/Reject buttons and pauses the workflow until they respond.
14. **Approved?** — approved opportunities build the prep record; declined ones are logged.
15. **Create Application-Prep Record** — writes a row into `application_prep` with what the
    team needs to start the application (deadline, amount, required docs, notes, owner, status).
16. **Mark Application Prep** — updates the opportunity's stage to `application_prep`. Done.

Every rejection path (ineligible / misaligned / low-fit / declined) writes the outcome **and
its reason** to the table, so nothing is dropped silently and there's a full audit trail.

### The two-layer filter (design note)

- **Eligibility is deterministic.** Country, org type, deadline, and funding range are
  true/false rules — a fail is an instant reject before any AI call is spent.
- **Alignment is the veto, and the most important filter.** Whether a grant fits *what the
  organisation stands for* is a judgment, so it lives in the AI step — but it's treated as a
  veto: a values-misaligned grant is rejected regardless of eligibility or how attractive the
  money is. Only opportunities that clear the veto **and** score 80+ reach a human.

The human's job is intentionally narrow: everything reaching them is already eligible and
aligned, so they only decide *"do we actually want to pursue this?"* — not catch bad fits.

---

## How intake works in production

In this build the **Webhook** waits to be *sent* an opportunity; the demo feeds it manually.
The webhook is the intake endpoint — in production you put a **source** in front of it that
sends opportunities to that same URL automatically. Options, simplest first:

- **Submission form** — an n8n Form Trigger (or Google Form / Typeform); a staff member pastes
  in a grant they found and submits it. Most realistic for a small nonprofit.
- **Scheduled scraper** — a separate workflow runs on a timer, pulls new grants from funder
  sites / grant databases / RSS, and POSTs each to the webhook. The fully-automated version.
- **Email parsing** — grant newsletters arrive in an inbox; a Gmail trigger extracts the
  opportunity and sends it in.
- **Existing system** — if opportunities are already tracked in Airtable or a CRM, that tool
  calls the webhook whenever a new one is added.

The decision engine is identical in every case; only the source in front of it changes.

---

## Tech

n8n (self-hosted) · Google Gemini (LLM evaluation) · Webhooks · n8n Data Tables (state) ·
SMTP (approval email) · JavaScript · human-in-the-loop automation

---

## Run it locally

Data Tables are off by default on self-hosted, so enable them when you start n8n.

```bash
# Node 18+ installed
# macOS / Linux
N8N_DATA_TABLES_ENABLED=true npx n8n
# Windows PowerShell
$env:N8N_DATA_TABLES_ENABLED="true"; npx n8n
```

Then open http://localhost:5678. Keep that terminal open the whole time — closing it stops
n8n. Use a **second** terminal for any test commands.

### Two Data Tables to create first

n8n -> **Data tables** tab.

**`funding_opportunities`** (state): `opportunity_id`, `title`, `funder`, `stage`, `reason`
(all text), `score` (number), `updated_at` (text).

**`application_prep`** (record): `opportunity_id`, `title`, `funder`, `deadline` (text),
`amount` (number), `score` (number), `effort`, `owner`, `required_docs`, `draft_notes`,
`status`, `created_at` (text).

### Wiring after import

1. **Import** `airi-funding-workflow.json`.
2. **Data Table nodes** — pick the real table on each (`application_prep` for "Create
   Application-Prep Record", `funding_opportunities` for the rest). Field mappings are in
   `field-mappings.md`.
3. **Google Gemini Chat Model** — add a Gemini API key from
   [Google AI Studio](https://aistudio.google.com/apikey) (free tier; a **personal** Google
   account works — some org/school accounts are blocked). Set the model to a stable Flash, e.g.
   `models/gemini-flash-latest`.
4. **Human Approval (Email)** — SMTP credential. For Gmail: enable 2-Step Verification,
   generate an **App Password**, and use host `smtp.gmail.com`, port `465`, SSL on.

### Test

Click **Execute workflow**, then in a second terminal (see `test-payloads.sh`):

```bash
curl -X POST http://localhost:5678/webhook-test/funding-intake \
  -H 'Content-Type: application/json' \
  -d '{"title":"AI Literacy for Rural Communities Grant","funder":"Example Digital Foundation","url":"https://example.org/grants/ai-literacy","amount":60000,"currency":"CAD","deadline":"2028-05-01","country":"Canada","org_type":"nonprofit","description":"Funds nonprofits delivering AI literacy education to underserved Canadian communities."}'
```

Use a **future** deadline, and change the title/funder each run — repeats are correctly routed
to "Already Handled" by the state machine. For repeated use, toggle the workflow **Active** and
POST to the production URL `.../webhook/funding-intake` (no Execute click needed).

---

## Roadmap

- **External research (v2):** replace the evaluation step with an AI Agent that has a
  web-search tool, so it researches the funder itself instead of judging from the submitted
  description alone.
- **Scheduled reminders:** a timer that re-pings `pending_approval` items that go stale.
- **Visible board:** swap Data Tables for Airtable/Notion for a kanban of opportunities by stage.

---

## Files

- `airi-funding-workflow.json` — the importable n8n workflow
- `field-mappings.md` — exact field values for the Data Table nodes
- `test-payloads.sh` — sample opportunities covering each outcome branch
