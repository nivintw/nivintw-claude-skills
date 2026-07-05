<!--
SPDX-FileCopyrightText: © 2026 Tyler Nivin
SPDX-License-Identifier: MIT
-->

# Embedding casts on a static site

The recording half produces `.cast` files. This half plays them on a web page
with [asciinema-player](https://github.com/asciinema/asciinema-player), vendored
locally so the site stays dependency-free (no CDN, no build step).

## 1. Vendor the player

Fetch the player JS + CSS from npm into your assets dir. Pin the version.

```bash
V=3.10.0
curl -fsSL "https://cdn.jsdelivr.net/npm/asciinema-player@$V/dist/bundle/asciinema-player.min.js" -o assets/asciinema-player.min.js
curl -fsSL "https://cdn.jsdelivr.net/npm/asciinema-player@$V/dist/bundle/asciinema-player.css"    -o assets/asciinema-player.css
```

The global is `window.AsciinemaPlayer`; the API is `AsciinemaPlayer.create(src, el, opts)`.

## 2. Markup

Load the CSS in `<head>` and the JS before your init script. Each cast is a
mount element carrying its source and intended size:

```html
<link rel="stylesheet" href="assets/asciinema-player.css" />
...
<figure class="cast">
  <div class="cast__player"
       data-cast="casts/fco.cast" data-cols="92" data-rows="22"
       aria-label="Recorded terminal demo of the fco command"></div>
  <figcaption><code>fco</code> — fuzzy-checkout any branch.</figcaption>
</figure>
...
<script src="assets/asciinema-player.min.js"></script>
<script src="assets/main.js"></script>
```

## 3. Init script

Hydrate every mount. Guarding on `window.AsciinemaPlayer` means pages that don't
load the player script are unaffected, and a failed script load degrades to the
CSS fallback below instead of throwing.

```js
const mounts = document.querySelectorAll(".cast__player[data-cast]");
if (mounts.length && window.AsciinemaPlayer) {
  mounts.forEach(function (el) {
    const opts = { theme: "asciinema", fit: "width", controls: true };
    const cols = el.getAttribute("data-cols");
    const rows = el.getAttribute("data-rows");
    if (cols) opts.cols = Number(cols);
    if (rows) opts.rows = Number(rows);
    try {
      window.AsciinemaPlayer.create(el.getAttribute("data-cast"), el, opts);
    } catch (e) {
      console.warn("asciinema player failed for", el.getAttribute("data-cast"), e);
    }
  });
}
```

Useful `opts`: `autoPlay`, `loop`, `speed`, `idleTimeLimit`, `poster: "npt:0:03"`
(freeze-frame thumbnail), `terminalFontFamily` (match your site's mono font — a
Nerd Font if your casts use glyphs).

## 4. Graceful fallback (no JS / failed load)

Style the container and show a hint until the player hydrates. The `:empty`
selector matches before the player injects its DOM, then stops matching once it
does:

```css
.cast { border: 1px solid var(--border); border-radius: 12px; overflow: hidden; }
.cast figcaption { padding: 0.7rem 1.1rem; border-top: 1px solid var(--border); color: var(--muted); }
.cast__player:empty::before {
  content: "▶ terminal cast — enable JavaScript to play";
  display: block; padding: 2.2rem 1.1rem; text-align: center; color: var(--muted);
}
```

## 5. Licensing (REUSE-compliant repos)

asciinema-player is **Apache-2.0** (© Marcin Kulik & contributors), not your
project's license. If you run [REUSE](https://reuse.software/):

- Add `LICENSES/Apache-2.0.txt` (`reuse download Apache-2.0`).
- Annotate the vendored files in `REUSE.toml` as Apache-2.0 (don't let a header
  tool stamp your own license onto them):

  ```toml
  [[annotations]]
  path = ["**/asciinema-player.min.js", "**/asciinema-player.css"]
  SPDX-FileCopyrightText = "© Marcin Kulik and asciinema-player contributors"
  SPDX-License-Identifier = "Apache-2.0"
  ```

- `.cast` files are JSON-lines with a leading JSON object — no comment syntax, so
  annotate `**/*.cast` in `REUSE.toml` too (as your own copyright/license).
- If you use a header tool (e.g. hawkeye), exclude the vendored player and the
  `.cast` files from it so it doesn't try to insert headers.

## 6. MkDocs wiring

On an MkDocs Material site the mechanics above are the same — vendor the player, drop the
same `<figure class="cast">` mount markup, run the same init script — only *where things are
declared* changes, since MkDocs owns the page shell instead of hand-authored HTML:

- **Vendor under `docs/assets/`** (`docs_dir`'s conventional asset path), not a bespoke
  `assets/` dir.
- **Wire the CSS/JS via `mkdocs.yml`**, not a per-page `<link>`/`<script>` tag — MkDocs
  injects these into every page's `<head>`/end-of-body itself:

  ```yaml
  extra_css:
    - assets/asciinema-player.css
  extra_javascript:
    - assets/asciinema-player.min.js
    - assets/main.js
  ```

- **Markup stays identical** — raw HTML passes through Markdown unmodified, so the same
  `<figure class="cast">…</figure>` block from step 2 drops straight into a `.md` page with
  no change.
- **The init script itself is unchanged** *unless* the theme has `navigation.instant`
  enabled (Material's SPA-style page-swap navigation). A `DOMContentLoaded` listener only
  fires once per full page load, so it never re-fires after an instant-nav swap and casts on
  a page you navigate *to* (not the first page loaded) silently fail to hydrate. Swap the
  guard to Material's `document$` observable, which fires on every instant-nav swap too:

  ```js
  document$.subscribe(function () {
    const mounts = document.querySelectorAll(".cast__player[data-cast]");
    if (mounts.length && window.AsciinemaPlayer) {
      mounts.forEach(function (el) {
        const opts = { theme: "asciinema", fit: "width", controls: true };
        // ...same as step 3
        window.AsciinemaPlayer.create(el.getAttribute("data-cast"), el, opts);
      });
    }
  });
  ```

  If `navigation.instant` is off, the plain `DOMContentLoaded` version from step 3 is
  simpler and sufficient — only switch when that feature is actually enabled.
