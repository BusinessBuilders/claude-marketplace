# Hand-built SVG illustration

Everything here is plain inline SVG inside the deck HTML, using the brand tokens via `fill="var(--x)"`.
Build illustrations from a small kit of reusable `<symbol>`/`<g>` definitions placed once in `<defs>`,
then `<use>`d with a `color="…"` to recolor (the shapes use `fill="currentColor"`).

## Depth defs (gradients + soft shadow) — makes it look professional

```xml
<defs>
  <!-- soft drop shadow: lifts cards/buildings off the background -->
  <filter id="soft" x="-20%" y="-20%" width="140%" height="140%">
    <feDropShadow dx="0" dy="9" stdDeviation="13" flood-color="#000" flood-opacity="0.5"/>
  </filter>
  <!-- a warm glow behind a hero subject -->
  <radialGradient id="glow" cx="50%" cy="40%" r="60%">
    <stop offset="0" stop-color="hsl(18 67% 50% / .18)"/><stop offset="1" stop-color="hsl(18 67% 50% / 0)"/>
  </radialGradient>
  <!-- extruded slab faces for an isometric/3D card -->
  <linearGradient id="roof" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="hsl(30 10% 18%)"/><stop offset="1" stop-color="hsl(30 10% 13%)"/></linearGradient>
  <linearGradient id="side" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="hsl(30 9% 9%)"/><stop offset="1" stop-color="hsl(30 9% 12%)"/></linearGradient>
</defs>
```

Apply `filter="url(#soft)"` to the big panels (building front face, cards). Put a faint `url(#glow)`
ellipse behind the focal point. Use a 2-tone gradient on any large flat fill so it isn't a dead blob.

## Cartoon worker + desk (the personality)

Origin at the worker's feet; ~50px tall; shirt color = `currentColor`.

```xml
<g id="worker">
  <ellipse cx="0" cy="1" rx="13" ry="3.2" fill="hsl(0 0% 0% / .4)"/>            <!-- ground shadow -->
  <rect x="-7.5" y="-15" width="6" height="16" rx="3" fill="hsl(220 6% 30%)"/>   <!-- legs -->
  <rect x="1.5" y="-15" width="6" height="16" rx="3" fill="hsl(220 6% 30%)"/>
  <path d="M-13 -13 q0 -22 13 -22 q13 0 13 22 z" fill="currentColor"/>           <!-- torso/shirt -->
  <circle cx="-13.5" cy="-23" r="3.4" fill="currentColor"/><circle cx="13.5" cy="-23" r="3.4" fill="currentColor"/> <!-- arms -->
  <circle cx="0" cy="-44" r="9.5" fill="hsl(38 55% 86%)"/>                        <!-- head -->
  <path d="M-9.5 -46 a9.5 9.5 0 0 1 19 0 q-9.5 -7 -19 0 z" fill="hsl(28 38% 24%)"/> <!-- hair -->
</g>

<g id="desk">  <!-- origin at floor; monitor glow = currentColor -->
  <rect x="-12" y="-3" width="4" height="15" rx="1.5" fill="hsl(30 10% 16%)"/><rect x="20" y="-3" width="4" height="15" rx="1.5" fill="hsl(30 10% 16%)"/>
  <rect x="-16" y="-6" width="44" height="6" rx="2" fill="hsl(30 12% 22%)"/>
  <rect x="-10" y="-23" width="26" height="17" rx="2.5" fill="hsl(30 14% 12%)" stroke="currentColor" stroke-width="1.6"/>
  <rect x="-6" y="-19" width="18" height="9" rx="1" fill="currentColor" opacity=".5"/><rect x="1" y="-6" width="4" height="6" fill="hsl(30 12% 18%)"/>
</g>
```

Use: `<g transform="translate(140,234)"><use href="#worker" color="var(--teal)"/></g>`
Make figures **big enough to have personality** — tiny figures read as clip-art noise.

## Cutaway "building" (the signature illustration)

A slab with depth + a labeled roof sign + a grid of rooms, each room = one function with an icon, a
worker at a desk, and a label. This single frame can carry your whole story.

```xml
<!-- extruded slab: roof + side + front face -->
<polygon points="60,100 788,100 828,76 100,76" fill="url(#roof)" stroke="hsl(38 60% 92% / .14)"/>
<polygon points="788,100 828,76 828,440 788,444" fill="url(#side)" stroke="hsl(38 60% 92% / .10)"/>
<rect x="60" y="100" width="728" height="340" fill="hsl(30 9% 11.5%)" stroke="hsl(38 60% 92% / .16)" filter="url(#soft)"/>
<!-- roof sign -->
<rect x="280" y="50" width="330" height="32" rx="16" fill="hsl(30 9% 14%)" stroke="hsl(18 67% 50% / .55)"/>
<text x="430" y="71" text-anchor="middle" class="lbl" font-size="16" letter-spacing="2">YOUR&#160;BUSINESS</text>
<!-- one room (repeat across a grid; recolor per function) -->
<rect x="76" y="116" width="168" height="150" rx="6" fill="hsl(196 40% 12%)" stroke="hsl(196 57% 44% / .5)"/>
<rect x="76" y="116" width="168" height="5" rx="2.5" fill="var(--teal)"/>   <!-- accent top bar -->
<text x="160" y="140" text-anchor="middle" class="sub" font-size="11" fill="var(--teal-l)" font-weight="700">VOICE</text>
<g transform="translate(188,234)"><use href="#desk" color="hsl(196 52% 60%)"/></g>
<g transform="translate(134,234)"><use href="#worker" color="var(--teal)"/></g>
<text x="160" y="254" text-anchor="middle" class="lbl" font-size="14">Function · label</text>
```

Pattern: 4 rooms across the top for the 4 functions; a wide floor band beneath for "the machine";
put a *separate* zone to the side for anything that isn't the customer's (e.g. "our shop / our
cluster") so ownership is never ambiguous.

## Hardware / GPU card glyph (reads as a graphics card, not an empty box)

```xml
<g fill="hsl(30 11% 17%)" stroke="hsl(120 25% 50% / .85)" stroke-width="1.4">
  <rect x="116" y="330" width="54" height="58" rx="3"/>   <!-- card body, green PCB edge -->
</g>
<g fill="none" stroke="hsl(196 50% 58% / .8)" stroke-width="1.3">
  <circle cx="143" cy="350" r="9"/><circle cx="143" cy="372" r="6"/>          <!-- dual fans -->
</g>
<circle cx="143" cy="350" r="1.8" fill="hsl(120 40% 55%)"/>                    <!-- status LED -->
```
Tile 8 of these for an "8× GPU cluster" rack.

## Cloud-vs-building (problem visual for the cover)

Blocked **public cloud** at top (a clean silhouette with a vertical gradient, NOT a flat blob), an
orange circle-slash "no" badge, a dashed-and-blocked path down, and a glowing **building** holding the
private files behind a closed lock.

```xml
<linearGradient id="cloudg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="hsl(220 9% 44%)"/><stop offset="1" stop-color="hsl(220 11% 25%)"/></linearGradient>
<!-- cloud silhouette (filled bumps, single gradient fill, no internal strokes) -->
<g fill="url(#cloudg)"><ellipse cx="220" cy="68" rx="60" ry="30"/><circle cx="182" cy="64" r="27"/><circle cx="256" cy="58" r="31"/><rect x="160" y="66" width="120" height="28" rx="8"/></g>
<!-- "no" badge -->
<g transform="translate(305,58)"><circle r="20" fill="hsl(18 45% 14%)" stroke="var(--orange)" stroke-width="2.6"/><line x1="-11" y1="11" x2="11" y2="-11" stroke="var(--orange)" stroke-width="2.8" stroke-linecap="round"/></g>
<!-- closed lock badge -->
<g transform="translate(120,250)"><circle r="20" fill="hsl(196 45% 14%)" stroke="hsl(196 57% 58%)" stroke-width="2.2"/><g stroke="hsl(196 57% 70%)" stroke-width="2.4" fill="none" stroke-linecap="round"><rect x="-9" y="-2" width="18" height="15" rx="3" fill="hsl(196 45% 20% / .7)"/><path d="M-5 -2 v-5 a5 5 0 0 1 10 0 v5"/></g></g>
```
NOTE: build cloud silhouettes from **filled** shapes with no per-shape stroke — overlapping dashed
strokes create internal lines and the cloud reads as a smudge.

## Flow diagram glyphs (no emoji)

Vector mic / chip / speaker for a "voice stack", document for "scanning", arrows between boxes:

```xml
<!-- mic --> <g stroke="hsl(196 52% 66%)" stroke-width="2.4" fill="none" stroke-linecap="round"><rect x="-6" y="-13" width="12" height="22" rx="6" fill="hsl(196 40% 18%)"/><path d="M-11 2 a11 11 0 0 0 22 0"/><path d="M0 13 v6"/><path d="M-7 19 h14"/></g>
<!-- chip --> <g stroke="hsl(38 72% 82%)" stroke-width="2.2" fill="hsl(38 30% 18%)"><rect x="-11" y="-11" width="22" height="22" rx="3"/><g stroke-width="2" stroke-linecap="round"><line x1="-11" y1="-5" x2="-16" y2="-5"/><line x1="11" y1="-5" x2="16" y2="-5"/><line x1="-5" y1="-11" x2="-5" y2="-16"/><line x1="5" y1="11" x2="5" y2="16"/></g><rect x="-4.5" y="-4.5" width="9" height="9" rx="1.5" fill="hsl(38 72% 82%)" stroke="none"/></g>
<!-- speaker --> <g stroke="hsl(20 75% 66%)" stroke-width="2.3" fill="none" stroke-linecap="round" stroke-linejoin="round"><path d="M-14 -6 h8 l9 -7 v26 l-9 -7 h-8 z" fill="hsl(20 40% 18%)"/><path d="M10 -7 a11 11 0 0 1 0 14"/><path d="M15 -12 a18 18 0 0 1 0 24"/></g>
<!-- arrow --> <g stroke="var(--orange)" stroke-width="2.4" fill="var(--orange)"><line x1="124" y1="68" x2="164" y2="68"/><polygon points="166,68 158,64 158,72"/></g>
<!-- document --> <g fill="hsl(20 30% 18%)" stroke="hsl(20 75% 66%)" stroke-width="2"><rect x="-8" y="-10" width="16" height="21" rx="2"/><line x1="-3.5" y1="-4" x2="3.5" y2="-4"/><line x1="-3.5" y1="1" x2="3.5" y2="1"/></g>
```

## Exporting an illustration as a standalone .svg (for a website)

Inline-in-HTML SVGs rely on the document's CSS (`var(--x)`, the `.lbl/.sub` classes) and don't need a
namespace. A standalone `.svg` does. Transform each `<svg>…</svg>`:

1. Add namespaces to the root tag:
   `<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" …>`
   (omit and the browser shows an XML tree instead of the picture.)
2. Replace **every** `var(--token)` with its literal value (presentation attributes don't resolve
   `var()`). e.g. `var(--teal)` → `hsl(196 57% 44%)`.
3. Inject a `<style>` right after the opening tag for fonts + the `.lbl/.sub` classes. The Google
   Fonts URL contains `&` — it must be `&amp;` or the XML is invalid:

```xml
<style>
@import url('https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,300..800&amp;family=Funnel+Display:wght@300..800&amp;display=swap');
text{font-family:'Bricolage Grotesque','Inter',system-ui,sans-serif;}
.lbl{font-weight:700;fill:hsl(38 75% 97%);}
.sub{font-weight:500;}
</style>
```

4. Prepend `<?xml version="1.0" encoding="UTF-8"?>` and save.

A tiny Python pass that does all of the above against a deck HTML lives conceptually as: regex
`<svg\b.*?</svg>` (DOTALL), `str.replace` each token, `re.sub` to inject namespaces + style, write
each to `web-assets/<name>.svg`. Then **render each standalone SVG to PNG and look** — confirm colors
resolved (not black) and `<use>` symbols appear. These illustrations are designed for **dark**
backgrounds; composite them on the site's dark sections.
