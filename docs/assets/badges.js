/*
 * SPDX-FileCopyrightText: © 2026 Tyler Nivin
 * SPDX-License-Identifier: MIT
 */

/* Hydrates every [data-version] badge from window.PLUGIN_VERSIONS, populated by the
   docs/versions/<name>.js shims (each independently bumped by release-please — see those
   files). Wired via mkdocs.yml's extra_javascript, so this loads once site-wide instead of
   per-page. Re-runs on every instant-nav page swap too (not just first load), via Material's
   document$ observable, so a badge on a page you navigate *to* still hydrates. */
document$.subscribe(function () {
  var versions = window.PLUGIN_VERSIONS || {};
  document.querySelectorAll("[data-version]").forEach(function (el) {
    var v = versions[el.getAttribute("data-version")];
    if (v) { el.textContent = "v" + v; }
  });
});
