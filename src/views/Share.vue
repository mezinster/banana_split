<template>
  <div>
    <div class="card" :transparent="!encryptionMode">
      <h2 class="card-title">
        {{ $t('createTitle') }}
      </h2>
      <p>
        <label>{{ $t('createNameLabel') }}</label>
        <input
          id="secretTitle"
          v-model="title"
          type="text"
          :disabled="encryptionMode"
          :placeholder="$t('createNameHint')"
          autofocus
        />
      </p>
      <p>
        <label>{{ $t('createSecretLabel') }}</label>
        <textarea
          id="secret"
          v-model="secret"
          :class="{ tooLong: secretTooLong }"
          :disabled="encryptionMode"
          :placeholder="$t('createSecretHint')"
        />
        <span v-if="secret.length > 0" :class="{ 'error-text': secretTooLong, 'char-counter': !secretTooLong }">
          {{ $t('createCharCounter', { remaining: 1024 - secret.length }) }}
        </span>
      </p>
      <p>
        <label>{{ $t('createShardsLabel') }}</label>
        <br />
        {{ $t('createShardsRequire') }}
        <input
          id="requiredShards"
          v-model.number="requiredShards"
          :disabled="encryptionMode"
          type="number"
          min="2"
          :max="totalShards"
        />
        {{ $t('createShardsOutOf') }}
        <input
          id="totalShards"
          v-model.number="totalShards"
          :disabled="encryptionMode"
          type="number"
          min="3"
          max="255"
        />
        {{ $t('createShardsReconstruct') }}
        <span v-if="shardsInvalid" class="error-text">
          <br />{{ $t('createShardsInvalid') }}
        </span>
      </p>
      <div class="form-group">
        <label>{{ $t('createPassphraseLabel') }}</label>
        <div v-if="!useManualPassphrase" class="flex justify-between align-center">
          <canvas-text :text="recoveryPassphrase" />
          <button class="button-icon" :disabled="encryptionMode" @click="regenPassphrase">
            &#x21ba;
          </button>
        </div>
        <div v-else>
          <input
            id="manualPassphrase"
            v-model="recoveryPassphrase"
            type="text"
            :disabled="encryptionMode"
            :placeholder="$t('createPassphraseHint')"
          />
          <span v-if="passphraseTooShort" class="error-text">
            {{ $t('createPassphraseTooShort') }}
          </span>
        </div>
        <label class="checkbox-label">
          <input
            v-model="useManualPassphrase"
            type="checkbox"
            :disabled="encryptionMode"
            @change="onPassphraseToggle"
          />
          {{ $t('createPassphraseCustom') }}
        </label>
      </div>
      <button
        id="generateBtn"
        class="button-card"
        :disabled="secretTooLong || passphraseTooShort || shardsInvalid"
        :hidden="encryptionMode"
        v-on:click="toggleMode"
      >
        {{ $t('createGenerateButton') }}
      </button>
      <button
        id="backToEditBtn"
        class="button-card"
        :disabled="secretTooLong"
        :hidden="!encryptionMode"
        v-on:click="toggleMode"
      >
        {{ $t('createBackButton') }}
      </button>
    </div>

    <div v-if="encryptionMode">
      <div class="card" transparent="true">
        <div class="flex align-center" style="gap: 8px; margin-bottom: 8px;">
          <button id="printBtn" class="button-card" @click="print">
            {{ $t('createPrintButton') }}
          </button>
          <select v-model="printLocale" class="print-locale-select">
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
          </select>
        </div>
        <shard-info
          v-for="shard in shards"
          :key="shard"
          :shard="shard"
          :required-shards="requiredShards"
          :title="title"
          :locale="printLocale"
        />
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import passPhrase from "../util/passPhrase";
import crypto from "../util/crypto";

import ShardInfo from "../components/ShardInfo.vue";
import CanvasText from "../components/CanvasText.vue";
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
  components: { ShardInfo, CanvasText },
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
textarea.tooLong {
  border: 5px solid red;
}
input[type="number"] {
  width: 64px;
  text-align: center;
}
.error-text {
  color: red;
}
.char-counter {
  color: gray;
  font-size: 0.85em;
}
.form-group {
  margin: 1em 0;
}
.checkbox-label {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 10px;
  margin-top: 4px;
  cursor: pointer;
  font-size: 1.6rem;
  font-weight: 400;
  color: var(--c_text-secondary);
}
.print-locale-select {
  width: auto;
  padding: 0.5rem;
  font-size: 2rem;
  border: 1px solid var(--c_border-main);
  border-radius: 0.5rem;
  background: var(--c_bg-card);
  cursor: pointer;
}
</style>
