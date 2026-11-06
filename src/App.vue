<template>
  <div class="app-root">
    <div id="app" class="measure">
      <header class="app-header">
        <router-link id="logo" to="/" class="logo">
          <span class="logo-text">{{ $t('appTitle') }}</span>
          <span class="logo-icon" aria-hidden="true">🍌</span>
        </router-link>
        <LanguageSelector />
      </header>
      <Alert />
      <main>
        <router-view />
      </main>
    </div>
    <div id="print" class="measure" />
    <footer class="app-footer measure">
      <ForkMe url="https://github.com/mezinster/banana_split" />
      <div class="version-footer">
        {{ gitRevision }}
      </div>
    </footer>
  </div>
</template>

<script lang="ts">
import Alert from "./components/Alert.vue";
import ForkMe from "./components/ForkMe.vue";
import LanguageSelector from "./components/LanguageSelector.vue";

import Vue from "vue";

export default Vue.extend({
  name: "App",
  components: { Alert, ForkMe, LanguageSelector },
  computed: {
    gitRevision: function() {
      return process.env.GIT_REVISION;
    }
  },
  watch: {
    "$i18n.locale"(newLocale: string) {
      document.documentElement.lang = newLocale;
      this.syncLangQuery(newLocale);
    }
  },
  created() {
    document.documentElement.lang = this.$i18n.locale;
    this.syncLangQuery(this.$i18n.locale);
  },
  methods: {
    syncLangQuery(lang: string) {
      var query = Object.assign({}, this.$route.query);
      if (query.lang !== lang) {
        query.lang = lang;
        this.$router.replace({ query: query }).catch(function() {});
      }
    }
  }
});
</script>

<style>
/* ---------- Tokens (see .superdesign/design-system.md) ---------- */
:root {
  --bg: #f2f1f0;
  --surface: #fff;
  --surface-muted: #f7f6f5;
  --text: #222;
  --text-secondary: #606060;
  --text-muted: #8a8a8a;
  --border: #d6d6d6;
  --border-light: #ebebeb;
  --emphasis: #353535;
  --emphasis-hover: #000;
  --on-emphasis: #fff;
  --accent: #ff1864;
  --accent-soft: #ffe3ec;
  --success: #2e7d32;
  --success-bg: #e8f5e9;
  --warn: #8b6400;
  --warn-bg: #ffe7b3;
  --warn-border: #e8b173;
  --danger: #b3261e;
  --danger-bg: #ffdad6;
  --danger-border: #e87f73;
  --shadow-card: 0 1px 2px rgba(0, 0, 0, 0.06), 0 8px 24px rgba(0, 0, 0, 0.06);
  --radius-card: 12px;
  --radius-ctl: 10px;
  --w-app: 620px;
  --gutter: 16px;
  --f-main: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica,
    Arial, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol";
  --f-mono: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  color-scheme: light;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #161616;
    --surface: #222;
    --surface-muted: #2a2a2a;
    --text: #eee;
    --text-secondary: #b0b0b0;
    --text-muted: #8a8a8a;
    --border: #3a3a3a;
    --border-light: #2f2f2f;
    --emphasis: #f2f1f0;
    --emphasis-hover: #fff;
    --on-emphasis: #161616;
    --accent-soft: #3d1422;
    --success: #81c784;
    --success-bg: #1b2e1c;
    --warn: #ffd27a;
    --warn-bg: #3a2e12;
    --warn-border: #6b5520;
    --danger: #ffb4ab;
    --danger-bg: #3d1a17;
    --danger-border: #7a2e27;
    --shadow-card: none;
    color-scheme: dark;
  }
}

/* ---------- Base ---------- */
* {
  box-sizing: border-box;
}
html {
  font-family: var(--f-main);
  font-size: 16px;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
body {
  margin: 0;
  color: var(--text);
  background: var(--bg);
  font-size: 1rem;
  line-height: 1.5;
}
.measure {
  width: 100%;
  max-width: var(--w-app);
  margin-left: auto;
  margin-right: auto;
  padding-left: var(--gutter);
  padding-right: var(--gutter);
}
h1,
h2,
h3 {
  margin: 0;
  letter-spacing: -0.02em;
}
p {
  margin: 0;
}
a {
  color: var(--accent);
}
:focus-visible {
  outline: 2px solid var(--accent);
  outline-offset: 2px;
}
[hidden] {
  display: none !important;
}

/* ---------- Header / footer ---------- */
.app-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 56px;
  margin-top: 8px;
}
.logo {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  font-size: 1.25rem;
  font-weight: 700;
  letter-spacing: -0.02em;
  color: var(--text);
  text-decoration: none;
}
.logo:hover .logo-text {
  text-decoration: underline;
}
.logo-icon {
  font-size: 1.5rem;
}
main {
  padding-bottom: 8px;
}
.app-footer {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding-top: 24px;
  padding-bottom: 32px;
}
.version-footer {
  font-size: 0.8125rem;
  font-style: italic;
  color: var(--text-muted);
}

/* ---------- Typography helpers ---------- */
.display {
  font-size: 1.75rem;
  line-height: 1.2;
  font-weight: 600;
}
.caption {
  display: block;
  margin-top: 6px;
  font-size: 0.8125rem;
  color: var(--text-muted);
}
.error-text {
  display: block;
  margin-top: 6px;
  font-size: 0.8125rem;
  color: var(--danger);
}
.field-label {
  display: block;
  margin-bottom: 6px;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--text-secondary);
}

/* ---------- Card ---------- */
.card {
  margin: 8px 0 16px;
  padding: 16px;
  background: var(--surface);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);
}
.card.is-pending {
  opacity: 0.5;
}
.card__header {
  margin: 0 0 16px;
  padding-bottom: 12px;
  border-bottom: 1px solid var(--border-light);
}
.card__title {
  font-size: 1.375rem;
  line-height: 1.3;
  font-weight: 600;
}
.card__subtitle {
  font-weight: 400;
}

/* ---------- Steps ---------- */
.step {
  display: flex;
  gap: 12px;
}
.step + .step {
  margin-top: 24px;
}
.step__num {
  flex-shrink: 0;
  width: 24px;
  height: 24px;
  margin-top: 1px;
  border-radius: 50%;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
  font-weight: 600;
  background: var(--accent);
  color: #fff;
}
.step__num.is-pending {
  background: transparent;
  border: 1px solid var(--border);
  color: var(--text-muted);
}
.step__body {
  flex: 1;
  min-width: 0;
}
.step__title {
  margin-bottom: 12px;
  font-weight: 600;
}
.step.is-pending .step__title {
  color: var(--text-muted);
}
.divider {
  border: 0;
  border-top: 1px solid var(--border-light);
  margin: 20px 0;
}

/* ---------- Inputs ---------- */
.input {
  display: block;
  width: 100%;
  min-height: 48px;
  padding: 12px;
  font-family: var(--f-main);
  font-size: 1rem;
  color: var(--text);
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-ctl);
  transition: border-color 0.15s ease-out, box-shadow 0.15s ease-out;
}
.input::placeholder {
  color: var(--text-muted);
}
.input:focus {
  outline: none;
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-soft);
}
.input.is-invalid {
  border-color: var(--danger);
}
.input:disabled,
.input[readonly] {
  background: var(--surface-muted);
}
.input:disabled {
  opacity: 0.6;
}
textarea.input {
  min-height: 120px;
  resize: vertical;
}
.input--mono {
  font-family: var(--f-mono);
  font-size: 0.9375rem;
}
input[type="checkbox"] {
  accent-color: var(--accent);
}

/* ---------- Buttons ---------- */
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  min-height: 48px;
  padding: 12px 20px;
  font-family: var(--f-main);
  font-size: 1rem;
  font-weight: 600;
  line-height: 1.25;
  text-align: center;
  text-decoration: none;
  border-radius: var(--radius-ctl);
  border: 1px solid transparent;
  cursor: pointer;
  transition: background-color 0.15s ease-out, border-color 0.15s ease-out,
    color 0.15s ease-out;
}
.btn--primary {
  background: var(--emphasis);
  color: var(--on-emphasis);
}
.btn--primary:hover:not(:disabled) {
  background: var(--emphasis-hover);
}
.btn--secondary {
  background: var(--surface);
  color: var(--text);
  border-color: var(--border);
}
.btn--secondary:hover:not(:disabled) {
  border-color: var(--text-secondary);
}
.btn--block {
  display: flex;
  width: 100%;
}
.btn--icon {
  min-height: 40px;
  width: 40px;
  padding: 0;
  background: transparent;
  color: var(--text-secondary);
  border-radius: 50%;
}
.btn--icon:hover:not(:disabled) {
  color: var(--text);
  background: var(--surface);
}
.btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}
.btn svg {
  width: 20px;
  height: 20px;
  flex-shrink: 0;
}

/* ---------- Segmented control ---------- */
.segmented {
  display: flex;
  gap: 4px;
  padding: 4px;
  background: var(--surface-muted);
  border: 1px solid var(--border-light);
  border-radius: 999px;
}
.segmented__item {
  flex: 1;
  min-height: 36px;
  padding: 6px 10px;
  font-family: var(--f-main);
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--text-secondary);
  background: transparent;
  border: none;
  border-radius: 999px;
  cursor: pointer;
}
.segmented__item.is-active {
  background: var(--surface);
  color: var(--text);
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.12);
}
.segmented__item:disabled {
  cursor: not-allowed;
  opacity: 0.5;
}

/* ---------- Progress ---------- */
.progress {
  margin-bottom: 16px;
}
.progress__text {
  margin-bottom: 8px;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--text-secondary);
}
.progress__bar {
  display: flex;
  gap: 6px;
  height: 6px;
}
.progress__seg {
  flex: 1;
  border-radius: 999px;
  background: var(--border);
  transition: background-color 0.2s ease-out;
}
.progress__seg.is-filled {
  background: var(--accent);
}

/* ---------- QR thumbnails (scan progress) ---------- */
.qr-strip {
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: 8px;
  margin-top: 16px;
}
.qr-thumb {
  display: inline-flex;
  padding: 6px;
  background: #fff;
  border: 1px solid var(--border);
  border-radius: var(--radius-card);
}
.qr-thumb canvas {
  display: block;
  width: 72px;
  height: 72px;
}
.qr-thumb:not(.is-remaining) {
  animation: unblur 0.6s ease-out;
}
.qr-thumb.is-remaining {
  border-style: dashed;
}
.qr-thumb.is-remaining canvas {
  filter: blur(4px);
  opacity: 0.4;
}
/* Scan-progress thumbnails only. Never animate the generated .qr-tile: the
   E2E test screenshots it immediately and any filter frame breaks decoding. */
@keyframes unblur {
  0% {
    filter: brightness(150%);
  }
  100% {
    filter: none;
  }
}

/* ---------- On-screen shard grid (#print holds ShardQrCode tiles) ---------- */
#print:empty {
  display: none;
}
@media screen {
  #print {
    display: grid;
    grid-template-columns: repeat(2, minmax(0, 1fr));
    gap: 12px;
  }
}
@media screen and (min-width: 560px) {
  #print {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}

@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation: none !important;
    transition: none !important;
  }
}

/* ---------- Print ---------- */
@media print {
  body {
    background: #fff;
    color: #000;
  }
  #app,
  .app-footer {
    display: none;
  }
  #print {
    display: block;
    width: auto;
    max-width: none;
    padding: 0;
  }
}
</style>
