#!/usr/bin/env bash
# Test payloads for the AIRI funding workflow — one per outcome branch.
# Use the TEST url (click "Listen for test event" in n8n first). For production, swap
# /webhook-test/ for /webhook/.
URL="http://localhost:5678/webhook-test/funding-intake"

echo "== 1. ALIGNED + ELIGIBLE  -> should pass gate, pass veto, score high, email you for approval =="
curl -s -X POST "$URL" -H 'Content-Type: application/json' -d '{
  "title": "AI Literacy for Rural Communities Grant",
  "funder": "Example Digital Foundation",
  "url": "https://example.org/grants/ai-literacy",
  "amount": 60000, "currency": "CAD",
  "deadline": "2026-05-01", "country": "Canada", "org_type": "nonprofit",
  "description": "Funds registered nonprofits delivering AI literacy education and responsible-AI workshops to underserved Canadian communities."
}'; echo; echo

echo "== 2. INELIGIBLE (hard gate)  -> rejected_ineligible (wrong country), no LLM call =="
curl -s -X POST "$URL" -H 'Content-Type: application/json' -d '{
  "title": "US STEM Education Fund",
  "funder": "State Education Board",
  "url": "https://example.org/grants/us-stem",
  "amount": 40000, "currency": "USD",
  "deadline": "2026-06-01", "country": "United States", "org_type": "nonprofit",
  "description": "Supports STEM education programs for schools in the United States."
}'; echo; echo

echo "== 3. MISALIGNED (values veto)  -> eligible on paper, but rejected_misaligned =="
curl -s -X POST "$URL" -H 'Content-Type: application/json' -d '{
  "title": "AI Surveillance Deployment Partnership",
  "funder": "WatchTower Analytics Inc.",
  "url": "https://example.org/grants/surveillance-partner",
  "amount": 90000, "currency": "CAD",
  "deadline": "2026-07-01", "country": "Canada", "org_type": "nonprofit",
  "description": "Funding for a nonprofit partner to pilot and publicly promote our facial-recognition surveillance platform in community settings, in exchange for endorsing the product."
}'; echo; echo
