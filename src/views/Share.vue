<template>
  <div>
    <section class="card">
      <header class="card__header">
        <h2 class="card__title">
          {{ $t('createTitle') }}
        </h2>
      </header>

      <div class="step">
        <span class="step__num">1</span>
        <div class="step__body">
          <label class="field-label" for="secretTitle">{{ $t('createNameLabel') }}</label>
          <input
            id="secretTitle"
            v-model="title"
            class="input"
            type="text"
            :disabled="encryptionMode"
            :placeholder="$t('createNameHint')"
            autofocus
          />
        </div>
      </div>

      <div class="step">
        <span class="step__num">2</span>
        <div class="step__body">
          <label class="field-label" for="secret">{{ $t('createSecretLabel') }}</label>
          <textarea
            id="secret"
            v-model="secret"
            class="input"
            :class="{ 'is-invalid': secretTooLong }"
            :disabled="encryptionMode"
            :placeholder="$t('createSecretHint')"
          />
          <span v-if="secret.length > 0" :class="secretTooLong ? 'error-text' : 'caption'">
            {{ $t('createCharCounter', { remaining: 1024 - secret.length }) }}
          </span>
        </div>
      </div>

      <div class="step">
        <span class="step__num">3</span>
        <div class="step__body">
          <span class="field-label">{{ $t('createShardsLabel') }}</span>
          <div class="shards-row">
            <span>{{ $t('createShardsRequire') }}</span>
            <NumberStepper
              v-model="requiredShards"
              input-id="requiredShards"
              :min="2"
              :max="totalShardsBound"
              :disabled="encryptionMode"
            />
            <span>{{ $t('createShardsOutOf') }}</span>
            <NumberStepper
              v-model="totalShards"
              input-id="totalShards"
              :min="3"
              :max="255"
              :disabled="encryptionMode"
            />
            <span>{{ $t('createShardsReconstruct') }}</span>
          </div>
          <span v-if="shardsInvalid" class="error-text">
            {{ $t('createShardsInvalid') }}
          </span>
        </div>
      </div>

      <div class="step">
        <span class="step__num">4</span>
        <div class="step__body">
          <span class="field-label">{{ $t('createPassphraseLabel') }}</span>
          <div v-if="!useManualPassphrase" class="passphrase-field">
            <canvas-text :text="recoveryPassphrase" />
            <button
              type="button"
              class="btn btn--icon"
              :title="$t('createPassphraseRegenerate')"
              :aria-label="$t('createPassphraseRegenerate')"
              :disabled="encryptionMode"
              @click="regenPassphrase"
            >
              <svg viewBox="0 0 24 24" aria-hidden="true" class="icon-stroke">
                <path d="M3 12a9 9 0 1 0 3-6.7L3 8" />
                <path d="M3 3v5h5" />
              </svg>
            </button>
          </div>
          <div v-else>
            <input
              id="manualPassphrase"
              v-model="recoveryPassphrase"
              class="input input--mono"
              :class="{ 'is-invalid': passphraseTooShort && recoveryPassphrase.length > 0 }"
              type="text"
              autocomplete="off"
              :disabled="encryptionMode"
              :placeholder="$t('createPassphraseHint')"
            />
            <span v-if="passphraseTooShort" class="error-text">
              {{ $t('createPassphraseTooShort') }}
            </span>
          </div>
          <div class="segmented passphrase-mode" role="group" :aria-label="$t('createPassphraseLabel')">
            <button
              type="button"
              class="segmented__item"
              :class="{ 'is-active': !useManualPassphrase }"
              :aria-pressed="String(!useManualPassphrase)"
              :disabled="encryptionMode"
              @click="setManualPassphrase(false)"
            >
              {{ $t('createPassphraseAuto') }}
            </button>
            <button
              id="customPassphraseToggle"
              type="button"
              class="segmented__item"
              :class="{ 'is-active': useManualPassphrase }"
              :aria-pressed="String(useManualPassphrase)"
              :disabled="encryptionMode"
              @click="setManualPassphrase(true)"
            >
              {{ $t('createPassphraseManual') }}
            </button>
          </div>
        </div>
      </div>

      <button
        v-if="!encryptionMode"
        id="generateBtn"
        type="button"
        class="btn btn--primary btn--block generate-btn"
        :disabled="secretTooLong || passphraseTooShort || shardsInvalid"
        @click="toggleMode"
      >
        {{ $t('createGenerateButton') }}
      </button>
    </section>

    <section v-if="encryptionMode" class="card result-card">
      <header class="card__header">
        <h2 class="card__title">
          {{ $t('createResultTitle') }}
        </h2>
      </header>
      <div class="print-row">
        <button id="printBtn" type="button" class="btn btn--primary" @click="print">
          {{ $t('createPrintButton') }}
        </button>
        <select v-model="printLocale" class="print-locale-select" :aria-label="$t('tabPrint')">
          <option value="en">
            🇬🇧
          </option>
          <option value="ru">
            🇷🇺
          </option>
          <option value="tr">
            🇹🇷
          </option>
          <option value="be">
            🇧🇾
          </option>
          <option value="ka">
            🇬🇪
          </option>
          <option value="uk">
            🇺🇦
          </option>
          <option value="pl">
            🇵🇱
          </option>
          <option value="es">
            🇪🇸
          </option>
          <option value="it">
            🇮🇹
          </option>
        </select>
      </div>
      <button
        id="backToEditBtn"
        type="button"
        class="btn btn--secondary btn--block"
        @click="toggleMode"
      >
        {{ $t('createBackButton') }}
      </button>
      <shard-info
        v-for="(shard, i) in shards"
        :key="shard"
        :shard="shard"
        :required-shards="requiredShards"
        :title="title"
        :locale="printLocale"
        :index="i + 1"
        :total="shards.length"
      />
    </section>
  </div>
</template>

<script lang="ts">
import passPhrase from "../util/passPhrase";
import crypto from "../util/crypto";

import ShardInfo from "../components/ShardInfo.vue";
import CanvasText from "../components/CanvasText.vue";
import NumberStepper from "../components/NumberStepper.vue";
import Vue from "vue";

type ShareData = {
  title: string;
  secret: string;
  totalShards: number;
  requiredShards: number;
  recoveryPassphrase: string;
  useManualPassphrase: boolean;
  encryptionMode: boolean;
  printLocale: string;
};

export default Vue.extend({
  name: "Share",
  components: { ShardInfo, CanvasText, NumberStepper },
  data(): ShareData {
    return {
      title: "",
      secret: "",
      totalShards: 3,
      requiredShards: 2,
      recoveryPassphrase: "",
      useManualPassphrase: false,
      encryptionMode: false,
      printLocale: ""
    };
  },
  computed: {
    secretTooLong(): boolean {
      return this.secret.length > 1024;
    },
    passphraseTooShort(): boolean {
      return this.useManualPassphrase && this.recoveryPassphrase.length < 8;
    },
    totalShardsBound(): number {
      return typeof this.totalShards === "number" && this.totalShards >= 2
        ? Math.min(this.totalShards, 255)
        : 255;
    },
    shardsInvalid(): boolean {
      return this.totalShards < 3 || this.totalShards > 255 ||
        this.requiredShards < 2 || this.requiredShards > this.totalShards ||
        !Number.isInteger(this.totalShards) || !Number.isInteger(this.requiredShards);
    },
    shards(): string[] {
      this.$eventHub.$emit("clearAlerts");
      if (!this.encryptionMode) {
        return [];
      }
      try {
        return crypto.share(
          this.secret,
          this.title,
          this.recoveryPassphrase,
          this.totalShards,
          this.requiredShards
        );
      } catch (error) {
        this.$eventHub.$emit("showError", error);
        this.toggleMode(); // back to editing
      }
      return [];
    }
  },
  watch: {
    totalShards(newVal: number) {
      this.requiredShards = Math.floor(newVal / 2) + 1;
    }
  },
  created: function() {
    this.regenPassphrase();
    this.printLocale = this.$i18n.locale;
  },
  mounted: function() {
    this.$eventHub.$emit("foldGeneralInfo");
    this.$eventHub.$emit("clearAlerts");
  },
  methods: {
    regenPassphrase: function() {
      if (process.env.NODE_ENV === "test") {
        this.recoveryPassphrase = "TEST";
        return;
      }
      this.recoveryPassphrase = passPhrase.generate(4);
    },
    print: function() {
      window.print();
    },
    toggleMode: function() {
      this.encryptionMode = !this.encryptionMode;
    },
    setManualPassphrase: function(manual: boolean) {
      if (this.useManualPassphrase === manual) {
        return;
      }
      this.useManualPassphrase = manual;
      this.onPassphraseToggle();
    },
    onPassphraseToggle: function() {
      if (!this.useManualPassphrase) {
        this.regenPassphrase();
      } else {
        this.recoveryPassphrase = "";
      }
    }
  }
});
</script>

<style>
.shards-row {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px 10px;
}
.passphrase-field {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  min-height: 48px;
  padding: 4px 4px 4px 12px;
  background: var(--surface-muted);
  border: 1px solid var(--border);
  border-radius: var(--radius-ctl);
  color: var(--text);
  overflow: hidden;
}
.passphrase-field .canvasText {
  min-width: 0;
  max-width: 100%;
}
.passphrase-mode {
  margin-top: 12px;
}
.icon-stroke {
  fill: none;
  stroke: currentColor;
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}
.generate-btn {
  margin-top: 28px;
}
.result-card {
  margin-bottom: 12px;
}
.print-row {
  display: flex;
  gap: 8px;
  margin-bottom: 12px;
}
.print-row .btn {
  flex: 1;
}
.print-locale-select {
  min-height: 48px;
  min-width: 64px;
  padding: 0 8px;
  font-size: 1.25rem;
  color: var(--text);
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius-ctl);
  cursor: pointer;
}
</style>
