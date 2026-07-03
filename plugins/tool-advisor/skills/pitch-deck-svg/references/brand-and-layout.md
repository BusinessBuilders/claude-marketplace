# Brand system & slide layout

A dark, warm, editorial system. Copy these verbatim as a starting point, then recolor the accents to
the company's brand. Two display/body fonts do almost all the work.

## Fonts (Google Fonts)

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,300..800&family=Funnel+Display:wght@300..800&display=swap" rel="stylesheet">
```

- **Funnel Display** (800) — headlines. Tight, confident, modern.
- **Bricolage Grotesque** — body, labels, captions.

## Design tokens

```css
:root{
  --black:hsl(0 0% 4%); --soft:hsl(0 0% 6.5%); --warm:hsl(30 10% 10%); --card:hsl(30 9% 12.5%);
  --cream:hsl(38 60% 92%); --cream-br:hsl(38 75% 97%); --taupe:hsl(35 12% 64%); --dust:hsl(33 9% 46%);
  --orange:hsl(18 67% 50%); --orange-soft:hsl(20 75% 62%); --gold:hsl(38 72% 78%);
  --teal:hsl(196 57% 44%); --teal-l:hsl(196 52% 56%);
  --hair:hsl(38 60% 92% / .12); --soft-b:hsl(38 60% 92% / .22);
  --disp:'Funnel Display','Bricolage Grotesque',sans-serif;
  --body:'Bricolage Grotesque','Inter',system-ui,sans-serif;
}
```

Accent logic: **orange** = primary highlight / "the problem"; **teal** = product/calm/secure;
**gold** = traction/value; **cream** = text. Each highlight color earns its meaning — don't scatter.

## The slide frame (16:9, print-exact)

```css
*{margin:0;padding:0;box-sizing:border-box;-webkit-print-color-adjust:exact;print-color-adjust:exact;}
html,body{background:#000;font-family:var(--body);color:var(--cream);}
@page{ size:1280px 720px; margin:0; }
.slide{position:relative;width:1280px;height:720px;overflow:hidden;background:var(--black);
  page-break-after:always;break-after:page;padding:64px 80px;display:flex;flex-direction:column;}
.slide.glow{background:radial-gradient(120% 90% at 50% 28%, hsl(30 12% 11%) 0%, var(--black) 62%);}
.slide:last-child{page-break-after:auto;}
```

`1280×720` + `@page size:1280px 720px` makes each `<section class="slide">` map to exactly one PDF
page at 16:9. `.glow` adds a subtle vignette for hero/feature slides. `print-color-adjust:exact` keeps
dark backgrounds in the PDF.

## Reusable component classes

```css
.eyebrow{font-weight:600;font-size:14px;text-transform:uppercase;letter-spacing:.18em;color:var(--orange);}
.eyebrow .o{color:var(--teal-l);margin:0 8px;}
h1{font-family:var(--disp);font-weight:800;font-size:92px;line-height:.98;color:var(--cream-br);letter-spacing:-.03em;}
h2{font-family:var(--disp);font-weight:800;font-size:50px;line-height:1.02;color:var(--cream-br);letter-spacing:-.025em;}
h3{font-family:var(--body);font-weight:700;font-size:25px;color:var(--cream-br);line-height:1.2;}
.hl{color:var(--orange);} .hl-t{color:var(--teal-l);} .hl-g{color:var(--gold);}
p.body{font-size:20px;line-height:1.5;color:var(--cream);}
p.lead{font-size:23px;line-height:1.45;color:var(--taupe);}
.muted{color:var(--taupe);}

/* tags / pills */
.tag{display:inline-flex;align-items:center;gap:6px;font-weight:700;font-size:12px;text-transform:uppercase;letter-spacing:.13em;padding:6px 14px;border-radius:999px;}
.tag-teal{background:var(--teal);color:var(--cream-br);} .tag-orange{background:var(--orange);color:var(--cream-br);}
.tag-ghost{background:transparent;color:var(--taupe);border:1px solid var(--soft-b);}
.pill{display:inline-block;font-size:13px;color:var(--taupe);border:1px solid var(--soft-b);border-radius:999px;padding:5px 12px;margin:4px 6px 0 0;}

/* footer + photo frame */
.foot{position:absolute;left:80px;right:80px;bottom:30px;display:flex;justify-content:space-between;font-size:12px;letter-spacing:.12em;text-transform:uppercase;color:var(--dust);}
.frame{border-radius:10px;overflow:hidden;border:1px solid var(--soft-b);background:var(--warm);box-shadow:0 20px 48px rgba(0,0,0,.55);}
.frame img{display:block;width:100%;height:100%;object-fit:cover;}
.cap{font-size:12px;letter-spacing:.1em;text-transform:uppercase;color:var(--dust);margin-top:9px;}

/* layout helpers */
.row{display:flex;gap:46px;align-items:center;flex:1;min-height:0;}
.col{flex:1;min-width:0;}
.strip{display:grid;grid-template-columns:repeat(3,1fr);gap:18px;}   /* 3-photo proof strip */

/* stat blocks */
.stats{display:flex;gap:18px;}
.stat{flex:1;background:var(--card);border:1px solid var(--hair);border-radius:10px;padding:22px 24px;}
.stat .n{font-family:var(--disp);font-weight:800;font-size:40px;color:var(--gold);line-height:1;letter-spacing:-.02em;}
.stat .l{font-size:14px;color:var(--taupe);margin-top:10px;line-height:1.35;}

/* comparison cards */
.cards{display:flex;gap:20px;}
.c{flex:1;background:var(--card);border:1px solid var(--hair);border-radius:10px;padding:26px;border-top:3px solid var(--orange);}
.c.t2{border-top-color:var(--teal);} .c.t3{border-top-color:var(--gold);}
.c .k{font-size:13px;letter-spacing:.12em;text-transform:uppercase;color:var(--orange);font-weight:700;margin-bottom:12px;}
.c h3{margin-bottom:9px;font-size:22px;} .c p{font-size:17px;color:var(--taupe);line-height:1.5;}

/* spec list (◆ is a vector glyph, NOT an emoji) */
.spec{list-style:none;display:flex;flex-direction:column;gap:14px;margin-top:6px;}
.spec li{display:flex;gap:13px;font-size:19px;line-height:1.4;color:var(--cream);}
.spec li .d{color:var(--orange);font-weight:800;flex:none;} .spec li b{color:var(--cream-br);}

/* "lanes" for running/shipped/serving/exploring style status rows */
.lane{background:var(--card);border:1px solid var(--hair);border-radius:10px;padding:16px 20px;border-left:3px solid var(--teal);}
.lane h4{font-size:12px;letter-spacing:.14em;text-transform:uppercase;color:var(--taupe);margin-bottom:6px;font-weight:700;}
.lane .it{font-size:16px;color:var(--cream);line-height:1.4;}

/* bottom call-out banner */
.banner{margin-top:auto;background:var(--card);border:1px solid var(--hair);border-left:3px solid var(--gold);border-radius:10px;padding:16px 22px;font-size:19px;color:var(--cream);line-height:1.4;}

/* SVG text helpers used inside illustrations */
.lbl{font-family:var(--body);font-weight:700;fill:var(--cream-br);}
.sub{font-family:var(--body);font-weight:500;}
```

## Slide skeleton

```html
<section class="slide glow">
  <div class="eyebrow">Section <span class="o">/</span> subtitle</div>
  <h2 style="margin-top:8px;">Headline with a <span class="hl">highlight.</span></h2>
  <div class="row"> ... content / illustration ... </div>
  <div class="banner"><b style="color:var(--gold)">Key takeaway.</b> One supporting sentence.</div>
  <div class="foot"><span>Legal Entity · dba Brand</span><span>06</span></div>
</section>
```

Title-only/closing slides: add `style="justify-content:center;"` to `.slide` and use `h1`.

## Brand wordmark, not a logo file
For dark slides, a typographic wordmark beats a raster logo (which often ships with a white box and
the wrong vibe):
```html
<div style="font-family:var(--disp);font-weight:800;font-size:30px;letter-spacing:-.02em;color:var(--cream-br);">Brand Name<span style="color:var(--orange);">.</span></div>
```
