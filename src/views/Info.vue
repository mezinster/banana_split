<template>
  <div class="info">
    <section class="info-hero">
      <h1 class="display">
        {{ $t('infoTagline') }}
      </h1>
      <p class="trust-badge">
        <svg viewBox="0 0 24 24" aria-hidden="true">
          <rect x="4" y="11" width="16" height="10" rx="2" />
          <path d="M8 11V7a4 4 0 0 1 8 0v4" />
        </svg>
        <span>{{ $t('infoMinimalRisk') }}</span>
      </p>
    </section>

    <nav class="action-list">
      <router-link
        v-for="action in actions"
        :id="action.id"
        :key="action.id"
        class="action-card"
        :to="action.to"
      >
        <span class="action-card__icon" aria-hidden="true">{{ action.icon }}</span>
        <span class="action-card__text">
          <span class="action-card__title">{{ $t(action.title) }}</span>
          <span class="action-card__desc">{{ $t(action.desc) }}</span>
        </span>
        <svg class="action-card__chevron" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M9 6l6 6-6 6" />
        </svg>
      </router-link>
    </nav>

    <GeneralInfo />
  </div>
</template>

<script lang="ts">
import GeneralInfo from "../components/GeneralInfo.vue";
import Vue from "vue";

const ACTIONS = [
  { id: "shareNav", to: "/share", icon: "✂️", title: "tabCreate", desc: "infoCreateDesc" },
  { id: "combineNav", to: "/combine", icon: "🔍", title: "tabRestore", desc: "infoRestoreDesc" },
  { id: "printNav", to: "/print", icon: "🖨️", title: "tabPrint", desc: "infoPrintDesc" }
];

export default Vue.extend({
  name: "Info",
  components: { GeneralInfo },
  data() {
    return { actions: ACTIONS };
  }
});
</script>

<style>
.info-hero {
  padding: 8px 0 24px;
}
.trust-badge {
  display: flex;
  align-items: flex-start;
  gap: 8px;
  margin-top: 12px;
  padding: 12px 16px;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--accent);
  background: var(--accent-soft);
  border-radius: var(--radius-card);
}
.trust-badge svg {
  flex-shrink: 0;
  width: 18px;
  height: 18px;
  margin-top: 1px;
  fill: none;
  stroke: currentColor;
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}
.action-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-bottom: 32px;
}
.action-card {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 20px;
  color: var(--text);
  text-decoration: none;
  background: var(--surface);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-card);
  box-shadow: var(--shadow-card);
  transition: border-color 0.15s ease-out, transform 0.15s ease-out;
}
.action-card:hover {
  border-color: var(--border);
}
.action-card:active {
  transform: scale(0.99);
}
.action-card__icon {
  flex-shrink: 0;
  width: 48px;
  height: 48px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 1.5rem;
  background: var(--emphasis);
  border-radius: var(--radius-ctl);
}
.action-card__text {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.action-card__title {
  font-size: 1.125rem;
  font-weight: 600;
  letter-spacing: -0.01em;
}
.action-card__desc {
  font-size: 0.875rem;
  color: var(--text-secondary);
}
.action-card__chevron {
  flex-shrink: 0;
  width: 20px;
  height: 20px;
  fill: none;
  stroke: var(--text-muted);
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}
</style>
