---
name: Inglés con Paulo
description: A warm paper world for one tutor teaching people who freeze when they speak.
colors:
  bg: "#FBF4EC"
  bg-soft: "#F5EBDD"
  white: "#FFFCF8"
  ink: "#2A1F16"
  ink-soft: "#6B5A48"
  orange: "#F26822"
  orange-deep: "#C1440E"
  peach: "#FBDDC5"
  peach-line: "#E9C8A6"
  monero-ink: "#35271B"
  danger: "#B23A1E"
  danger-deep: "#8F2E17"
  blocked: "#DC2626"
  error-bg: "#FBE4DC"
typography:
  display:
    fontFamily: "Fraunces, Georgia, serif"
    fontSize: "clamp(2.5rem, 6vw, 4.4rem)"
    fontWeight: 600
    lineHeight: 1.1
    letterSpacing: "-0.03em"
  headline:
    fontFamily: "Fraunces, Georgia, serif"
    fontSize: "clamp(1.9rem, 3.8vw, 2.6rem)"
    fontWeight: 600
    lineHeight: 1.1
    letterSpacing: "-0.015em"
  title:
    fontFamily: "Fraunces, Georgia, serif"
    fontSize: "1.05rem"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-0.01em"
  body:
    fontFamily: "Work Sans, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.6
    letterSpacing: "normal"
  label:
    fontFamily: "Space Mono, monospace"
    fontSize: "0.76rem"
    fontWeight: 400
    lineHeight: 1.2
    letterSpacing: "0.07em"
rounded:
  sm: "8px"
  md: "10px"
  lg: "14px"
  xl: "20px"
  pill: "100px"
spacing:
  xs: "8px"
  sm: "14px"
  md: "20px"
  lg: "26px"
  xl: "32px"
  section: "88px"
components:
  button-primary:
    backgroundColor: "{colors.orange}"
    textColor: "{colors.white}"
    rounded: "{rounded.md}"
    padding: "14px 26px"
    typography: "{typography.body}"
  button-primary-hover:
    backgroundColor: "{colors.orange-deep}"
  button-outline:
    backgroundColor: "{colors.white}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: "14px 26px"
  card:
    backgroundColor: "{colors.white}"
    textColor: "{colors.ink}"
    rounded: "{rounded.lg}"
    padding: "30px 26px"
  eyebrow:
    backgroundColor: "{colors.peach}"
    textColor: "{colors.orange-deep}"
    rounded: "{rounded.pill}"
    padding: "6px 15px"
    typography: "{typography.label}"
  input:
    backgroundColor: "{colors.bg}"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
    padding: "11px 14px"
---

# Design System: Inglés con Paulo

## Overview

**Creative North Star: "The Language Notebook"**

The surface is paper before it is screen. Everything sits on a warm cream (`#FBF4EC`) that never goes pure white, text is a soft brown-black (`#2A1F16`) that never goes pure black, and the one accent is a confident orange used sparingly. The reference is a well-kept personal notebook: warm stock, a confident hand, generous margins, and the occasional mark in the margin — the hand-drawn waveform that animates once under the hero headline is exactly that kind of marginalia.

The system is studious without being clinical. Fraunces gives headlines a literary weight that a geometric sans would flatten into software; Work Sans keeps the reading calm; Space Mono is reserved for the things you *handle* rather than read — codes, prices, timestamps, labels. That three-way split is the most load-bearing decision in the system.

Warmth here is functional, not decorative. The audience is adults who feel self-conscious about speaking, and the visual world is deliberately unhurried and un-institutional so that using it never feels like sitting an exam. There is no corporate blue, no dashboard grey, no stock photography. The one real photograph is of Paulo himself.

**Key Characteristics:**
- Paper-warm surfaces; pure white and pure black are absent by design
- A single orange accent, plus peach as its quiet form
- Serif display / sans body / mono label — three voices, strictly assigned
- Flat at rest, lifting only in response to the cursor
- Generous vertical air (88px section rhythm) and a 1040px reading column

## Colors

A single warm accent family on a paper ground; the palette is one hue plus its temperature, not a spectrum.

### Primary
- **Signal Orange** (`#F26822`): the only true accent. Primary buttons, active tabs, the referral hero, focus rings' sibling, and every "this is the action" moment. Its scarcity is what makes it work.
- **Burnt Orange** (`#C1440E`): the pressed and hovered form of Signal Orange, and the text colour for accent-on-peach labels. Never a background for large areas.

### Secondary
- **Peach** (`#FBDDC5`): Signal Orange at conversational volume. Eyebrow chips, notice boxes, the quiet fill behind labels and confirmations.
- **Peach Line** (`#E9C8A6`): the system's only border colour. Every card, input, and divider uses it, which is why the interface reads as one material.

### Neutral
- **Warm Cream** (`#FBF4EC`): the page ground. This is the "paper".
- **Toasted Cream** (`#F5EBDD`): the recessed ground — alternating sections, footers, tutor-authored panels. Depth by tone, not by shadow.
- **Card White** (`#FFFCF8`): raised surfaces. Warmer than white; against Warm Cream it reads as a sheet laid on the desk.
- **Bitter Cocoa** (`#2A1F16`): all primary text, and the dark surface on the Monero card.
- **Muted Cocoa** (`#6B5A48`): secondary text, hints, timestamps. Carries most of the interface's supporting copy.

### Tertiary
- **Monero Ink** (`#35271B`): the top stop of the gradient on the Monero pricing card, the only intentionally dark surface in the system.
- **Clay Red** (`#B23A1E`) / **Deep Clay** (`#8F2E17`): destructive actions only (delete account, reject). Deliberately adjacent to the orange family so danger reads as *serious*, not as a foreign alert colour.
- **Blocked Red** (`#DC2626`) and **Error Wash** (`#FBE4DC`): calendar conflict dots and error message backgrounds respectively.

### Named Rules

**The One Accent Rule.** Signal Orange is the system's only accent. When something needs emphasis and orange is already spoken for, reach for peach, weight, or space — never for a new hue.

**The No Pure Rule.** Nothing is `#FFFFFF` or `#000000`. White is `#FFFCF8`, black is `#2A1F16`. A pure value anywhere is a bug, not a choice.

**The Earned Exception Rule.** Exactly one surface escapes the paper world: the near-black Monero pricing card, whose gravity is the point — it marks the serious payment path. A second exception must earn itself the same way. *The green supporter medal (`#E7F4EC` / `#2F6B45`) currently does not, and is a known drift to reconcile.*

## Typography

**Display Font:** Fraunces (variable, opsz 9–144; fallback Georgia, serif)
**Body Font:** Work Sans (400/500/600; fallback sans-serif)
**Label/Mono Font:** Space Mono (400/700)

**Character:** Fraunces is warm and slightly literary — it gives a solo tutor's page the authority of a book rather than the anonymity of an app. Work Sans underneath it is plain and unfussy, so the reading never competes with the headline. Space Mono is the system's "machine" voice and appears only where a value is meant to be handled.

### Hierarchy
- **Display** (Fraunces 600, `clamp(2.5rem, 6vw, 4.4rem)`, 1.1, `-0.03em`): hero headline only, once per page. Italic within it is set in Signal Orange.
- **Headline** (Fraunces 600, `clamp(1.9rem, 3.8vw, 2.6rem)`, 1.1): section titles.
- **Title** (Fraunces 600, ~1.05rem): card headings, panel titles.
- **Body** (Work Sans 400, 1rem, 1.6): all prose. Reading columns cap around 560–620px, well inside a comfortable measure.
- **Label** (Space Mono, 0.76rem, `0.07em`, uppercase): eyebrows, badges, prices, referral codes, timestamps, unread counts.

### Named Rules

**The Three Voices Rule.** Fraunces says it, Work Sans explains it, Space Mono labels it. A serif paragraph, a mono sentence, or a sans hero all break the system.

**The Handled-Value Rule.** If a value is meant to be copied, counted, or compared — a Monero address, a referral code, a credit balance, a timestamp — it is Space Mono. If it is meant to be read, it is not.

## Layout

A single centred column, `max-width: 1040px` with `32px` gutters (`20px` below 720px). Nothing is full-bleed except section backgrounds.

Vertical rhythm is generous: `88px` between marketing sections, `24px` between stacked cards in the account and admin areas. Cards use asymmetric internal padding (`30px 26px`) — slightly more air above and below than beside, which suits text-dense panels.

Multi-column grids stay shallow and collapse early: the three-card feature grid and two-card pricing grid become single-column at 720px; the paired focus-area panels collapse at 760px; the admin message list collapses at 720px. Breakpoints in use are `1180px`, `760px`, `720px`, `560px`, `480px` — no formal scale, applied where a specific layout actually breaks.

Both authenticated surfaces (student account, admin panel) are organised as **tabbed subpages** rather than one long scroll, with the active tab reflected in the URL hash. Floating furniture — the chat launcher, the credits pill, the unread indicator — is pinned bottom-right and shifts to avoid the content column below 1180px.

**The Reading Column Rule.** Prose never exceeds ~620px even when its container is wider. The 1040px shell is for layout, not for line length.

## Elevation & Depth

Hybrid, leaning tonal. Depth comes first from stacking three warm tones — Warm Cream ground, Toasted Cream recess, Card White raised — and only second from shadow. Surfaces are **flat at rest**; shadow is a response to the cursor, not a permanent property.

Every shadow is tinted with the brown of the ink (`rgba(74, 44, 20, …)`). Neutral grey shadows turn cream muddy and grey-green; this is the single most common way to break the world.

### Shadow Vocabulary
- **Ambient** (`box-shadow: 0 1px 2px rgba(74,44,20,0.05)`): resting cards and outline buttons. Barely there; separates the sheet from the page.
- **Raised** (`box-shadow: 0 4px 16px -4px rgba(74,44,20,0.10), 0 2px 4px rgba(74,44,20,0.04)`): hovered pills and standard pricing card.
- **Lifted** (`box-shadow: 0 18px 40px -12px rgba(74,44,20,0.18), 0 4px 10px rgba(74,44,20,0.05)`): hovered cards, the Monero card, the profile portrait.
- **Accent glow** (`box-shadow: 0 4px 14px -3px rgba(242,104,34,0.55)`): primary buttons and the chat launcher only — orange casting its own coloured light.

### Named Rules

**The Warm Shadow Rule.** Every shadow is `rgba(74, 44, 20, …)`. A grey or black shadow anywhere in this system is a defect.

**The Flat-At-Rest Rule.** Cards, buttons, and chips carry ambient shadow or none. Elevation is earned by hover, focus, or genuine prominence — never assigned decoratively.

## Shapes

Soft but not pill-shaped, with one deliberate exception. The radius ladder is `8px` for inputs and small controls, `10px` for buttons, `14px` for cards, `20px` for the pricing and chat-window surfaces, and `100px` for anything that is a *token* rather than a container — eyebrows, badges, contact pills, student chips, the credits pill.

Borders are uniformly `1px solid` Peach Line, stepping up to `1.5px` on interactive controls (outline buttons, inputs) so the tap target reads as touchable. Circles are reserved for identity: the profile portrait and the avatar initials in the admin student picker.

Two-voice panels use a `4px` left border as the differentiator — orange for the student's own words, cocoa for the tutor's — which is the fastest way to tell authorship before reading a single word.

**The Pill-Means-Token Rule.** `border-radius: 100px` marks something as a label, count, or code — never a container of prose.

## Components

Overall character: **warm and unhurried**. Generous padding, soft lift, nothing shouting for attention. The audience is self-conscious about speaking, so the interface should never feel like it is rushing them.

### Buttons
- **Shape:** Gently rounded (`10px`), `14px 26px` padding, weight 600, `0.95rem`.
- **Primary:** Signal Orange on Card White text, with the accent glow shadow.
- **Hover / Focus:** darkens to Burnt Orange, lifts `translateY(-2px)`, shadow deepens; returns to `translateY(0)` on `:active` so the press is felt. All transitions `0.2s` on `cubic-bezier(0.22, 0.61, 0.36, 1)`.
- **Outline:** Card White fill, `1.5px` Peach Line border, ambient shadow; border turns Signal Orange on hover.
- **Destructive:** Clay Red fill, darkening to Deep Clay. Never orange.

### Chips
- **Style:** Peach fill, Burnt Orange text, pill radius, Space Mono uppercase at `0.76rem` with `0.07em` tracking.
- **State:** the selected admin student chip inverts to solid Signal Orange with a white avatar; unread counts invert to Clay Red with a `2px` page-coloured ring so they read as applied on top.

### Cards / Containers
- **Corner Style:** `14px`.
- **Background:** Card White on Warm Cream; Toasted Cream when the card is a recess (tutor-authored panels, footer).
- **Shadow Strategy:** ambient at rest, lifted on hover — see Elevation.
- **Border:** `1px` Peach Line, brightening toward Signal Orange on hover.
- **Internal Padding:** `30px 26px` (marketing), `28px` (app surfaces).
- **Signature detail:** feature cards carry a `3px` gradient bar (Signal Orange → Peach) at the top edge that wipes in from the left on hover via `transform: scaleX()`.

### Inputs / Fields
- **Style:** Warm Cream fill, `1.5px` Peach Line stroke, `8px` radius, `11px 14px` padding, Work Sans `0.95rem`.
- **Focus:** border becomes Signal Orange, native outline removed — but the global `:focus-visible` ring (`2px solid` Burnt Orange, `2px` offset) still applies system-wide.
- **Error:** message block on Error Wash with Burnt Orange text; the field itself is not recoloured.

### Navigation
- **Marketing:** sticky, translucent Warm Cream at 82% with `blur(12px)`, borderless until scrolled — a `scrolled` class then adds the Peach Line rule and ambient shadow. Links are Muted Cocoa Work Sans 500 with an orange underline that grows from the left on hover.
- **App:** horizontal tab strip over a Peach Line rule; the active tab is Card White with a `2.5px` Signal Orange underline and Burnt Orange label.

### Signature Component — The Waveform Signature
A hand-drawn-feeling SVG waveform beneath the hero headline, stroked in Signal Orange at `3px` with round caps, drawn once on load via `stroke-dasharray/offset` over 2.2s. It is the system's one piece of ornament and stands in for the human voice the product is about. It does not repeat and it does not loop.

### Signature Component — Two-Voice Panels
Paired panels where authorship is the content: a `4px` left border (Signal Orange = the student, Bitter Cocoa = Paulo), a matching tag chip, and a Toasted Cream ground on the tutor side. Used for focus areas on both the student and admin surfaces.

## Do's and Don'ts

### Do:
- **Do** tint every shadow `rgba(74, 44, 20, …)`.
- **Do** keep Signal Orange scarce — roughly one primary action per view.
- **Do** assign the three faces strictly: Fraunces to headline, Work Sans to prose, Space Mono to handled values.
- **Do** convey depth by tone first (Warm Cream → Toasted Cream → Card White) and reach for shadow second.
- **Do** stop looping animation completely under `prefers-reduced-motion` — the referral hero's sheen and pulse both halt, and the page still reads correctly static.
- **Do** design labels to survive Polish, which runs materially longer than Spanish or English; chips and tabs must wrap or ellipsis rather than clip.
- **Do** use `100px` radius only for tokens (badges, codes, counts, pills).

### Don't:
- **Don't** introduce `#FFFFFF` or `#000000`.
- **Don't** use a grey or black shadow.
- **Don't** add a fourth typeface, or a new hue outside the orange family, without an exception as earned as the Monero card's.
- **Don't** treat the green supporter medal as a precedent — it is recorded drift, not a sanctioned accent.
- **Don't** make the waveform loop, or animate it on every navigation; it draws once.
- **Don't** put prose inside a pill.
- **Don't** stack more than three tonal layers; there is no fourth surface colour.
