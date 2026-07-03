---
name: pitch-deck-svg
description: Use when building a premium, investor/partner-grade pitch deck or slide illustrations with hand-built SVG (not AI image renders). Covers the dark editorial brand system, reusable vector components (cartoon workers at desks, isometric building cutaways, GPU/hardware glyphs, cloud-vs-building, voice/data-flow diagrams), the HTML→PDF render pipeline, standalone SVG export for a website, and the visual QA loop. Triggers on "make a pitch deck", "investor deck", "slide illustrations", "deck SVG", "cinematic deck", "render deck to PDF".
---

# Pitch Deck + Hand-Built SVG

How to produce a deck that looks like the best decks on PitchDeckHunt (Shopify/Stripe tier):
illustration-led, dark editorial brand, **hand-built vector** (never AI renders for anything with
labels), rendered from HTML to a compressed PDF, and verified by actually looking at every slide.

This skill is distilled from a real build (the "Business Builders / NVIDIA Inception" deck). The
artifacts it produced live at `~/Desktop/NvidiaInception/deck/deck.html` and `.../web-assets/` — read
those as worked examples.

## When to use
- Building or redesigning a pitch / investor / partner / sales deck.
- Creating diagram-style slide illustrations (architecture, "how it works", product system).
- Porting deck illustrations into a website as standalone SVGs.

## Core principles (the part that matters most)

1. **Illustration-led, not photo-led.** The best decks carry the story with one strong illustration
   per idea + big type + a couple of metrics. Photos are *evidence exhibits* (max ~2: e.g. real
   hardware), small and captioned — not the hero aesthetic.
2. **Hand-built vector beats AI renders for anything with text or structure.** Diffusion models
   hallucinate labels and warp geometry. Vector gives pixel-exact labels, exact brand colors, and
   infinite print resolution. Use AI renders only for *mood*, and label them "concept render".
3. **No emoji. Ever.** Replace 🎙🧠🔊 etc. with crafted vector glyphs. Typographic marks
   (`·` `×` `—` `◆`) are fine.
4. **Problem/question first.** Open on the tension the audience feels ("How do you X when Y?"), then
   answer it. Don't open on your solution/hardware — that's a proof point, not a hook.
5. **One design system, applied everywhere.** Same tokens, type scale, and components on every slide.
   Consistency reads as "serious company."
6. **Depth = professional.** Subtle gradients + a soft `feDropShadow` lift cards/illustrations off the
   background. Flat blobs read amateur.
7. **Verify by looking.** After every change, render and screenshot each slide. Catch overlaps,
   clipped labels, stray emoji, and message contradictions before declaring done.

## Workflow

1. **Set the brand system once** — design tokens + fonts + slide frame + component classes. See
   `references/brand-and-layout.md`.
2. **Outline the narrative** — one idea per slide, no duplicates. A classic 10-slide arc:
   problem/question → the system (signature illustration) → proof → product(s) → traction →
   the ask/roadmap → why-us → vision → close/contact.
3. **Build the signature slide first** — the one big illustration that tells the whole story (e.g. an
   isometric cutaway "building" with cartoon workers in labeled rooms). Get the *look* approved on one
   slide before mass-producing. Reusable SVG components in `references/svg-illustration.md`.
4. **Roll the look across all slides.**
5. **Render → QA → fix, in a loop.** Pipeline + checklist in `references/render-and-qa.md`.
6. **(Optional) Export illustrations as standalone SVGs** for a website. Gotchas in
   `references/svg-illustration.md` (xmlns, deref `var()`, escape `&` in font `@import`).

## Reference files
- `references/brand-and-layout.md` — design tokens, Google Fonts, the 1280×720 slide frame, and the
  reusable component CSS (eyebrow, h1/h2, cards, stats, spec list, lanes, frame, banner, foot).
- `references/svg-illustration.md` — reusable SVG symbols (cartoon worker, desk, GPU card with fans,
  building cutaway slab, cloud silhouette, lock/shield, document glyph), depth techniques
  (gradients + drop shadow + isometric extrusion), and standalone-SVG export for the web.
- `references/render-and-qa.md` — the headless-Chrome → PDF → Ghostscript pipeline, per-slide PNG
  export for inspection, and the QA checklist of failure modes (overlap, clipping, emoji, color/var
  resolution, contradictions).

## Hard-won pitfalls (read once)
- `var(--x)` in a **standalone** `.svg` won't resolve and the file may render as an XML tree — add
  `xmlns="http://www.w3.org/2000/svg"` and replace every `var(--token)` with a literal value.
- A Google Fonts `@import` URL has `&` which is invalid in XML — write it as `&amp;`.
- Long body text in a fixed-size box silently **overlaps** the element below — shorten copy or tighten
  spacing, then re-render to confirm.
- Text near a viewBox edge gets **clipped** — center labels over their group and keep within the box.
- After messaging edits, `grep` the whole file for contradictions (e.g. "data never leaves" while
  also pitching a hosted service) and for any banned terms.
- Keep an `OLD-backup` copy before a full rewrite; render to PNG and **look** before shipping.
