/*
 * SPDX-FileCopyrightText: © 2026 Tyler Nivin
 * SPDX-License-Identifier: MIT
 */

/* Interactivity for the nivintw-claude-skills docs site. Vanilla, no framework,
   no build step. Two features: a theme toggle (light/dark, persisted), and a
   command-palette search over the site-wide index in search-index.js. */
(function () {
  "use strict";

  /* ---- theme toggle ---------------------------------------------------- */
  var root = document.documentElement;
  var STORE = "ncs-theme";

  function systemTheme() {
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }
  function current() {
    return root.getAttribute("data-theme") || systemTheme();
  }
  function apply(theme) {
    root.setAttribute("data-theme", theme);
    var btn = document.querySelector(".theme-toggle");
    if (btn) {
      var dark = theme === "dark";
      btn.textContent = dark ? "☀ light" : "☾ dark";
      btn.setAttribute("aria-label", "Switch to " + (dark ? "light" : "dark") + " theme");
    }
  }
  try {
    var saved = localStorage.getItem(STORE);
    if (saved === "dark" || saved === "light") { apply(saved); }
  } catch (e) { /* private mode — fall back to system */ }

  document.addEventListener("click", function (e) {
    var btn = e.target.closest && e.target.closest(".theme-toggle");
    if (!btn) { return; }
    var next = current() === "dark" ? "light" : "dark";
    apply(next);
    try { localStorage.setItem(STORE, next); } catch (e2) { /* ignore */ }
  });

  // Reflect the active theme on the toggle's label at load.
  var initialBtn = document.querySelector(".theme-toggle");
  if (initialBtn) { apply(current()); }

  /* ---- copy buttons ---------------------------------------------------- */
  function legacyCopy(text) {
    var ta = document.createElement("textarea");
    ta.value = text;
    ta.setAttribute("readonly", "");
    ta.style.position = "absolute";
    ta.style.left = "-9999px";
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand("copy"); } catch (e) { /* ignore */ }
    document.body.removeChild(ta);
  }
  function flash(btn) {
    btn.classList.add("copied");
    btn.textContent = "copied ✓";
    setTimeout(function () {
      btn.classList.remove("copied");
      btn.textContent = "copy";
    }, 1500);
  }
  function copyText(text, btn) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(
        function () { flash(btn); },
        function () { legacyCopy(text); flash(btn); }
      );
    } else {
      legacyCopy(text);
      flash(btn);
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
  Array.prototype.forEach.call(document.querySelectorAll(".snippet"), function (snip) {
    addCopy(snip, function () { return snip.innerText.trim(); });
  });
  var termCmd = document.querySelector(".terminal .term-cmd");
  if (termCmd) {
    addCopy(termCmd.closest(".terminal"), function () { return termCmd.innerText.trim(); }, "term");
  }

  /* ---- command palette ------------------------------------------------- */
  var input = document.querySelector(".header-search input");
  var panel = document.querySelector(".palette");
  var index = window.SEARCH_INDEX || [];
  if (!input || !panel) { return; }

  function esc(s) {
    return s.replace(/[&<>"]/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c];
    });
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
    var hits = index.filter(function (m) {
      return (m.cmd + " " + m.plugin + " " + m.summary).toLowerCase().indexOf(q) !== -1;
    });
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
