<template>
  <div>
    <div class="card" :transparent="!encryptionMode">
      <h2 class="card-title">
        Create a secret split
      </h2>
      <p>
        <label>1. Name of your split</label>
        <input
          id="secretTitle"
          v-model="title"
          type="text"
          :disabled="encryptionMode"
          placeholder="Ex: 'My Bitcoin seed phrase'"
          autofocus
        />
      </p>
      <p>
        <label>2. Secret</label>
        <textarea
          id="secret"
          v-model="secret"
          :class="{ tooLong: secretTooLong }"
          :disabled="encryptionMode"
          placeholder="Your secret goes here"
        />
        <span v-if="secretTooLong" class="error-text">
          Inputs longer than 1024 characters make QR codes illegible
        </span>
      </p>
      <p>
        <label>3. Shards</label>
        <br />
        Will require any
        <input
          id="requiredShards"
          v-model.number="requiredShards"
          :disabled="encryptionMode"
          type="number"
          min="2"
          :max="totalShards"
        />
        shards out of
        <input
          id="totalShards"
          v-model.number="totalShards"
          :disabled="encryptionMode"
          type="number"
          min="3"
          max="255"
        />
        to reconstruct
      </p>
      <p>
        <label>4. Recovery passphrase</label>
        <div v-if="!useManualPassphrase" class="flex justify-between align-center">
          <canvas-text :text="recoveryPassphrase" />
          <button class="button-icon" @click="regenPassphrase" :disabled="encryptionMode">
            &#x21ba;
          </button>
        </div>
        <div v-else>
          <input
            id="manualPassphrase"
            v-model="recoveryPassphrase"
            type="text"
            :disabled="encryptionMode"
            placeholder="Enter passphrase (min 8 characters)"
          />
          <span v-if="passphraseTooShort" class="error-text">
            Passphrase must be at least 8 characters
          </span>
        </div>
        <label class="checkbox-label">
          <input
            type="checkbox"
            v-model="useManualPassphrase"
            :disabled="encryptionMode"
            @change="onPassphraseToggle"
          />
          Use custom passphrase
        </label>
      </p>
      <button
        id="generateBtn"
        class="button-card"
        :disabled="secretTooLong || passphraseTooShort"
        :hidden="encryptionMode"
        v-on:click="toggleMode"
      >
        Generate QR codes!
      </button>
      <button
        id="backToEditBtn"
        class="button-card"
        :disabled="secretTooLong"
        :hidden="!encryptionMode"
        v-on:click="toggleMode"
      >
        Back to editing data
      </button>
    </div>

    <div v-if="encryptionMode">
      <div class="card" transparent="true">
        <button id="printBtn" class="button-card" @click="print">
          Print us!
        </button>
        <shard-info
          v-for="shard in shards"
          :key="shard"
          :shard="shard"
          :required-shards="requiredShards"
          :title="title"
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
      encryptionMode: false
    };
  },
  computed: {
    secretTooLong(): boolean {
      return this.secret.length > 1024;
    },
    passphraseTooShort(): boolean {
      return this.useManualPassphrase && this.recoveryPassphrase.length < 8;
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
.checkbox-label {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 8px;
  cursor: pointer;
  font-weight: normal;
}
</style>
