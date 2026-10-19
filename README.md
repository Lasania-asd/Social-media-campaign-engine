# 6sense Campaign Engine

Internal app that runs 6sense HQ's LinkedIn program: plan → research → draft → feedback → visuals → publish → results.
It ships seeded with the full plan from **20 Oct to 31 Dec 2026**: 60 posts across Nasif, Ahsan and the company page, the Korea event arcs, the industry watchlist, fresh sources, the fact bank and the voice guides.

---

## Quick start

```bash
cp .env.example .env        # add ANTHROPIC_API_KEY and APP_PASSWORD
npm install
npm run build
npm start                   # http://localhost:4100
```

The first boot creates `data/campaign.db` and seeds it. `npm run reset` wipes and re-seeds (destroys data).

**Docker**
```bash
docker build -t campaign-engine .
docker run -d -p 4100:4100 -v campaign-data:/data --env-file .env campaign-engine
```

**Dev:** `npm run dev` runs the API on :4100 and Vite on :5173 with a proxy.

Requirements: Node ≥ 22.9, and a Chromium binary for rendering visuals. It is auto-detected from Playwright's cache; otherwise set `CHROMIUM_PATH`. The Dockerfile installs one.

---

## How it works

### Campaign architecture (hub and spoke)
Every post hangs off a **source**: something real. A source can be an event, a paper, a regulation, funding, a market move, a field note or a case study. One source feeds several **posts** in different voices, formats and dates, so posts stay varied without inventing material.

| Pillar | Campaigns |
|---|---|
| Authority | We'll be there — Korea (pre → live → recap) · Korea Field Notes · Industry watchlist |
| Insights | Research & innovation (autopilot fills these) · Market & regulation moves |
| Thought leadership | Thought leadership · Proof from the build |
| Eye candy | Explainers: carousels, comparison tables, annotated diagrams, one-chart posts |

Voices: **Nasif** 3×/week, **Ahsan** 2×/week, **Page** about 1×/week plus reposts. Each post is timed to 8:30 am in its target country (KR, JP, SG, NL, UK, US). The UI shows Dhaka time.

### Draft flow (3 rounds, option-based feedback)
1. **Draft 1**: the writer uses the brief, the source's verified facts, the fact bank, the voice guide, the house style and all active rules.
2. You pick **feedback options** (standard ones such as "Lead with the number" or "Cut it by a third", plus 3–6 options specific to that draft). A written note is optional.
3. **Draft 2**, then the same again for the **Final**. You can keep iterating beyond that.

Every version is stored with the options offered, the options chosen and the note.

**Learning:** standard options are counted per voice. When the same option is picked **3 times**, it becomes a standing rule for that voice (`style_rules`, origin `learned`). Rules can be paused or edited in *Voice & rules*.

**No-fabrication guard:** numbers and claims may only come from the source facts or the fact bank. When something is missing, the writer inserts `[FACT NEEDED: …]`. The gap is highlighted in orange and becomes a reminder.

### Visuals
Visuals are rendered from branded HTML templates (Red Hat Display, #17494D / #00BC4C / #BA8D46 / #F7FBEF, 1080×1350) to PNG slides plus a PDF. Upload the PDF to LinkedIn as a document post. Templates live in `server/lib/templates.js`.

### Autopilot (`server/lib/autopilot.js`, Asia/Dhaka)
- **Mon 05:00, research sweep:** Claude with web search, run per country, finds papers, regulations, funding, tech and events no more than 14 days old. Results go into *Sources inbox*. Anything older than 30 days is rejected.
- **Then, match and draft:** planned slots in the next 14 days get the best-fitting fresh source (scored by country, sector, freshness and kind) and a Draft 1.
- **Daily 08:00, reminders:** post today plus comment crew, capture photo, fact gaps, log results 7 days after posting, and the Monday profile-views log. The digest goes to `NOTIFY_WEBHOOK_URL` (Slack, n8n and so on).
- To run manually: *Autopilot* page, or `npm run sweep`.

### Results
KPIs are engagement, profile views (Nasif and Ahsan), LinkedIn → site sessions (from GA) and DMs started. LinkedIn exposes **no API for profile views**, so that number is logged weekly (about 10 seconds, with a reminder). Post metrics are logged per post until a scheduler connector exists (see below).

---

## Integrations (for the CTO)

**Publishing.** "Send to scheduler" POSTs this payload to `SCHEDULER_WEBHOOK_URL`:
```json
{ "id": 12, "voice": "nasif", "text": "...", "scheduled_for": "2026-11-10T13:30:00.000Z", "format": "carousel",
  "media": { "pdf": "https://…/deck.pdf", "images": ["https://…/slide-01.png"] }, "first_comments": ["…"] }
```
Route it through n8n to Fanpage Karma, Metricool or Buffer.

**Metrics.** LinkedIn returns personal-profile post stats only for posts published *through the same tool*. Pick one scheduler for both publishing and stats. Then add a puller that writes to the `metrics` table with `source='<tool>'`; the log-results reminder already skips posts that have metrics. Fanpage Karma (Gold plan and up) and Metricool (Advanced plan and up) both have data APIs.

---

## Data

- SQLite at `data/campaign.db` (WAL mode). Schema: `server/schema.sql`.
- Backup options: `npm run backup` (a safe online copy), or *Results → Download backup (JSON)* at `/api/export`.
- Moving to Postgres later is straightforward: every query is in `server/index.js`, `server/lib/*.js` and `server/db.js`.

## File map
```
server/
  index.js            API + static hosting + auth (shared team password, pick your name)
  db.js, schema.sql   SQLite + helpers
  lib/prompts.js      house style, format specs, feedback-option library, research prompt
  lib/ai.js           Claude calls (writer + web-search research), offline fallback writer
  lib/drafts.js       3-round draft flow + learning
  lib/autopilot.js    sweep, match + draft, reminders, notifications, cron
  lib/templates.js    branded slide templates;  lib/render.js  Chromium → PNG/PDF
  seed/seed.js        the Oct–Dec 2026 plan, events, sources, facts, voices, rules, first drafts
  brand/              logo SVGs
client/src/           React UI (Today, Plan, Studio, Sources, Events, Results, Voice & rules, Fact bank, Autopilot)
```

## Suggested next steps
1. Add `ANTHROPIC_API_KEY`, deploy behind HTTPS, and set `APP_PASSWORD`.
2. Connect a notification webhook (Slack or n8n) so reminders reach people without them opening the app.
3. Choose the scheduler (Fanpage Karma or Metricool), wire the publish webhook and the metrics puller.
4. Photo upload in Studio (photo posts are currently posted with Nasif's own photo).
