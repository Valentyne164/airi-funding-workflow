# AIRI Funding Workflow — How It Works (Node by Node)

A plain-language walkthrough of every node, in execution order. Use this to explain the
system to anyone, or as your own reference.

---

## The big picture (one sentence)

A funding opportunity comes in → the system checks if it's a duplicate → checks eligibility →
has AI evaluate mission/values fit → auto-rejects poor fits with reasons → sends strong matches
to a human for approval → generates a draft application → and records everything.

---

## THE MAIN PIPELINE

### 1. Funding Intake (Webhook)
The front door. Listens at a URL for an incoming grant (title, funder, amount, deadline,
country, org type, description). When one arrives, the workflow starts.

### 2. Normalize + AIRI Profile
Cleans up the incoming data into a consistent shape, and attaches AIRI's full profile —
mission, values, 6 pillars, 30 focus areas, red lines, and eligibility rules. It also builds a
stable `opportunity_id` from the funder + title + URL, so the same grant always gets the same ID.
This node is the "brain's memory" of what AIRI stands for.

### 3. Get Existing Record
Looks in the `funding_opportunities` table: "have I seen this opportunity_id before?"
Returns the existing record if found, or nothing if it's new.

### 4. Resolve Stage
Reads the answer from step 3. If nothing was found → marks it `is_new = true`, `stage = new`.
If a record exists → it's a duplicate. (This is the state-machine logic.)

### 5. Route by Stage  (the duplicate gate)
An IF node checking `is_new`.
- **New** (is_new true) → continues to the eligibility gate.
- **Duplicate** (is_new false) → sent to "Already Handled" and stops.
This is what stops the system re-processing the same grant when a scraper feeds it repeatedly.

### 6. Already Handled
A "do nothing" node. Duplicates land here and the workflow ends quietly. No email, no
reprocessing — exactly right for a grant that's already been dealt with.

---

## ELIGIBILITY (deterministic — no AI)

### 7. Hard Eligibility Gate
Objective true/false checks against AIRI's rules: correct country (Canada), eligible org type
(nonprofit/charity), funding within range (5,000–250,000 CAD), and enough deadline lead time.
Outputs `gate_pass` (true/false) and a written `reason`.

### 8. Passed Gate?
An IF node.
- **Pass** → continues to AI evaluation.
- **Fail** → goes to "Log: Ineligible" → the ineligible rejection email. (No AI call wasted on
  something AIRI literally can't apply for.)

---

## AI EVALUATION

### 9. Build Prompt
Assembles the full instruction prompt for the AI — AIRI's pillars, focus areas, red lines, the
grant details, and detailed rules for how to score and how to write rejections. Stored as
`eval_prompt` and passed to the next node.

### 10. Evaluate Opportunity  (+ Google Gemini Chat Model)
The AI brain. Gemini receives the prompt and returns a structured JSON assessment: which pillars
and focus areas match, eligibility judgement, a qualify/don't-qualify decision, reasons to
approve, reasons to reject, watch-outs, capacity fit, and a detailed rejection analysis.
(The Google Gemini Chat Model node is the actual LLM, connected to this node.)

### 11. Parse Evaluation
Takes Gemini's text response, strips any formatting, and turns it into clean, usable fields
(`approval_reasons_str`, `rejection_reasons_str`, `matched_pillars_str`, `reject_email_html`,
etc.). If the AI output can't be parsed, it defaults safely so the pipeline never crashes.

---

## THE DECISION BRANCHES

### 12. Values/Mission Misaligned?  (the veto)
An IF node. If the AI flagged the grant as conflicting with AIRI's values or red lines →
**Log: Misaligned → Email: Rejection (LLM)** (detailed reason). This is the most important
filter: a values-misaligned grant is rejected even if it's otherwise eligible.
- **Not misaligned** → continues to the quality check.

### 13. Qualifies?
An IF node checking the AI's qualify decision (mission fit + score).
- **Qualifies** → Mark Pending Approval → human review.
- **Doesn't qualify** → Log: Does Not Qualify → rejection email (weak fit, explained).

### 14. Mark Pending Approval
Saves `stage = pending_approval` to the table *before* waiting on a human (who may take days),
so the state is never lost.

### 15. Human Approval (Email)  (Send and Wait for Response)
Sends the reviewer a detailed decision brief — summary, matched priorities, reasons to approve,
watch-outs — with **Approve** and **Reject** buttons. The workflow pauses here until the human
clicks.

### 16. Approved?
An IF node reading the human's click.
- **Approved** → Write Application Draft (the approval path).
- **Rejected** → Log: Declined → "Send an Email" (a short "declined by team" note).

---

## THE APPROVAL PATH

### 17. Write Application Draft  (2nd Gemini call)
A second AI call. Using the grant details and AIRI's profile, Gemini writes a full first-draft
grant application: organisation overview, statement of need, objectives, funder alignment,
budget rationale, evaluation plan.

### 18. Application Draft (Send)
Emails the drafted application to the team, ready to refine and submit.

### 19. Generate Application Prep Doc
Creates the internal application-prep record in the `application_prep` table (deadline, amount,
required docs, notes, owner, status).

### 20. Mark Application Prep
Updates the opportunity's stage to `application_prep` in the main table. Done.

---

## THE FIVE OUTCOMES (summary)

| Outcome | How it's reached | What the reviewer gets |
|---|---|---|
| **Approved** | Passes gate, veto, score → human clicks Approve | Draft application emailed + prep record |
| **Ineligible** | Fails Hard Eligibility Gate | Rejection email: which rule it failed |
| **Misaligned** | AI values veto | Rejection email: which values/red lines it breaches |
| **Does Not Qualify** | Passes veto but weak fit | Rejection email: why it doesn't match AIRI's focus |
| **Declined by human** | Human clicks Reject | Short "declined by team" note |
| **Duplicate** | Already in the table | Nothing — silently skipped (Already Handled) |

---

## KEY DESIGN IDEAS (the "why")

- **Deterministic checks before AI** — objective eligibility runs first, so no AI call is wasted.
- **Alignment as a veto, not an average** — mission conflict = automatic rejection, no matter how
  attractive the money is.
- **The human decides appetite, not correctness** — everything reaching a human is already
  eligible and aligned; they just decide "do we want it?".
- **State machine for a live feed** — duplicate detection makes the system safe to run behind an
  automated grant scraper that sees the same grants repeatedly.

---

## MOVING TO THE CLOUD (you do NOT start over)

1. Export this workflow (⋮ → Download JSON).
2. In n8n Cloud → Import from File → the whole workflow loads intact.
3. Re-add credentials (Gemini API key, SMTP) and re-select the two Data Tables.
4. Publish.

Then the v2 upgrades unlock: web-search research (funder-specific accuracy), always-on hosting,
a public webhook URL for an automated grant scraper, and PDF/Google Doc application drafts.
