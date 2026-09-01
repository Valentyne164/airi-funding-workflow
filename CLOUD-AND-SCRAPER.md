# AIRI Funding Workflow — Cloud Deployment & Autonomous Scraper

A companion to the original workflow write-ups. Where the evaluation workflow *decides*
on grant opportunities, this document covers the two additions that made the system
**fully autonomous**: hosting it in the cloud so it runs 24/7 without a laptop, and an
AI-powered scraper that finds new grants on its own and feeds them in.

The result is an end-to-end pipeline where the **only human action is clicking Approve or
Reject in an email.** Everything else — discovery, evaluation, drafting, record-keeping —
happens on its own.

---

## 1. What was added

Two upgrades, on top of the already-built evaluation workflow:

1. **Cloud hosting** — moved n8n off a local laptop onto an always-on cloud server, so the
   workflow is live at a public address 24/7.
2. **Autonomous scraper** — a second, scheduled workflow that uses AI web search to
   discover current grant opportunities and POSTs each one into the evaluation workflow's
   webhook automatically.

---

## 2. Cloud deployment

### Stack
- **Host:** Oracle Cloud (Always Free tier), a `VM.Standard.E2.1.Micro` instance
  (1 OCPU / 1 GB RAM) running Ubuntu 22.04.
- **Runtime:** Docker, running n8n (Community Edition) as a container with a persistent
  volume so all workflows, credentials, and Data Tables survive restarts.
- **Reachability:** exposed on port 5678 to the public internet.

### Notable decisions
- **AMD micro over ARM.** The larger free ARM shape (Ampere A1, 4 OCPU / 24 GB) was
  persistently "out of capacity" in the region, so the always-available AMD micro was used
  instead. It's small, which drove the next decision.
- **A swap file for the 1 GB box.** With only 1 GB of RAM, n8n under load risks being
  killed by the OS. A 2 GB swap file (persisted in `/etc/fstab`) gives it headroom to run
  reliably on a tiny instance.
- **Gemini stays remote, so the box stays light.** All heavy AI work runs on Google's
  servers via the Gemini API, not on the server itself. That's what lets the whole system
  run on a 1 GB instance.
- **`--restart unless-stopped`** on the container, so n8n comes back automatically after a
  crash or a server reboot — a requirement for "always on."

### The firewall gotcha (worth calling out)
Oracle Cloud blocks inbound ports by **two** independent layers, and both must be opened:
1. The **Oracle Security List** (an ingress rule in the cloud console), and
2. The **instance's own `iptables`** firewall (Oracle's Ubuntu image ships with strict
   rules that also block the port).

Opening one and not the other produces a silent "connection timed out" with no error —
a classic source of lost time. Both were opened for port 5678, and the `iptables` rule was
persisted with `netfilter-persistent` so it survives reboots.

---

## 3. The autonomous scraper

### Goal
Replace the manual "send an opportunity to the webhook" step with a scheduled workflow that
finds grants on its own — across *all* of AIRI's focus areas, not just one — and hands each
to the tested evaluation engine.

### Architecture
A separate workflow, so the tested evaluation workflow stays untouched:

```
Schedule Trigger (daily)
  → HTTP Request  → Gemini call #1: SEARCH (Google Search grounding)
       Finds real, current grant opportunities across AIRI's focus areas,
       with real source URLs. Returns grounded prose.
  → HTTP Request  → Gemini call #2: STRUCTURE (JSON mode, no tools)
       Converts that prose into a clean JSON array with the exact fields
       the evaluation webhook expects.
  → Code node     → parse the JSON string into individual items (one per grant)
  → HTTP Request  → POST each grant to the evaluation workflow's webhook
```

Each scraped grant then flows through the **existing** evaluation pipeline: eligibility
gate → AI evaluation → values/mission veto → score threshold → human approval by email →
AI-drafted application → prep record. Poor fits are rejected with reasons; strong ones reach
a human.

### Why two Gemini calls, not one
Gemini's **Google Search grounding** (live web access) **cannot be combined with JSON output
mode** in a single request — the API only allows search tools together with other search
tools. So the design splits cleanly:
- **Call #1** searches the live web (grounding on) and returns grounded text with real
  sources — this is what prevents the model from hallucinating grants.
- **Call #2** takes that text and reshapes it into strict JSON (grounding off, JSON mode on).

This separation is not a workaround so much as the correct decomposition: *find* real
grants, then *structure* them.

### Why grounding matters
A plain LLM call with no web access will confidently invent plausible-but-fake grants —
worse than useless for a funding tool. Google Search grounding connects the model to live
web content and returns real opportunities with citations, so every grant the scraper
produces traces back to a real source URL.

### Duplicate safety
Grounded search tends to re-surface the same well-known grants on each run. This is a
non-issue because the evaluation workflow already has **duplicate detection**: a stable
`opportunity_id` (funder + title + url) is checked against a Data Table, and repeats are
silently dropped via the "Already Handled" path. So the scraper can safely re-discover the
same grants daily without re-processing them.

---

## 4. Autonomy: what keeps it running

- n8n runs 24/7 in Docker on the cloud server, independent of any personal machine.
- The scraper workflow is **Published (Active)**, so its Schedule Trigger fires on its own —
  no browser, no laptop needed.
- Container and swap both survive reboots; workflow data persists on disk.
- The only human action in the entire system is clicking **Approve** or **Reject** in the
  emails the pipeline sends.

---

## 5. End state

A genuinely autonomous, cloud-hosted AI decision pipeline:

- runs 24/7 in the cloud, independent of any laptop;
- **finds** new grant opportunities automatically on a schedule, using grounded AI web
  search across all of AIRI's focus areas;
- **evaluates** each against AIRI's mission, values, and eligibility with AI;
- **rejects** poor fits with clear reasons and routes strong ones to a human;
- **drafts** a first application on approval and records it;
- and requires a human only to click Approve or Reject.
