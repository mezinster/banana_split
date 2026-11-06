<template>
  <div class="language-selector">
    <button
      type="button"
      class="language-trigger"
      :title="currentLabel"
      :aria-label="currentLabel"
      aria-haspopup="listbox"
      :aria-expanded="String(open)"
      @click="open = !open"
    >
      {{ currentFlag }}
    </button>
    <ul v-if="open" class="language-dropdown" role="listbox">
      <li
        v-for="locale in locales"
        :key="locale.code"
        class="language-option"
        role="option"
        tabindex="0"
        :aria-selected="String(locale.code === $i18n.locale)"
        :class="{ active: locale.code === $i18n.locale }"
        @keydown.enter.prevent="selectLocale(locale.code)"
        @keydown.space.prevent="selectLocale(locale.code)"
        @click="selectLocale(locale.code)"
      >
        <span class="language-flag">{{ locale.flag }}</span>
        <span class="language-name">{{ locale.name }}</span>
      </li>
    </ul>
  </div>
</template>

<script lang="ts">
import Vue from "vue";

const LOCALES = [
  { code: "en", flag: "🇬🇧", name: "English" },
  { code: "ru", flag: "🇷🇺", name: "Русский" },
  { code: "tr", flag: "🇹🇷", name: "Türkçe" },
  { code: "be", flag: "🇧🇾", name: "Беларуская" },
  { code: "ka", flag: "🇬🇪", name: "ქართული" },
  { code: "uk", flag: "🇺🇦", name: "Українська" },
  { code: "pl", flag: "🇵🇱", name: "Polski" },
  { code: "es", flag: "🇪🇸", name: "Español" },
  { code: "it", flag: "🇮🇹", name: "Italiano" }
];

export default Vue.extend({
  name: "LanguageSelector",
  data() {
    return {
      open: false,
      locales: LOCALES
    };
  },
  computed: {
    currentFlag(): string {
      const current = LOCALES.find(l => l.code === this.$i18n.locale);
      return current ? current.flag : LOCALES[0].flag;
    },
    currentLabel(): string {
      const current = LOCALES.find(l => l.code === this.$i18n.locale);
      return current ? current.name : "English";
    }
  },
  mounted() {
    document.addEventListener("click", this.handleClickOutside);
  },
  beforeDestroy() {
    document.removeEventListener("click", this.handleClickOutside);
  },
  methods: {
    selectLocale(code: string) {
      this.$i18n.locale = code;
      this.open = false;
    },
    handleClickOutside(event: Event) {
      const el = this.$el as HTMLElement;
      if (!el.contains(event.target as Node)) {
        this.open = false;
      }
    }
  }
});
</script>

<style>
.language-selector {
  position: relative;
  display: inline-block;
}
.language-trigger {
  width: 40px;
  height: 40px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0;
  font-size: 1.5rem;
  line-height: 1;
  background: transparent;
  border: none;
  border-radius: 50%;
  cursor: pointer;
}
.language-trigger:hover {
  background: var(--surface);
}
.language-dropdown {
  position: absolute;
  right: 0;
  top: calc(100% + 4px);
  z-index: 1000;
  min-width: 200px;
  margin: 0;
  padding: 4px;
  list-style: none;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-card);
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.15);
}
.language-option {
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 44px;
  padding: 8px 12px;
  font-size: 0.9375rem;
  white-space: nowrap;
  border-radius: 8px;
  cursor: pointer;
}
.language-option:hover,
.language-option:focus {
  outline: none;
  background: var(--surface-muted);
}
.language-option.active {
  font-weight: 600;
}
.language-flag {
  font-size: 1.25rem;
}
@media print {
  .language-selector {
    display: none;
  }
}
</style>
