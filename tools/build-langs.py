#!/usr/bin/env python3
"""Generate the Polish and English homepages from index.html.

Why this exists
---------------
The site does its i18n client-side: one URL, one HTML file, and a
`translations` object swapped in by JS. That is fine for a logged-in student
who picks a language, but it makes the site effectively monolingual to search
engines. A crawler fetches `/`, gets the Spanish render, and indexes that.
There is no separate URL for the Polish or English homepage, so there is
nothing for Google to rank for a Polish or English query — which matters a
lot here, since two of the three audiences (Polish speakers, English speakers
wanting Spanish) are reached only through those languages.

The fix is one URL per language plus reciprocal hreflang:

    /      -> Spanish  (also x-default)
    /pl/   -> Polish
    /en/   -> English

Rather than hand-maintaining three near-identical 1500-line files, this script
derives the variants from index.html. Run it after any homepage edit:

    python3 tools/build-langs.py

What it changes per variant
---------------------------
* `<html lang>`, `<title>`, `<meta description>` and the og:/twitter: strings
  are replaced with the translated versions below. These are static in <head>,
  so the client-side translator never touches them — yet they are exactly what
  a search result snippet shows. They have to be right in the HTML itself.
* `currentLang` is pinned to the page's language instead of being read from
  localStorage, so the body copy renders in that language on first paint. The
  body text is still translated by the existing client JS; Google renders JS,
  so this indexes correctly, and a human with JS disabled still gets a fully
  laid-out page (in Spanish) rather than a blank one.
* The language buttons navigate between the three URLs instead of swapping
  text in place, so the URL and the visible language can never disagree.
* Relative links/assets become root-absolute, because these files live one
  directory down.
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SITE = "https://www.inglesconpaulo.org"

# Spanish stays the canonical root. Each entry is the <head> text that the
# client-side translator cannot reach.
LANGS = {
    "pl": {
        "dir": "pl",
        "locale": "pl_PL",
        "title": "Paulo Crespo — angielski i hiszpański, żeby wreszcie mówić",
        "desc": (
            "Lekcje 1 na 1 przez wideorozmowę, skupione na mówieniu — dla osób, "
            "które rozumieją język, ale blokują się, gdy trzeba coś powiedzieć. "
            "Pierwsza lekcja próbna w niższej cenie."
        ),
        "img_alt": "Paulo Crespo — lekcje językowe 1 na 1",
    },
    "en": {
        "dir": "en",
        "locale": "en_GB",
        "title": "Paulo Crespo — Spanish lessons that get you speaking",
        "desc": (
            "One-to-one video lessons built around real conversation, for people "
            "who understand the language but freeze when they have to speak. "
            "First trial lesson at a reduced price."
        ),
        "img_alt": "Paulo Crespo — one-to-one language lessons",
    },
}

ES = {
    "locale": "es_ES",
    "title": "Paulo Crespo — Inglés para comunicar con confianza",
}


def hreflang_block() -> str:
    """Reciprocal alternates. Every variant lists every variant, itself
    included — Google ignores a one-way hreflang set."""
    rows = [
        f'<link rel="alternate" hreflang="es" href="{SITE}/">',
        f'<link rel="alternate" hreflang="pl" href="{SITE}/pl/">',
        f'<link rel="alternate" hreflang="en" href="{SITE}/en/">',
        f'<link rel="alternate" hreflang="x-default" href="{SITE}/">',
    ]
    return "\n".join(rows) + "\n"


def strip_existing(html: str) -> str:
    html = re.sub(r'<link rel="alternate" hreflang="[^"]*" href="[^"]*">\n?', "", html)
    return html


def make_variant(src: str, lang: str) -> str:
    cfg = LANGS[lang]
    out = strip_existing(src)

    out = out.replace('<html lang="es">', f'<html lang="{lang}">', 1)

    # Head strings the client-side translator never sees.
    out = re.sub(r"<title>.*?</title>", f"<title>{cfg['title']}</title>", out, count=1, flags=re.S)
    out = re.sub(
        r'<meta name="description" content=".*?">',
        f'<meta name="description" content="{cfg["desc"]}">',
        out, count=1, flags=re.S,
    )
    out = re.sub(
        r'<link rel="canonical" href="[^"]*">',
        f'<link rel="canonical" href="{SITE}/{cfg["dir"]}/">',
        out, count=1,
    )
    for prop, val in [
        ("og:url", f"{SITE}/{cfg['dir']}/"),
        ("og:title", cfg["title"]),
        ("og:description", cfg["desc"]),
        ("og:locale", cfg["locale"]),
        ("og:image:alt", cfg["img_alt"]),
    ]:
        out = re.sub(
            rf'<meta property="{re.escape(prop)}" content="[^"]*">',
            f'<meta property="{prop}" content="{val}">',
            out, count=1,
        )
    for name, val in [("twitter:title", cfg["title"]), ("twitter:description", cfg["desc"])]:
        out = re.sub(
            rf'<meta name="{re.escape(name)}" content="[^"]*">',
            f'<meta name="{name}" content="{val}">',
            out, count=1,
        )

    out = out.replace('<link rel="canonical"', hreflang_block() + '<link rel="canonical"', 1)

    # Pin the language. Without this the page would read localStorage and could
    # render Polish body copy at /en/, contradicting its own canonical.
    # Matches both the original localStorage form and the already-pinned form,
    # so the script stays idempotent across repeated runs.
    out, n = re.subn(
        r"let currentLang = (?:localStorage\.getItem\('site_lang'\) \|\| 'es'|'[a-z]{2}');"
        r"(?:\s*\n\s*try \{ localStorage\.setItem\('site_lang', '[a-z]{2}'\); \} catch \(e\) \{\})?",
        f"let currentLang = '{lang}'; // pinned: this URL *is* the {lang} homepage\n"
        f"try {{ localStorage.setItem('site_lang', '{lang}'); }} catch (e) {{}}",
        out, count=1,
    )
    if n != 1:
        raise SystemExit(f"could not pin language for {lang} (matched {n})")

    # These files sit one directory down, so bare relative paths would resolve
    # to /pl/cuenta.html and 404.
    def absolutise(m):
        attr, url = m.group(1), m.group(2)
        if re.match(r"^(https?:|//|#|/|mailto:|tel:|data:)", url):
            return m.group(0)
        return f'{attr}="/{url}"'

    out = re.sub(r'\b(href|src)="([^"]+)"', absolutise, out)
    return out


def rewrite_switcher(html: str) -> str:
    """Point the language buttons at the per-language URLs. Same markup in all
    three files, so whichever page you are on, the other two are one click and
    one real navigation away."""
    old = re.search(
        r'<span class="lang-switcher">.*?</span>', html, re.S
    )
    if not old:
        raise SystemExit("lang-switcher not found")
    new = (
        '<span class="lang-switcher">\n'
        '        <button onclick="goLang(\'es\', \'/\')" id="lang-btn-es" class="lang-btn">ES</button>\n'
        '        <button onclick="goLang(\'pl\', \'/pl/\')" id="lang-btn-pl" class="lang-btn">PL</button>\n'
        '        <button onclick="goLang(\'en\', \'/en/\')" id="lang-btn-en" class="lang-btn">EN</button>\n'
        '      </span>'
    )
    html = html[: old.start()] + new + html[old.end():]

    if "function goLang(" not in html:
        html = html.replace(
            "function setLang(lang) {",
            "// The homepage exists at three URLs, so switching language is a real\n"
            "// navigation. The choice is still persisted, so the rest of the site\n"
            "// (cuenta, legal, blog — all single-URL) follows along.\n"
            "function goLang(lang, url) {\n"
            "  try { localStorage.setItem('site_lang', lang); } catch (e) {}\n"
            "  window.location.href = url;\n"
            "}\n\n"
            "function setLang(lang) {",
            1,
        )
    return html


def main() -> int:
    src_path = ROOT / "index.html"
    src = src_path.read_text(encoding="utf-8")

    # The Spanish root needs the same hreflang set and the same switcher.
    es = strip_existing(src)
    es = es.replace('<link rel="canonical"', hreflang_block() + '<link rel="canonical"', 1)
    es = rewrite_switcher(es)

    # Pin the root to Spanish too. It previously read localStorage, so once a
    # visitor had been to /pl/ the Spanish URL rendered Polish body copy —
    # directly contradicting its own canonical and hreflang. Now that each URL
    # *is* a language, the root is Spanish unconditionally.
    es = es.replace(
        "let currentLang = localStorage.getItem('site_lang') || 'es';",
        "let currentLang = 'es'; // pinned: this URL *is* the Spanish homepage\n"
        "try { localStorage.setItem('site_lang', 'es'); } catch (e) {}",
        1,
    )
    src_path.write_text(es, encoding="utf-8")
    print(f"index.html         hreflang + switcher + pinned (es, {ES['locale']})")

    for lang, cfg in LANGS.items():
        out = make_variant(es, lang)
        d = ROOT / cfg["dir"]
        d.mkdir(exist_ok=True)
        (d / "index.html").write_text(out, encoding="utf-8")
        print(f"{cfg['dir']}/index.html      generated ({lang})")

    return 0


if __name__ == "__main__":
    sys.exit(main())
