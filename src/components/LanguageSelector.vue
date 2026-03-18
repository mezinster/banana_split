<template>
  <div class="language-selector">
    <button class="language-trigger" :title="currentLabel" @click="open = !open">
      {{ currentFlag }}
    </button>
    <ul v-if="open" class="language-dropdown">
      <li
        v-for="locale in locales"
        :key="locale.code"
        class="language-option"
        :class="{ active: locale.code === $i18n.locale }"
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
  { code: "uk", flag: "🇺🇦", name: "Українська" }
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
  font-size: 2.4rem;
  background: transparent;
  border: none;
  padding: 0.5rem;
  cursor: pointer;
  line-height: 1;
}
.language-dropdown {
  position: absolute;
  right: 0;
  top: 100%;
  background: var(--c_bg-card);
  border: 1px solid var(--c_border-main);
  border-radius: 0.5rem;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  list-style: none;
  margin: 0.25rem 0 0;
  padding: 0.25rem 0;
  z-index: 1000;
  min-width: 180px;
}
.language-option {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.6rem 1rem;
  cursor: pointer;
  font-size: 1.6rem;
  white-space: nowrap;
}
.language-option:hover {
  background: var(--c_bg-app);
}
.language-option.active {
  font-weight: 600;
}
.language-flag {
  font-size: 2rem;
}
@media print {
  .language-selector {
    display: none;
  }
}
</style>
