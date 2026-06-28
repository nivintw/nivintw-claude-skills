/*
 * SPDX-FileCopyrightText: © 2026 Tyler Nivin
 * SPDX-License-Identifier: MIT
 */

/* Interactivity for the nivintw-claude-skills docs site. Vanilla, no framework,
   no build step. Three features: a theme toggle (light/dark, persisted), copy
   buttons on command blocks, and a command-palette search over the site-wide
   index in search-index.js. */
(function () {
  "use strict";

  /* ---- theme toggle ---------------------------------------------------- */
  var root = document.documentElement;
  var STORE = "ncs-theme";
  var darkMQ = window.matchMedia("(prefers-color-scheme: dark)");

  function systemTheme() { return darkMQ.matches ? "dark" : "light"; }
  function current() { return root.getAttribute("data-theme") || systemTheme(); }

  function setToggleLabel(theme) {
    var btn = document.querySelector(".theme-toggle");
    if (!btn) { return; }
    var dark = theme === "dark";
    btn.textContent = dark ? "☀ light" : "☾ dark";
    btn.setAttribute("aria-label", "Switch to " + (dark ? "light" : "dark") + " theme");
  }
  function apply(theme) {
    root.setAttribute("data-theme", theme);
    setToggleLabel(theme);
  }

  var saved = null;
  try { saved = localStorage.getItem(STORE); } catch (e) { /* private mode */ }
  if (saved === "dark" || saved === "light") {
    apply(saved); // an explicit choice wins over the CSS prefers-color-scheme rule
  } else {
    setToggleLabel(current()); // no choice: let CSS drive colors, just label the toggle
  }

  document.addEventListener("click", function (e) {
    var btn = e.target.closest && e.target.closest(".theme-toggle");
    if (!btn) { return; }
    var next = current() === "dark" ? "light" : "dark";
    apply(next);
    try { localStorage.setItem(STORE, next); } catch (e2) { /* ignore */ }
  });

  // Keep the toggle label honest if the OS theme flips and no explicit choice is set.
  function onSystemThemeChange() {
    if (!root.getAttribute("data-theme")) { setToggleLabel(current()); }
  }
  if (darkMQ.addEventListener) {
    darkMQ.addEventListener("change", onSystemThemeChange);
  } else if (darkMQ.addListener) {
    darkMQ.addListener(onSystemThemeChange); // Safari < 14 has no addEventListener here
  }

  /* ---- copy buttons ---------------------------------------------------- */
  function legacyCopy(text) {
    var ta = document.createElement("textarea");
    ta.value = text;
    ta.setAttribute("readonly", "");
    ta.style.position = "absolute";
    ta.style.left = "-9999px";
    document.body.appendChild(ta);
    ta.select();
    var ok = false;
    try { ok = document.execCommand("copy"); } catch (e) { ok = false; }
    document.body.removeChild(ta);
    return ok;
  }
  function flash(btn, ok) {
    btn.classList.toggle("copied", ok);
    btn.textContent = ok ? "copied ✓" : "copy failed";
    setTimeout(function () {
      btn.classList.remove("copied");
      btn.textContent = "copy";
    }, 1500);
  }
  function copyText(text, btn) {
    // Only show success when the copy actually happened — never a false "copied ✓".
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(
        function () { flash(btn, true); },
        function () { flash(btn, legacyCopy(text)); }
      );
    } else {
      flash(btn, legacyCopy(text));
    }
  }
  function addCopy(el, getText, variant) {
    var wrap = document.createElement("div");
    wrap.className = "copy-wrap" + (variant ? " copy-wrap--" + variant : "");
    el.parentNode.insertBefore(wrap, el);
    wrap.appendChild(el);
    var btn = document.createElement("button");
    btn.type = "button";
    btn.className = "copy-btn";
    btn.textContent = "copy";
    btn.setAttribute("aria-label", "Copy to clipboard");
    btn.addEventListener("click", function () { copyText(getText(), btn); });
    wrap.appendChild(btn);
  }
  document.querySelectorAll(".snippet").forEach(function (snip) {
    addCopy(snip, function () { return snip.innerText.trim(); });
  });
  document.querySelectorAll(".terminal").forEach(function (term) {
    var cmd = term.querySelector(".term-cmd");
    if (cmd) { addCopy(term, function () { return cmd.innerText.trim(); }, "term"); }
  });

  /* ---- version badges -------------------------------------------------- */
  // Version numbers are never hard-coded in the pages. Each plugin ships a tiny
  // versions/<name>.js shim that release-please bumps on release; here we fill every
  // [data-version] badge from the merged window.PLUGIN_VERSIONS map. Loading the shims as
  // <script> (not fetch) is what keeps this working from a file:// path with no server.
  var versions = window.PLUGIN_VERSIONS || {};
  document.querySelectorAll("[data-version]").forEach(function (el) {
    var v = versions[el.getAttribute("data-version")];
    if (v) { el.textContent = "v" + v; }
  });

  /* ---- command palette ------------------------------------------------- */
  var ESC = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" };
  var input = document.querySelector(".header-search input");
  var panel = document.querySelector(".palette");
  var index = window.SEARCH_INDEX || [];
  if (!input || !panel) { return; }

  // Precompute one lowercased haystack per command so search doesn't rebuild it per keystroke.
  index.forEach(function (m) {
    m.haystack = (m.cmd + " " + m.plugin + " " + m.summary).toLowerCase();
  });

  function esc(s) {
    return s.replace(/[&<>"]/g, function (c) { return ESC[c]; });
  }

  function render(matches) {
    if (!matches.length) {
      panel.innerHTML = '<p class="p-empty">No commands match.</p>';
      panel.classList.add("open");
      return;
    }
    panel.innerHTML = matches.map(function (m) {
      return '<a href="' + esc(m.url) + '">' +
        '<span class="p-cmd">' + esc(m.cmd) + "</span>" +
        '<span class="p-sum">' + esc(m.summary) + "</span></a>";
    }).join("");
    panel.classList.add("open");
  }

  function search(q) {
    q = q.trim().toLowerCase();
    if (!q) { panel.classList.remove("open"); panel.innerHTML = ""; return; }
    var hits = index.filter(function (m) { return m.haystack.indexOf(q) !== -1; });
    render(hits);
  }

  input.addEventListener("input", function () { search(input.value); });
  input.addEventListener("focus", function () { if (input.value.trim()) { search(input.value); } });

  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape") { panel.classList.remove("open"); input.blur(); }
    // "/" focuses the palette, the way a terminal would.
    if (e.key === "/" && document.activeElement !== input) {
      e.preventDefault();
      input.focus();
    }
  });
  document.addEventListener("click", function (e) {
    if (!e.target.closest || !e.target.closest(".header-search")) {
      panel.classList.remove("open");
    }
  });
})();
