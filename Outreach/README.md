# Outreach — launch-day email blast

> Working directory for the 2026-07-20 launch email send.  The CSV
> of recipient emails is **gitignored** (PII).  This README + the
> script are committed.

## Files

| File | Tracked? | Purpose |
|---|---|---|
| `README.md` | ✅ | This file |
| `v0-users.csv` | ❌ (gitignored) | Recipient list, curated by maintainer |
| `blast.YYYY-MM-DD.log` | ❌ (gitignored) | Per-send audit log produced by the script |

## CSV schema

`Outreach/v0-users.csv` has four columns:

| Column | Required | Notes |
|---|---|---|
| `email` | yes | The recipient address |
| `first_name` | no | Used to personalise "Hi <name>," — falls back to "Hi," if empty |
| `consent_date` | yes | ISO date the user opted in.  **Empty `consent_date` = no send.**  The script skips these rows. |
| `notes` | no | Free-text annotation for the maintainer (where the contact came from, when they said something specific, etc.).  Not used by the script. |

Header row required.  Example:

```csv
email,first_name,consent_date,notes
alice@example.com,Alice,2026-04-10,GitHub Sponsors backer since v0.49
bob@example.com,Bob,2026-05-02,splynek.app newsletter signup
carol@example.com,,2026-05-15,Discord opt-in
not-yet@example.com,,,never opted in — DO NOT include
```

## Where the list comes from (consent sources)

Splynek has no telemetry and no account system.  There is **no
programmatic way to enumerate v0.x users.**  The CSV is curated
manually from:

1. **GitHub Sponsors backers** — email visible on the Sponsors
   dashboard for tiers that include an email-disclosure perk.
2. **splynek.app newsletter signups** — Mailchimp / Buttondown / etc.
   exports.  Use the most recent export; double-check unsubscribes.
3. **Discord opt-in role** — users with the `launch-news` role have
   explicitly opted in.  Use the bot's export or compile manually.
4. **Direct outreach contacts** — people who emailed support@ and
   said "let me know when v1.0 ships".  Add to the CSV only if they
   were explicit.

**If you can't point to an explicit opt-in moment, don't add them
to the CSV.**  Splynek's privacy posture exists because we don't
cut corners; this is one of those moments.

## How to send

```bash
# 0. Make sure the CSV is up to date + double-check the consent_date
#    column has values for everyone you want to mail.

# 1. Dry-run first — prints intent, sends nothing
python3 Scripts/email-blast-launch.py --dry-run

# 2. Set the Resend API key (same one the Worker uses)
export RESEND_API_KEY=re_…

# 3. Real send
python3 Scripts/email-blast-launch.py

# 4. Audit
cat Outreach/blast.2026-07-20.log | grep FAIL    # any errors?
```

The script throttles to 5 sends/sec and logs every attempt.  Retry
failures by editing the CSV down to just the failed rows and
re-running.

## Removing someone after they reply "stop"

1. Delete the row from `Outreach/v0-users.csv` (or set
   `consent_date` to empty so the script skips them).
2. Add a row to `Outreach/unsubscribed.txt` (gitignored) with their
   email + the date so future blasts don't accidentally re-add
   them.

## Privacy posture (reminder)

- **No tracking pixels** in the email body.  The template uses
  plain HTML paragraphs only.
- **No open-rate / click-rate analytics.**  We don't need to know.
- **No "click here to unsubscribe" link**.  Replies-to-stop is the
  unsubscribe mechanism — it's also a recipient-friendly signal we
  actually read.
- **The CSV stays local** — gitignored, encrypted backup to
  1Password if you keep one.  Never paste into a shared doc.
