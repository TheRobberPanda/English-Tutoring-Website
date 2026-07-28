# Ingles con Paulo — Project Context

## What this is

A trilingual (ES/PL/EN) tutoring business website for Paulo, a language tutor:
- Teaches English to Spanish speakers
- Teaches English and Spanish to Polish speakers
- Teaches Spanish to English speakers

The site is the primary booking and student-management platform for this business — not a portfolio/marketing-only site. Real students book real paid lessons through it.

**Business context:** Paulo is a solo operator who wants to stay solo (no plans to hire), currently has ~3 paying clients, and wants sustainable inbound growth (SEO, referrals, content) rather than manual outreach. He is based in Poland, which matters for legal/consumer-law compliance (GDPR/RODO, Polish consumer rights law).

## Repository

`https://github.com/TheRobberPanda/English-Tutoring-Website`

Files:
- `index.html` — public homepage (hero, about, pricing, testimonials, FAQ, SEO resources section)
- `cuenta.html` — student login/signup + dashboard (booking, credits, referrals, Telegram linking, testimonials, account deletion)
- `admin.html` — Paulo's admin panel (calendar, slot creation, student credits, testimonial moderation, "Next Lessons" Meet-link view)
- `monero.html` — explainer page for paying with Monero
- `legal.html` — trilingual Privacy Policy + Terms + 14-day EU withdrawal-right page
- `perder-verguenza-hablar-ingles.html`, `angielski-dla-niesmialych.html`, `ingles-para-entrevistas-trabajo.html` — SEO landing pages targeting specific long-tail search queries
- `robots.txt`, `sitemap.xml`

All pages are plain HTML/CSS/vanilla JS (no build step, no framework) styled with a warm cream/orange design system (`--bg`, `--orange`, `--peach` etc. CSS variables defined per-file). i18n is done via a `translations` object + `data-i18n`/`data-i18n-html` attributes, toggled client-side, persisted to `localStorage` (`site_lang`) and synced to `profiles.language` for logged-in users.

## Infrastructure

- **Hosting:** Vercel
- **Domain:** Just purchased `inglesconpaulo.org` (migrating off the free `inglesconpaulo.dpdns.org` subdomain — DNS/Vercel/Supabase-redirect-URL/Resend-domain-verification/Google-OAuth-redirect migration is NOT yet complete as of this writing)
- **Backend:** Supabase project `xmpajzrbgnmlttmlwopf` (`https://xmpajzrbgnmlttmlwopf.supabase.co`)
  - Tables: `profiles`, `schedule_slots`, `testimonials`, `telegram_pending_language`, `referral_rewards`
  - Uses the **new Supabase API key system** (`sb_publishable_...` / `sb_secret_...`) — legacy JWT-based `anon`/`service_role` keys have been **disabled** (not just rotated — Supabase's new key system doesn't support rotation, only disable+replace).
- **Edge Functions:** `telegram-webhook`, `booking-notifications`, `delete-account`, `check-calendar-conflicts` (all `verify_jwt: false`, each does its own custom secret-header auth)
- **Booking bot:** Telegram `@InglesDePauloBot` (separate from Paulo's personal `@frelseisme`)
- **Calendar/Meet:** Google Calendar + Meet via OAuth refresh token (NOT a service account — service accounts can't create Meet links or invite attendees on personal Gmail). OAuth app is published to production (was stuck in Testing mode, which caused 7-day refresh token expiry — now fixed).
- **Payments:** Monero (25% discount vs standard payment)
- **Email:** Resend SMTP; contact `yankxwtic@mozmail.com`
- **Secrets:** Stored in **Supabase Vault**, referenced at runtime via `vault.decrypted_secrets` — nothing sensitive is hardcoded in `pg_cron` jobs or trigger functions anymore (this was a real problem that got fixed — see Security section).

## Completed work (chronological, high-level)

1. **i18n system** — client-side trilingual support, `language_manually_set` flag prevents auto-detection from overriding explicit choice, default language Spanish.
2. **~20+ Supabase migrations** — RLS policies, security-definer functions, `pg_cron` scheduling, schema evolution.
3. **Calendar sync bug fix** — `check-calendar-conflicts` cron was silently failing 100% of the time (401s) because `CRON_SECRET` had been rotated but the cron job still sent the old value (which was plaintext in `pg_cron.job` — that's how it leaked). Fixed by moving the secret into Vault and rewriting the cron job to look it up at call time. Also fixed a bug where all-day Google Calendar events (which use `start.date` not `start.dateTime`) were silently ignored by the conflict checker.
4. **Google Meet links were never being generated** for real bookings — traced to the Google OAuth refresh token being dead (see OAuth Testing-mode issue above). Fixed the OAuth setup, then backfilled Meet links for the affected historical bookings via a one-off Edge Function.
5. **Admin dashboard improvements** — "Next Lessons" card at the top showing upcoming bookings with one-click Meet join links (previously `google_meet_link` wasn't even being queried); same join-link added to the calendar day-view panel.
6. **Admin auto-redirect** — `cuenta.html` now redirects admins straight to `admin.html` instead of showing them the student dashboard.
7. **Signup UX** — prominent spam-folder warning shown during signup (email deliverability is genuinely degraded by the free `dpdns.org` subdomain's low sender reputation — a paid domain, now purchased, is the real fix), plus an always-visible "resend confirmation email" link (previously only appeared after a failed login).
8. **Full security audit** — ran Supabase's advisor linter, read every RLS policy/trigger/function, and live-pen-tested the schema as a simulated non-admin attacker (privilege escalation, credit self-grant, reading other students' data, hijacking bookings, self-approving testimonials — all blocked). Fixed: missing `search_path` pinning on all SECURITY DEFINER functions, `anon` execute grants on privileged functions that should be `authenticated`-only, weak Telegram link-code entropy (was `md5(random())` truncated to 6 hex chars — now `gen_random_uuid()`-derived, 256x stronger). Linter findings went from 30 → 9 (remaining 9 are intentional).
9. **Full API key system migration** — Supabase deprecated rotation of legacy JWT keys (disable-only now). Migrated: frontend `SUPABASE_ANON_KEY` constants → new publishable key; the one Database Webhook trigger that used the legacy `service_role` JWT via `Authorization: Bearer` → rewritten to use the new secret key via the `apikey` header (new-format keys aren't JWTs, get rejected on `Authorization: Bearer`), pulled from Vault; `booking-notifications` function flipped to `verify_jwt: false` to match the pattern of the other webhook-driven functions. Verified end-to-end after disabling legacy keys — zero downtime.
10. **Referral program** — every student has a unique 6-char `referral_code` (auto-generated at signup). Dashboard shows a shareable link (`cuenta.html?ref=CODE`) that auto-fills the code and jumps straight to signup. When Paulo grants a referred student's *first* real credit top-up via the admin panel (via a new `admin_grant_credits` RPC — refunds go through separate RPCs and never trigger this), the referrer automatically gets +1 free class. One-time only, logged in a `referral_rewards` audit table.
11. **Legal/compliance page** (`legal.html`) — GDPR/RODO privacy policy (data controller identity section has placeholders Paulo must fill in with his real legal name/address/NIP — this is a genuine legal requirement, flagged clearly in the file), full data/processor/rights disclosure, and a proper explanation of the EU 14-day consumer withdrawal right. The waiver is actually implemented, not just described: signup now has a mandatory checkbox, and `profiles.terms_accepted_at` / `profiles.withdrawal_right_waived` are recorded permanently at signup as evidence.
12. **SEO landing pages** — 3 long-tail-targeted pages (losing fear of speaking English in Spanish; English for shy learners in Polish; job-interview English), linked from the homepage, plus `robots.txt`/`sitemap.xml` for the new domain.

## Known open items / TODO

- **Domain migration is incomplete.** `inglesconpaulo.org` is purchased but DNS, Vercel domain config, Supabase Auth redirect URLs, Resend domain (SPF/DKIM/DMARC) re-verification, and the Google OAuth redirect URI all still need updating for the new domain.
- **`legal.html` has placeholder legal identity fields** (`[Paulo — completa aquí tu nombre legal completo]` etc.) — must be filled in with real info before this page is genuinely compliant. There's also an unresolved question of whether Paulo needs to formally register as a sole proprietor (`jednoosobowa działalność gospodarcza`) in Poland — flagged as a real legal question, not resolved.
- **The "algo parecido a la logopedia" (speech-therapy-like) language on the homepage is a legal risk** — `logopeda` is a regulated profession in Poland; this framing should probably be softened to "confidence coaching" language instead. Not yet changed.
- **`webhook_shared_secret` in Vault** still holds the same value that was previously exposed in plaintext in a trigger definition (now fixed structurally, but the value itself was seen in a chat transcript before the fix) — low priority, but should be rotated to a fresh value whenever convenient.
- **Two students never confirmed their email** (`isra283@gmail.com`, `o2xt0bqst@mozmail.com`) — probably worth a manual nudge.
- **Two Supabase Auth dashboard toggles not yet enabled:** leaked-password protection (HaveIBeenPwned check), and raising the minimum password length above the default 6.
- **The one-off `backfill-meet-links` Edge Function** is still deployed (harmless — requires the same secret header as everything else — but no longer needed, could be deleted).

## Conventions to follow when editing this codebase

- Match the existing warm cream/orange visual design (see CSS `:root` variables at the top of any file) — don't introduce a different palette or font stack (`Fraunces` for headings, `Work Sans` for body, `Space Mono` for codes/labels).
- Every user-facing page needs all three languages (ES/PL/EN) — the `translations` object pattern with `data-i18n`/`data-i18n-html` attributes is the established approach; don't hardcode English or Spanish strings on pages meant for all audiences.
- Any new Supabase secret should go in **Vault**, referenced via `vault.decrypted_secrets` at call time — never hardcode a secret directly into a `pg_cron` job body or a trigger function definition (this exact mistake caused a real incident this project already recovered from).
- Any new SECURITY DEFINER function needs `set search_path = ''` and fully schema-qualified references, plus explicit `revoke`/`grant` on `EXECUTE` — don't rely on Postgres defaults.
- Credit changes to a student's account should go through `admin_grant_credits` (for genuine top-ups, which correctly triggers referral rewards) or the existing refund RPCs (`cancel_booking`, `admin_cancel_slot`) — never a raw `UPDATE profiles SET credits = ...`, since that bypasses both the protective trigger's intent and the referral-reward logic.
