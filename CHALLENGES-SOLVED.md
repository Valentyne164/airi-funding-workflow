# AIRI Funding Workflow — Challenges Encountered & How I Solved Them

A record of the real engineering problems I hit while building this system, and how each was
diagnosed and fixed. This is the debugging journey behind the finished workflow — the part that
demonstrates problem-solving, not just following instructions.

---

## 1. State routing — duplicates weren't being handled correctly
**Problem:** New opportunities kept getting routed to "Already Handled" (treated as duplicates)
even on their first run, so the workflow never processed anything.
**Root causes found:** (a) the "Get Existing Record" node had *Always Output Data* on, which made
it echo the input item back — the next node mistook that for a found record; (b) the Switch node's
*strict type validation* wouldn't match the boolean flag even when it was correct.
**Fix:** rewrote the stage-resolution logic to only treat a result as "existing" if it truly
matched (opportunity ID + stage, and not the echoed profile object); switched routing to an IF
node checking `is_new` with type-conversion enabled. Confirmed both paths visually in the
execution view.
**Lesson:** In n8n, "Always Output Data" and strict type validation are subtle traps for state
logic. Verify what a node *actually* outputs, don't assume.

## 2. Production runs used an old version of the workflow
**Problem:** I'd fix something, test via the production URL, and see no change.
**Root cause:** production/webhook execution uses the **Published** version, not the working
editor copy. My edits weren't published.
**Fix:** publish after every change.
**Lesson:** In n8n, "saved" and "published" are different. Production only sees the published
version.

## 3. Multiple workflow copies collided on the same webhook
**Problem:** Tests behaved unpredictably — sometimes hitting an old, broken version.
**Root cause:** several duplicate workflow copies all registered the same webhook path; only one
can own it, and it wasn't always the one I was editing.
**Fix:** archived all duplicates, kept a single source of truth.
**Lesson:** One webhook path = one active workflow. Duplicates cause silent collisions.

## 4. Google Gemini API access kept failing (403 → 404 → 503)
**Problem:** A cascade of different API errors.
**Root causes & fixes:**
- **403 "project denied access":** the API key was created under a school/organisation Google
  account, which the institution blocks. Fixed by creating the key under a **personal Gmail**.
- **404 "model no longer available":** older Flash models are retired for new keys. Fixed by
  selecting a current stable Flash model.
- **503 "high demand":** free-tier congestion. Fixed by enabling **Retry On Fail** and choosing a
  less-loaded model.
**Lesson:** LLM API errors are specific — read the status code. 403 = permissions, 404 = wrong
model, 503 = temporary load. Each has a different fix.

## 5. Emails sent blank or with raw template code
**Problem:** Approval/rejection emails arrived empty, or literally showed `{{ ... }}` text.
**Root cause:** the message field wasn't in expression mode, and/or referenced fields that didn't
exist on that path.
**Fix:** set fields to expression mode and pointed them at fields that actually exist on each
branch.
**Lesson:** An email is only as good as the data path feeding it — reference fields that the
running branch actually produced.

## 6. Rejection email referenced a node that never ran on that path
**Problem:** The eligibility-rejection email errored with "No path back to referenced node:
Parse Evaluation."
**Root cause:** ineligible grants are rejected *before* the AI evaluation runs, so that email
couldn't pull data from the (never-executed) Parse Evaluation node.
**Fix:** pointed the eligibility-rejection email at the nodes that *do* run on that early path
(the eligibility log), not the AI node.
**Lesson:** Each branch only has access to the nodes upstream of it. An early-exit path can't
reference a later node.

## 7. The human reviewer had no way to reject
**Problem:** The approval email only had an "Approve" button, so the human-decline branch could
never fire.
**Fix:** enabled the "Approve and Disapprove" response type, giving the reviewer both buttons,
which routes correctly to the decline branch.
**Lesson:** A human-in-the-loop step needs *both* outcomes wired and reachable, or half your
logic is dead code.

## 8. Human-decline reused the AI rejection email (too detailed)
**Problem:** When a human declined, they got the long AI-analysis rejection, which didn't fit.
**Fix:** added a dedicated short "declined by team" email node on the decline branch, kept
separate from the AI rejection emails so nothing else broke.
**Lesson:** Different rejection *reasons* deserve different messages — separate nodes keep them
independent and safe to edit.

## 9. File/environment logistics
**Problem:** Recovering work across sessions, moving files, and pushing to GitHub had their own
snags (running `git init` in the wrong folder, empty-folder commits, credential exposure in
terminal history).
**Fix:** used a dedicated project folder, verified file contents before committing, rotated any
exposed API keys, and kept secrets out of the repo.
**Lesson:** Treat API keys like passwords — never leave them in terminal history or commit them.

---

## What this journey demonstrates

Building the workflow was the straightforward part. The real work was **diagnosis under
uncertainty** — reading error messages precisely, isolating root causes across a multi-node
system, distinguishing genuine bugs from correct-but-unfamiliar behaviour, and fixing each
without breaking the rest. Every problem above was traced to a specific cause and resolved, and
the final system runs cleanly across all six outcome paths in production.
