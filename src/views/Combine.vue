<template>
  <div>
    <section class="card">
      <header class="card__header">
        <h2 class="card__title">
          {{ $t('combineTitle') }}
          <span v-if="title" class="card__subtitle">
            {{ $t('combineFor') }} <em>{{ title }}</em>
          </span>
        </h2>
      </header>

      <div class="step">
        <span class="step__num">1</span>
        <div class="step__body">
          <div class="step__title">
            {{ $t('stepScanShards') }}
          </div>
          <div v-if="requiredShards" class="progress">
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
          <div v-if="requiredShards" class="qr-strip">
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
        </div>
      </div>
    </section>

    <section class="card" :class="{ 'is-pending': needMoreShards }">
      <div class="step">
        <span class="step__num" :class="{ 'is-pending': needMoreShards }">2</span>
        <div v-if="!needMoreShards" class="step__body">
          <label class="field-label" for="passphrase">{{ $t('combinePassphraseLabel') }}</label>
          <input
            id="passphrase"
            v-model="passphrase"
            class="input input--mono"
            type="text"
            autocomplete="off"
            :placeholder="$t('combinePassphraseHint')"
            autofocus
            @keyup.enter="reconstruct"
          />
          <button
            v-if="!recoveredSecret"
            id="reconstructBtn"
            type="button"
            class="btn btn--primary btn--block combine-action"
            @click="reconstruct"
          >
            {{ $t('combineReconstructButton') }}
          </button>
          <label class="field-label combine-secret-label" for="recoveredSecret">{{ $t('combineSecretLabel') }}</label>
          <textarea
            v-if="recoveredSecret"
            id="recoveredSecret"
            v-model="recoveredSecret"
            class="input input--mono"
            readonly
          />
          <textarea v-else class="input input--mono" readonly disabled />
        </div>
        <div v-else class="step__body" aria-hidden="true">
          <span class="field-label">{{ $t('combinePassphraseLabel') }}</span>
          <input class="input" type="text" disabled tabindex="-1" :placeholder="$t('combinePassphraseHint')" />
          <button type="button" class="btn btn--primary btn--block combine-action" disabled tabindex="-1">
            {{ $t('combineReconstructButton') }}
          </button>
        </div>
      </div>
    </section>
  </div>
</template>

<script lang="ts">
import crypto, { Shard } from "../util/crypto";
import ShardInput from "../components/ShardInput.vue";
import Vue from "vue";

type CombineData = {
  title: string;
  nonce: string;
  shards: Shard[];
  qrCodes: Set<string>;
  requiredShards?: number;
  passphrase: string;
  recoveredSecret?: string;
  PLACEHOLDER_QR_DATA: string;
};

export default Vue.extend({
  name: "Combine",
  components: { ShardInput },
  data(): CombineData {
    return {
      title: "",
      nonce: "",
      shards: [],
      qrCodes: new Set(),
      requiredShards: undefined,
      passphrase: "",
      recoveredSecret: undefined,
      PLACEHOLDER_QR_DATA: ""
    };
  },
  computed: {
    needMoreShards(): boolean {
      return !this.requiredShards || this.shards.length < this.requiredShards;
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
        this.$eventHub.$emit("showWarn", this.$t('errorShardSeen'));
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
      if (
        this.requiredShards &&
        this.requiredShards !== parsed.requiredShards
      ) {
        this.$eventHub.$emit("showError", this.$t('errorRequiredMismatch'));
        return;
      } else {
        this.requiredShards = parsed.requiredShards;
      }
      this.qrCodes.add(result);
      this.shards.push(parsed);
    },
    reconstruct: function(): void {
      if (!this.passphrase) {
        return;
      }
      this.passphrase = this.passphrase
        .split(" ")
        .filter(el => el)
        .join("-");
      const shards = Array.from(this.shards);
      try {
        this.recoveredSecret = crypto.reconstruct(shards, this.passphrase);
      } catch (error) {
        this.$eventHub.$emit("showError", this.$t('errorDecryptionFailed'));
      }
    }
  }
});
</script>

<style>
.combine-action {
  margin-top: 12px;
}
.combine-secret-label {
  margin-top: 20px;
}
</style>
