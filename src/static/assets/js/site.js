// MirraNET website behaviour: language switch, copy button and project info.
// projects.json is generated at deploy time by scripts/sync-projects.sh, so
// visitors never contact the GitHub API directly.

(function () {
  "use strict";

  const LANG = document.documentElement.lang === "de" ? "de" : "en";
  const BASE = document.documentElement.dataset.base || "";

  const STRINGS = {
    de: {
      version: (v) => `Version ${v}`,
      released: (d) => `veröffentlicht ${d}`,
      updated: (d) => `aktualisiert ${d}`,
      inDev: "In Entwicklung",
      copied: "Kopiert",
      locale: "de-DE",
    },
    en: {
      version: (v) => `Version ${v}`,
      released: (d) => `released ${d}`,
      updated: (d) => `updated ${d}`,
      inDev: "In development",
      copied: "Copied",
      locale: "en-GB",
    },
  };
  const T = STRINGS[LANG];

  // ---------- Language switcher ----------
  // Remember an explicit choice so the automatic detection in <head>
  // doesn't send the visitor back.
  document.querySelectorAll("[data-set-lang]").forEach((link) => {
    link.addEventListener("click", () => {
      try { localStorage.setItem("mirranet-lang", link.dataset.setLang); } catch (_) { /* private mode */ }
      if (location.hash) link.href = link.href.split("#")[0] + location.hash;
    });
  });

  // ---------- Copy button ----------
  document.querySelectorAll("[data-copy]").forEach((btn) => {
    const label = btn.textContent;
    btn.addEventListener("click", async () => {
      const code = btn.parentElement.querySelector("code");
      if (!code) return;
      try {
        await navigator.clipboard.writeText(code.textContent);
        btn.textContent = T.copied;
        setTimeout(() => { btn.textContent = label; }, 1800);
      } catch (_) { /* clipboard not available */ }
    });
  });

  // ---------- Project info ----------
  // "3 days ago" style dates, falling back to a plain date for older ones.
  function relative(iso) {
    const then = new Date(iso);
    if (isNaN(then)) return "";
    const days = Math.round((Date.now() - then.getTime()) / 86400000);
    if (days > 60 || !("RelativeTimeFormat" in Intl)) {
      return then.toLocaleDateString(T.locale, { day: "numeric", month: "long", year: "numeric" });
    }
    const rtf = new Intl.RelativeTimeFormat(T.locale, { numeric: "auto" });
    if (days < 1) return rtf.format(0, "day");
    if (days < 14) return rtf.format(-days, "day");
    return rtf.format(-Math.round(days / 7), "week");
  }

  async function initProjects() {
    if (!document.querySelector("[data-version], [data-updated]")) return;
    let info = null;
    try {
      const res = await fetch(`${BASE}projects.json`, { cache: "no-cache" });
      if (res.ok) info = await res.json();
    } catch (_) { /* the page works without it */ }
    if (!info) return;

    document.querySelectorAll("[data-version]").forEach((el) => {
      const p = info[el.dataset.version];
      if (!p) return;
      const parts = [];
      if (p.release && p.release.tag) {
        parts.push(T.version(p.release.tag.replace(/^v/i, "")));
        if (p.release.published_at) parts.push(T.released(relative(p.release.published_at)));
      } else {
        parts.push(T.inDev);
        if (p.pushed_at) parts.push(T.updated(relative(p.pushed_at)));
      }
      el.innerHTML = '<span class="dot" aria-hidden="true"></span>';
      el.append(parts.join(" · "));
    });

    document.querySelectorAll("[data-updated]").forEach((el) => {
      const p = info[el.dataset.updated];
      if (!p) return;
      const parts = [p.language || el.textContent.trim()];
      if (p.release && p.release.tag) parts.push(p.release.tag);
      if (p.pushed_at) parts.push(T.updated(relative(p.pushed_at)));
      el.textContent = parts.join(" · ");
    });
  }

  initProjects();
})();
