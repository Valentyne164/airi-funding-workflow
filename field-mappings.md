# AIRI workflow — exact field values for each Data Table node

**How to read this**
- `[E]` = expression. Hover the field → click the small expression toggle (the `fx` icon
  that appears in the field's corner) → paste the value exactly (including the `{{ }}`).
- `[T]` = plain text. Just type it normally, no toggle.
- In each write node, set **Mapping Column Mode = Map Each Column Manually**, click **Refresh**,
  then fill the fields below.
- If you imported the fixed workflow file, some of these may already be filled — just check
  them against this list.

`Get Existing Record` is already done (Get + condition, no fields). Skip it.

---

## 1. Log: Ineligible
Table: **funding_opportunities**  ·  Operation: **Upsert**
Match condition → opportunity_id · Equals · `[E]` `{{ $json.opportunity_id }}`

| Column | Type | Value |
|---|---|---|
| opportunity_id | [E] | `{{ $json.opportunity_id }}` |
| title | [E] | `{{ $json.title }}` |
| funder | [E] | `{{ $json.funder }}` |
| stage | [T] | `rejected_ineligible` |
| reason | [E] | `{{ $json.gate_reason }}` |
| score | [T] | `0` |
| updated_at | [E] | `{{ $now.toISO() }}` |

## 2. Log: Misaligned
Table: **funding_opportunities**  ·  Operation: **Upsert**
Match condition → opportunity_id · Equals · `[E]` `{{ $json.opportunity_id }}`

| Column | Type | Value |
|---|---|---|
| opportunity_id | [E] | `{{ $json.opportunity_id }}` |
| title | [E] | `{{ $json.title }}` |
| funder | [E] | `{{ $json.funder }}` |
| stage | [T] | `rejected_misaligned` |
| reason | [E] | `{{ $json.values_conflicts.join('; ') || $json.eval_reasoning }}` |
| score | [E] | `{{ $json.alignment_score }}` |
| updated_at | [E] | `{{ $now.toISO() }}` |

## 3. Log: Low Fit
Table: **funding_opportunities**  ·  Operation: **Upsert**
Match condition → opportunity_id · Equals · `[E]` `{{ $json.opportunity_id }}`

| Column | Type | Value |
|---|---|---|
| opportunity_id | [E] | `{{ $json.opportunity_id }}` |
| title | [E] | `{{ $json.title }}` |
| funder | [E] | `{{ $json.funder }}` |
| stage | [T] | `rejected_low_fit` |
| reason | [E] | `{{ $json.eval_reasoning }}` |
| score | [E] | `{{ $json.alignment_score }}` |
| updated_at | [E] | `{{ $now.toISO() }}` |

## 4. Mark Pending Approval
Table: **funding_opportunities**  ·  Operation: **Upsert**
Match condition → opportunity_id · Equals · `[E]` `{{ $json.opportunity_id }}`

| Column | Type | Value |
|---|---|---|
| opportunity_id | [E] | `{{ $json.opportunity_id }}` |
| title | [E] | `{{ $json.title }}` |
| funder | [E] | `{{ $json.funder }}` |
| stage | [T] | `pending_approval` |
| reason | [E] | `{{ $json.eval_reasoning }}` |
| score | [E] | `{{ $json.alignment_score }}` |
| updated_at | [E] | `{{ $now.toISO() }}` |

## 5. Log: Declined
Table: **funding_opportunities**  ·  Operation: **Upsert**
Match condition → opportunity_id · Equals · `[E]` `{{ $('Parse Evaluation').item.json.opportunity_id }}`

| Column | Type | Value |
|---|---|---|
| opportunity_id | [E] | `{{ $('Parse Evaluation').item.json.opportunity_id }}` |
| title | [E] | `{{ $('Parse Evaluation').item.json.title }}` |
| funder | [E] | `{{ $('Parse Evaluation').item.json.funder }}` |
| stage | [T] | `declined_by_human` |
| reason | [T] | `Human chose not to pursue` |
| score | [E] | `{{ $('Parse Evaluation').item.json.alignment_score }}` |
| updated_at | [E] | `{{ $now.toISO() }}` |

## 6. Create Application-Prep Record
Table: **application_prep**  ·  Operation: **Insert**  ·  (no match condition)

| Column | Type | Value |
|---|---|---|
| opportunity_id | [E] | `{{ $('Parse Evaluation').item.json.opportunity_id }}` |
| title | [E] | `{{ $('Parse Evaluation').item.json.title }}` |
| funder | [E] | `{{ $('Parse Evaluation').item.json.funder }}` |
| deadline | [E] | `{{ $('Parse Evaluation').item.json.deadline }}` |
| amount | [E] | `{{ $('Parse Evaluation').item.json.amount }}` |
| score | [E] | `{{ $('Parse Evaluation').item.json.alignment_score }}` |
| effort | [E] | `{{ $('Parse Evaluation').item.json.effort_estimate }}` |
| owner | [T] | `UNASSIGNED` |
| required_docs | [T] | `Proposal narrative; Budget; Org registration; Letters of support` |
| draft_notes | [E] | `{{ $('Parse Evaluation').item.json.eval_reasoning }}` |
| status | [T] | `prep_started` |
| created_at | [E] | `{{ $now.toISO() }}` |

## 7. Mark Application Prep
Table: **funding_opportunities**  ·  Operation: **Upsert**
Match condition → opportunity_id · Equals · `[E]` `{{ $('Parse Evaluation').item.json.opportunity_id }}`

| Column | Type | Value |
|---|---|---|
| opportunity_id | [E] | `{{ $('Parse Evaluation').item.json.opportunity_id }}` |
| stage | [T] | `application_prep` |
| reason | [T] | `Approved by human; prep record created` |
| updated_at | [E] | `{{ $now.toISO() }}` |
