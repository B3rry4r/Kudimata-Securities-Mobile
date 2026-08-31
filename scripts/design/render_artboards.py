#!/usr/bin/env python3
"""Render design artboards to real PNGs, so a screen can be compared to its design.

Until this existed, "matches the artboard" was an opinion. An agent looked at a
screenshot of the app, read the artboard's HTML *source*, and judged. Picture on
one side, code on the other. That is not a comparison, and it is how an entire
tab shipped un-built while every report said the design was covered.

    python3 render_artboards.py                      # every artboard
    python3 render_artboards.py s51 s22              # only these
    python3 render_artboards.py --canvas path/to/canvas   # explicit location

Run it from the repo root. The canvas directory is discovered (any folder
containing .dc.html files), or given with --canvas / $DESIGN_CANVAS_DIR.

Output: build/design_shots/<id>.png, at phone width, ready to sit beside
build/shots/<screen>__light.png.

HOW, and why it is done the hard way
------------------------------------
The obvious approach — cut the artboard's <div> out and render it alone —
produces a half-render, and a half-render is worse than none because someone
will compare against it. Two things break:

  * The canvas loads its design system and illustrations from RELATIVE paths
    (`_ds/<id>/_ds_bundle.js`, `./support.js`, `assets/...`). Move the HTML
    somewhere else and every one of those 404s.
  * `support.js` is a runtime that walks the DOM and renders `<x-import>`
    elements into real components. Extracting a subtree drops the bootstrap it
    needs, so every icon silently disappears — the text still renders, which is
    exactly what makes it deceptive.

So this renders the ORIGINAL file, unmodified, in place. A copy is written beside
it with one <style> block appended that hides everything except the target
artboard and pins it to the origin. `visibility` rather than `display` — display
collapses the layout the runtime has already computed. The copy is deleted after.
"""

from __future__ import annotations

import os
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path.cwd()
OUT = ROOT / "build/design_shots"


def find_canvas() -> pathlib.Path | None:
    """Locate the canvas directory instead of assuming its name.

    The first version of this script hardcoded one project's folder
    (`docs/design/redesign-2026-08`), which worked in exactly that repo and
    silently rendered nothing anywhere else. A tool that only runs where it was
    written is not a tool.

    Order: an explicit --canvas argument, then $DESIGN_CANVAS_DIR, then the
    shallowest directory under the repo that actually contains .dc.html files.
    """
    args = sys.argv[1:]
    if "--canvas" in args:
        return pathlib.Path(args[args.index("--canvas") + 1]).resolve()
    env = os.environ.get("DESIGN_CANVAS_DIR")
    if env:
        return pathlib.Path(env).resolve()
    found = sorted(
        {f.parent for f in ROOT.rglob("*.dc.html") if ".git" not in f.parts},
        key=lambda d: len(d.parts),
    )
    return found[0] if found else None
CHROME = next((c for c in ("google-chrome", "chromium", "chromium-browser")
               if subprocess.run(["which", c], capture_output=True).returncode == 0), None)

ISOLATE = """
<style id="__artboard_isolate">
  html, body {{ background: #fff !important; }}
  body * {{ visibility: hidden !important; }}
  #{aid}, #{aid} * {{ visibility: visible !important; }}
  #{aid} {{ position: absolute !important; top: 0 !important; left: 0 !important;
            margin: 0 !important; z-index: 2147483647 !important; }}
</style>
"""


def main() -> int:
    if not CHROME:
        print("no chrome/chromium on PATH - cannot render", file=sys.stderr)
        return 2

    argv = sys.argv[1:]
    if "--canvas" in argv:
        i = argv.index("--canvas")
        argv = argv[:i] + argv[i + 2:]
    wanted = set(argv)

    canvas = find_canvas()
    if canvas is None or not canvas.is_dir():
        print("no .dc.html canvas found. Pass --canvas <dir> or set "
              "DESIGN_CANVAS_DIR.", file=sys.stderr)
        return 2
    OUT.mkdir(parents=True, exist_ok=True)
    rendered, failed = 0, []

    for f in sorted(canvas.glob("*.dc.html")):
        src = f.read_text(errors="replace")
        ids = [m.group(1) for m in re.finditer(r'id="(s\d+[a-z]*)"', src)]
        for aid in dict.fromkeys(ids):
            if wanted and aid not in wanted:
                continue
            style = ISOLATE.format(aid=aid)
            page = (src.replace("</body>", style + "</body>", 1)
                    if "</body>" in src else src + style)
            # Beside the original, so every relative path still resolves.
            tmp = f.with_name(f"_render_{aid}.html")
            tmp.write_text(page)
            png = OUT / f"{aid}.png"
            try:
                subprocess.run(
                    [CHROME, "--headless=new", "--disable-gpu", "--no-sandbox",
                     "--hide-scrollbars", "--window-size=430,1500",
                     # support.js registers components at runtime; without this
                     # the shot catches the page mid-render and loses its icons.
                     "--virtual-time-budget=10000",
                     f"--screenshot={png}", str(tmp)],
                    capture_output=True, timeout=180)
            finally:
                tmp.unlink(missing_ok=True)
            if png.exists() and png.stat().st_size > 0:
                rendered += 1
            else:
                failed.append(aid)

    print(f"rendered {rendered} artboard(s) into {OUT.relative_to(ROOT)}")
    if failed:
        # Never a silent skip. A missing render that nobody mentions becomes a
        # screen nobody compared, reported as a screen that matched.
        print(f"NOT RENDERED, so NOT verified: {', '.join(failed)}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
