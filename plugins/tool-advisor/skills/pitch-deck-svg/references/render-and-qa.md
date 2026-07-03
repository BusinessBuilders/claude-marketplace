# Render pipeline & visual QA

The deck is a single `deck.html` of `<section class="slide">` blocks. Render to PDF with headless
Chrome, compress with Ghostscript, and inspect every slide as a PNG. **Always look at the output** —
HTML that "should" be fine routinely has overlaps, clipped text, or a stray emoji.

## Render HTML → PDF

```bash
cd /path/to/deck
google-chrome --headless=new --disable-gpu --no-pdf-header-footer \
  --print-to-pdf=deck-raw.pdf "file://$PWD/deck.html"
```
- Find the binary if needed: try `google-chrome`, `google-chrome-stable`, `chromium`, `chromium-browser`.
- The `Failed to connect to the bus` / DBus errors in output are harmless.
- `--no-pdf-header-footer` removes the date/URL margins.
- `@page{size:1280px 720px}` in the CSS makes each slide exactly one 16:9 page.

## Compress for sending (Ghostscript)

```bash
gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook -dNOPAUSE -dQUIET -dBATCH \
   -sOutputFile=Deck.pdf deck-raw.pdf
```
`/ebook` typically takes a multi-MB deck (big photos) down to well under 1 MB while staying crisp on
screen. Verify: `pdfinfo Deck.pdf | grep -E 'Pages|Page size'` (expect your slide count and
`960 x 540 pts` = 16:9).

## Export per-slide PNGs to actually inspect

```bash
pdftoppm -png -r 110 deck-raw.pdf qa/s            # all slides -> qa/s-01.png ...
pdftoppm -png -r 120 -f 7 -l 7 deck-raw.pdf qa/s  # just slide 7
```
Then open/Read each PNG and look. Render a single standalone SVG to PNG to verify it in isolation:
```bash
google-chrome --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
  --window-size=1180,560 --screenshot=check.png "file://$PWD/web-assets/system.svg"
```
GOTCHA: in `--headless=new`, `--window-size` is the WINDOW, and ~87px of its height is reserved for
browser chrome — the viewport is that much shorter, so exact-size captures cut off the bottom of the
art (with a white band below). Always add ~100px of height slack (`--window-size=W,H+110`); for
dark-designed SVGs, screenshot a small dark-background wrapper HTML that `<img>`s the SVG at its
exact pixel size, so the extra viewport is filled by the wrapper background instead of white.

## Open it on the user's screen
```bash
( xdg-open Deck.pdf >/dev/null 2>&1 & )     # PNG/HTML previews you Read are NOT visible to the user
```
The user cannot see images you Read into your own context — open the file for them, or save a
screenshot with the browser tool's `save_to_disk`.

## QA checklist (run after every change)

- **Overlap:** does long body text in a fixed box collide with the element below? (Banners with
  `margin-top:auto` are common offenders.) Shorten copy or tighten spacing; re-render.
- **Clipping:** any label running off a card or past the SVG viewBox? Center labels over their group;
  keep within bounds.
- **Emoji:** scan and remove. `grep -nP '[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}]' deck.html` (keep
  `· × — ◆`). Replace with vector glyphs.
- **Color/var resolution (standalone SVGs):** anything rendering black that should be teal/orange =
  an unresolved `var()`; an XML-tree view = missing `xmlns`.
- **Consistency:** same type scale, accent meaning, and terminology on every slide. After messaging
  edits, `grep` for contradictions and banned terms across the whole file.
- **Photos:** at most ~2, clean (no heavy filters/duotone), captioned as evidence.
- **Placeholders:** `grep -niE 'TODO|FIXME|lorem|placeholder|tbd' deck.html` → none.

## Iteration discipline
- Back up before a big rewrite: `cp deck.html deck-OLD-backup.html`.
- Build/approve the signature slide's *look* before applying it to all slides.
- After N consecutive passes with no real defect found, the deck has **converged** — stop; further
  micro-edits risk regression. Say it's done rather than nipping at a finished file.
- Keep the final file's name stable (e.g. `Deck.pdf`) so a re-render overwrites the canonical file the
  user uploads.
