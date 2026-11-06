<template>
  <div v-if="message" class="alert" :class="level" role="alert">
    <p class="alert__text">
      {{ message }}
    </p>
  </div>
</template>

<script lang="ts">
import Vue from "vue";

// This is a false positive. Suppress eslint error.
/* eslint-disable no-unused-vars */
enum AlertLevel {
  Error = "error",
  Warn = "warn"
}
/* eslint-enable no-unused-vars */

type AlertData = {
  message: string | null;
  level: AlertLevel;
};

export default Vue.extend({
  name: "Alert",
  data: function(): AlertData {
    return {
      message: null,
      level: AlertLevel.Error
    };
  },
  created: function() {
    this.$eventHub.$on("showError", (text: string) => {
      this.level = AlertLevel.Error;
      this.message = text;
    });
    this.$eventHub.$on("showWarn", (text: string) => {
      this.level = AlertLevel.Warn;
      this.message = text;
    });
    this.$eventHub.$on("clearAlerts", () => {
      this.message = null;
    });
  }
});
</script>

<style>
.alert {
  margin: 8px 0;
  padding: 12px 16px;
  font-size: 0.9375rem;
  border: 1px solid;
  border-radius: var(--radius-card);
}
.alert.warn {
  color: var(--warn);
  background: var(--warn-bg);
  border-color: var(--warn-border);
}
.alert.error {
  color: var(--danger);
  background: var(--danger-bg);
  border-color: var(--danger-border);
}
.alert__text {
  margin: 0;
}
</style>
