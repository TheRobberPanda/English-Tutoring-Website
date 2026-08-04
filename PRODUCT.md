# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

**Primary: Spanish speakers learning English.** Adults who can usually read and write the language reasonably but freeze when they have to speak it. They are shy, self-conscious, or blocked rather than beginners. The situation is typically a job interview, a work call or meeting, moving abroad, or travel — a moment where speaking badly has a real cost. The job they are hiring the product for is *to speak without freezing*, not to pass an exam.

**Also taught, but not the core:** Polish speakers learning English or Spanish, and English speakers learning Spanish. These are real and supported, and no future work should break them, but they do not define the product.

**Second user type: Paulo himself.** He is the sole administrator, and `admin.html` is a daily-use operational surface — scheduling, credits, student notes, messages, review moderation — not an afterthought panel. Its usability matters as much as the student's.

## Product Purpose

This is the booking and student-management platform the business actually runs on, not a marketing site with a contact form. Real students book real paid lessons through it.

Success has two halves: a student can book, rebook, and reach Paulo without friction; and Paulo can run the entire operation — availability, credits, lesson notes, messages — solo from one place.

## Positioning

Confidence-first one-to-one teaching for people who freeze when they speak, rather than grammar drilling or exam preparation. The differentiator is the target of the work: the block, not the syllabus.

Supporting, genuinely uncommon positions:

- **Monero is the primary payment method**, at a 25% discount versus standard payment. This is a real, deliberate choice, not a gimmick, and it has its own explainer page.
- **The person teaching is the person who answers your message.** There is no company, no staff, no support queue. This is a stated part of the offer, not just an operational fact.

## Operating Context

- Lessons run over Google Meet; a link is generated automatically per booking and surfaced to both sides.
- Standard lesson length is 50 minutes. One recurring 75-minute arrangement exists, priced at 1.5 credits.
- **Credits, not checkout.** A student buys credits out-of-band, and Paulo adds them manually. There is no payment processor in the product — payment is arranged over email, Telegram, or Monero and reconciled by hand.
- A Telegram bot (`@InglesDePauloBot`) is a full parallel channel: booking, cancelling, and notifications.
- **Paulo's Google Calendar is the source of truth for availability.** Personal commitments there automatically block, and if necessary cancel and refund, conflicting lesson slots.
- Every student-facing page is trilingual (ES/PL/EN), switchable client-side and remembered per user.

## Capabilities and Constraints

- Plain static HTML/CSS/vanilla JS. **No build step, no framework, no package manifest** — this is deliberate and future work should not introduce a toolchain casually.
- Hosted on Vercel behind Cloudflare. Domain: `inglesconpaulo.org`.
- Supabase for auth, database, storage, realtime, and Edge Functions. **Free plan**, which is a real constraint: ~1 GB storage, 50 MB per file, ~5 GB/month egress, 500 MB database. Anything media-heavy must be sized against this.
- **Row Level Security is the actual security boundary**, not the UI. Privileged operations go through `SECURITY DEFINER` RPCs; the frontend holds only a publishable key.
- Credits are fractional (`numeric`), so a lesson can legitimately cost 1.5. "One booking = one credit" is no longer true.
- A slot can be reserved for a single named student; others cannot see or book it.
- Student↔tutor chat supports image, video, audio, and PDF attachments, with **30-day automatic deletion** driven by the storage budget above.
- Per-student focus areas ("things I struggle with") are authored by both the student and Paulo, in separate attributed lists.
- Reviews carry 1–5 stars and threaded comments, and are moderated before appearing publicly.
- Referral reward is 3 free lessons, paid out when a referred student makes their first real credit purchase.
- **No invoicing, VAT handling, or tax identifiers.** Confirmed: Paulo is not planning to register as a sole proprietor (`jednoosobowa działalność gospodarcza`). Future work must not assume an invoice flow, a NIP, or a registered legal entity exists.
- Leaked-password protection is unavailable on the current Supabase plan; minimum password length is 8.

## Brand Commitments

- Name: **Inglés con Paulo** / Paulo Crespo.
- **Voice is first person, warm, plain, and personal.** The confirmed reference example is the referrals honesty note: self-employed, self-made, supporting his family alongside his wife, no company behind it, sincere gratitude for support. Marketing-speak and corporate "we" are off-brand — he is a "we" of one.
- A real photograph of Paulo is in use (`cv.png`). The product is not anonymous.
- **Never describe the teaching as speech therapy, or as "algo parecido a la logopedia."** Confirmed decision: drop the comparison entirely and describe the method on its own terms. `logopeda` is a regulated profession in Poland, and the claim borrows authority that is not his. *This copy is still live on the homepage and has not yet been changed.*
- The green supporter medal shown after a successful referral is **deliberately never announced anywhere in site copy**. It is meant to be discovered on receipt, not worked toward.
- An established visual system already exists across the pages and is authoritative for future work. It is not recorded in a `DESIGN.md`.

## Evidence on Hand

**Real:**
- Paulo's photograph (`cv.png`).
- Real legal identity and postal address, published in `legal.html` (Paulo Cesar Crespo Gallardo, Ul. Mickiewicza 5/1, 22-100 Chełm).
- A small number of live student accounts with genuine booking history.
- Real prices: **16€ per lesson standard, 12€ with Monero (−25%)**; first trial lesson 10€ (7€ with Monero).

**Explicitly absent — do not fabricate:**
- The testimonials currently on the homepage are **illustrative placeholders and are labelled as such**. A real review system now exists, but reviews must be submitted and approved before any can be presented as genuine. Never present the placeholders as real student words.
- There are no case studies, press mentions, customer logos, student counts, or success metrics. None should be invented, including soft forms like "hundreds of learners."

## Product Principles

1. **This is production, not a portfolio.** Real people pay real money through it; a broken booking is a lost lesson and a damaged relationship.
2. **Solo by choice.** Paulo intends to stay a one-person business. No feature should assume staff, shifts, or delegation.
3. **Inbound over outreach.** Growth is meant to come from SEO, referrals, and word of mouth rather than manual selling — features that compound quietly beat features that need daily effort.
4. **Written to be read by the student.** Notes, focus areas, and messages about a student are visible to that student by design. Anything recorded about someone should be phrased as if they are reading it, because they are.
5. **Claim only what is true.** No invented proof, no borrowed professional authority, no numbers that cannot be pointed at.

## Accessibility & Inclusion

- **Trilingual ES/PL/EN is a hard requirement** for every user-facing page. English-only or Spanish-only strings are a defect, not a shortcut.
- `prefers-reduced-motion` is honored, and permanently looping elements must stop completely under it — the account page carries an always-animating referral banner, so this is load-bearing rather than theoretical.
- The audience is explicitly people who feel self-conscious about speaking. Tone across the product must never make a learner feel judged, tested, or behind.
