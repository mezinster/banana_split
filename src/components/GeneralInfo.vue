<template>
  <div class="general-info">
    <details class="explainer" open>
      <summary class="explainer__summary">
        <h2>{{ $t('infoWhatIsThis') }}</h2>
        <svg class="explainer__chevron" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 9l6 6 6-6" /></svg>
      </summary>
      <div class="explainer__body">
        <i18n path="infoWhatIsThisBody" tag="p">
          <template #link>
            <a href="https://en.wikipedia.org/wiki/Shamir%27s_Secret_Sharing" target="_blank" rel="noopener noreferrer">
              {{ $t('infoShamirLink') }}
            </a>
          </template>
        </i18n>
      </div>
    </details>

    <details class="explainer">
      <summary class="explainer__summary">
        <h2>{{ $t('infoHowDoesItWork') }}</h2>
        <svg class="explainer__chevron" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 9l6 6 6-6" /></svg>
      </summary>
      <div class="explainer__body">
        <p>{{ $t('infoHowBody1') }}</p>
        <p>{{ $t('infoHowBody2') }}</p>
        <p>{{ $t('infoHowBody3') }}</p>
        <p>{{ $t('infoHowBody4') }}</p>
      </div>
    </details>

    <details class="explainer">
      <summary class="explainer__summary">
        <h2>{{ $t('infoHowToUse') }}</h2>
        <svg class="explainer__chevron" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 9l6 6 6-6" /></svg>
      </summary>
      <div class="explainer__body">
        <ol class="how-to">
          <li v-for="(key, i) in steps" :key="key" class="step">
            <span class="step__num">{{ i + 1 }}</span>
            <span class="step__body">{{ $t(key) }}</span>
          </li>
        </ol>
      </div>
    </details>
  </div>
</template>

<script lang="ts">
import Vue from "vue";

export default Vue.extend({
  name: "GeneralInfo",
  data() {
    return { steps: ["infoStep1", "infoStep2", "infoStep3"] };
  }
});
</script>

<style>
.general-info {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.explainer {
  background: var(--surface);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-card);
  overflow: hidden;
}
.explainer__summary {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 16px 20px;
  cursor: pointer;
  list-style: none;
  user-select: none;
}
.explainer__summary::-webkit-details-marker {
  display: none;
}
.explainer__summary h2 {
  font-size: 1.125rem;
  font-weight: 600;
}
.explainer__chevron {
  flex-shrink: 0;
  width: 20px;
  height: 20px;
  fill: none;
  stroke: var(--text-muted);
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
  transition: transform 0.2s ease-out;
}
.explainer[open] .explainer__chevron {
  transform: rotate(180deg);
}
.explainer__body {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 16px 20px 20px;
  font-size: 0.9375rem;
  line-height: 1.6;
  color: var(--text-secondary);
  border-top: 1px solid var(--border-light);
}
.how-to {
  margin: 0;
  padding: 0;
  list-style: none;
}
.how-to .step + .step {
  margin-top: 12px;
}
</style>
