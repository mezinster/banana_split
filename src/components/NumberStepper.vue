<template>
  <div class="stepper" :class="{ 'is-disabled': disabled }">
    <button
      type="button"
      class="stepper__btn"
      :aria-label="$t('stepperDecrease')"
      :disabled="disabled || !canDecrease"
      @click="step(-1)"
    >
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14" /></svg>
    </button>
    <input
      :id="inputId"
      class="stepper__input"
      type="number"
      inputmode="numeric"
      :value="value"
      :min="min"
      :max="max"
      :disabled="disabled"
      @input="onInput"
    />
    <button
      type="button"
      class="stepper__btn"
      :aria-label="$t('stepperIncrease')"
      :disabled="disabled || !canIncrease"
      @click="step(1)"
    >
      <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14" /></svg>
    </button>
  </div>
</template>

<script lang="ts">
import Vue from "vue";

// v-model-compatible numeric stepper. Emits a number when the field parses,
// otherwise the raw string, so callers' Number.isInteger validation still
// catches an empty or half-typed field instead of silently clamping it.
export default Vue.extend({
  name: "NumberStepper",
  props: {
    value: {
      type: [Number, String],
      default: ""
    },
    min: {
      type: Number,
      required: true
    },
    max: {
      type: Number,
      required: true
    },
    disabled: {
      type: Boolean,
      default: false
    },
    inputId: {
      type: String,
      default: undefined
    }
  },
  computed: {
    numeric(): number | null {
      return typeof this.value === "number" && isFinite(this.value) ? this.value : null;
    },
    canDecrease(): boolean {
      return this.numeric === null || this.numeric > this.min;
    },
    canIncrease(): boolean {
      return this.numeric === null || this.numeric < this.max;
    }
  },
  methods: {
    step(delta: number) {
      var next = this.numeric === null ? this.min : this.numeric + delta;
      this.$emit("input", Math.min(this.max, Math.max(this.min, next)));
    },
    onInput(event: Event) {
      var raw = (event.target as HTMLInputElement).value;
      var parsed = Number(raw);
      this.$emit("input", raw !== "" && isFinite(parsed) ? parsed : raw);
    }
  }
});
</script>

<style>
.stepper {
  display: inline-flex;
  align-items: stretch;
  height: 44px;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-ctl);
  overflow: hidden;
}
.stepper.is-disabled {
  opacity: 0.6;
}
.stepper__btn {
  width: 40px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0;
  background: transparent;
  border: none;
  color: var(--text-secondary);
  cursor: pointer;
}
.stepper__btn:hover:not(:disabled) {
  background: var(--surface-muted);
  color: var(--text);
}
.stepper__btn:disabled {
  opacity: 0.35;
  cursor: not-allowed;
}
.stepper__btn svg {
  width: 18px;
  height: 18px;
  fill: none;
  stroke: currentColor;
  stroke-width: 2;
  stroke-linecap: round;
}
.stepper__input {
  width: 52px;
  padding: 0 4px;
  font-family: var(--f-main);
  font-size: 1rem;
  font-weight: 600;
  text-align: center;
  color: var(--text);
  background: transparent;
  border: none;
  border-left: 1px solid var(--border-light);
  border-right: 1px solid var(--border-light);
  -moz-appearance: textfield;
}
.stepper__input::-webkit-outer-spin-button,
.stepper__input::-webkit-inner-spin-button {
  -webkit-appearance: none;
  margin: 0;
}
.stepper__input:focus {
  outline: none;
  background: var(--accent-soft);
}
</style>
