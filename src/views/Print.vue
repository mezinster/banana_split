<template>
  <div>
    <section class="card">
      <header class="card__header">
        <h2 class="card__title">
          {{ $t('printTitle') }}
          <span v-if="title" class="card__subtitle">
            {{ $t('combineFor') }} <em>{{ title }}</em>
          </span>
        </h2>
      </header>

      <div class="step">
        <span class="step__num">1</span>
        <div class="step__body">
          <div class="step__title">
            {{ $t('printShardsQuestion') }}
          </div>
          <label class="field-label" for="totalShards">{{ $t('printShardsLabel') }}</label>
          <NumberStepper
            v-model="requiredShards"
            input-id="totalShards"
            :min="3"
            :max="255"
            :disabled="numberEntered"
          />
          <button
            v-if="!numberEntered"
            id="generateBtn"
            type="button"
            class="btn btn--primary btn--block print-action"
            @click="handleShardsInput"
          >
            {{ $t('printImportButton') }}
          </button>
        </div>
      </div>

      <hr class="divider" />

      <div class="step" :class="{ 'is-pending': !numberEntered }">
        <span class="step__num" :class="{ 'is-pending': !numberEntered }">2</span>
        <div class="step__body">
          <div class="step__title">
            {{ $t('stepScanShards') }}
          </div>
          <template v-if="numberEntered">
            <div class="progress">
              <div class="progress__text">
                {{ $t('combineProgress', { scanned: shards.length, required: requiredShards }) }}
              </div>
              <div v-if="requiredShards <= 24" class="progress__bar">
                <span
                  v-for="n in requiredShards"
                  :key="n"
                  class="progress__seg"
                  :class="{ 'is-filled': n <= shards.length }"
                />
              </div>
            </div>
            <ShardInput v-if="needMoreShards" @decode="onDecode" />
            <div v-if="needMoreShards" class="qr-strip">
              <qriously
                v-for="code in qrCodes"
                :key="code"
                class="qr-thumb"
                :value="code"
                :size="200"
              />
              <qriously
                v-for="n in remainingCodes"
                :key="'remaining-' + n"
                class="qr-thumb is-remaining"
                :value="PLACEHOLDER_QR_DATA"
                :size="200"
              />
            </div>
          </template>
        </div>
      </div>

      <hr class="divider" />

      <div class="step" :class="{ 'is-pending': !readyToPrint }">
        <span class="step__num" :class="{ 'is-pending': !readyToPrint }">3</span>
        <div class="step__body">
          <div class="step__title">
            {{ $t('tabPrint') }}
          </div>
          <button
            v-if="readyToPrint"
            id="printBtn"
            type="button"
            class="btn btn--primary btn--block"
            @click="print"
          >
            {{ $t('createPrintButton') }}
          </button>
        </div>
      </div>
    </section>

    <p class="print-note">
      {{ $t('printNote') }}
    </p>

    <template v-if="readyToPrint">
      <shard-info
        v-for="(code, i) in Array.from(qrCodes)"
        :key="code"
        :shard="code"
        :required-shards="parseInt(requiredShards/2)+2"
        :title="title"
        :index="i + 1"
        :total="qrCodes.size"
      />
    </template>
  </div>
</template>

<script lang="ts">
import crypto, { Shard } from "../util/crypto";
import ShardInfo from "../components/ShardInfo.vue";
import ShardInput from "../components/ShardInput.vue";
import NumberStepper from "../components/NumberStepper.vue";

import Vue from "vue";

type PrintData = {
  title: string;
  nonce: string;
  shards: Shard[];
  qrCodes: Set<string>;
  requiredShards?: number;
  numberEntered: boolean;
  PLACEHOLDER_QR_DATA: string;
};

export default Vue.extend({
  name: "Print",
  components: { ShardInfo, ShardInput, NumberStepper },
  data(): PrintData {
    return {
      title: "",
      nonce: "",
      shards: [],
      qrCodes: new Set(),
      requiredShards: undefined,
      numberEntered: false,
      PLACEHOLDER_QR_DATA: ""
    };
  },
  computed: {
    readyToPrint(): boolean {
      return this.numberEntered && !this.needMoreShards;
    },
    needMoreShards(): boolean {
      return this.requiredShards !== undefined && this.shards.length !== this.requiredShards;
    },
    remainingCodes(): number {
      if (!this.requiredShards) {
        return 0;
      } else {
        return this.requiredShards - this.shards.length;
      }
    }
  },
  mounted: function() {
    this.$eventHub.$emit("foldGeneralInfo");
    this.$eventHub.$emit("clearAlerts");
  },
  methods: {
    onDecode: function(result: string): string | void {
      this.$eventHub.$emit("clearAlerts");
      if (result === "") {
        return;
      }
      if (this.qrCodes.has(result)) {
        return;
      }
      let parsed;
      try {
        parsed = crypto.parse(result);
      } catch (error) {
        this.$eventHub.$emit("showError", error);
        return;
      }

      if (this.title && this.title !== parsed.title) {
        this.$eventHub.$emit("showError", this.$t('errorTitleMismatch'));
        return;
      } else {
        this.title = parsed.title;
      }
      if (this.nonce && this.nonce !== parsed.nonce) {
        this.$eventHub.$emit("showError", this.$t('errorNonceMismatch'));
        return;
      } else {
        this.nonce = parsed.nonce;
      }
      this.qrCodes.add(result);
      this.shards.push(parsed);
    },
    print: function() {
      window.print();
    },
    handleShardsInput: function() {
      if (this.requiredShards && this.requiredShards >= 3 && this.requiredShards <= 255) {
        this.numberEntered = true;
      } else {
        this.$eventHub.$emit("showError", this.$t('printInvalidShards'));
      }
    },
    toggleMode: function() {
      this.numberEntered = !this.numberEntered;
    }
  }
});
</script>

<style>
.print-action {
  margin-top: 16px;
}
.print-note {
  margin: 0 0 16px;
  padding: 12px 16px;
  font-size: 0.875rem;
  color: var(--text-secondary);
  background: var(--surface-muted);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-card);
}
</style>
