<template>
  <div class="qr-tile">
    <div class="print-only">
      <h1>{{ title }}</h1>
      <h3>{{ needMoreText }}</h3>
    </div>
    <qriously class="qr-code print-only" :value="shard" :size="600" />
    <qriously class="screen-only card-qr" :value="shard" :size="200" />
    <div class="print-only">
      <div class="recovery-field">
        <div class="recovery-title">
          {{ $t('shardRecoveryPassphrase', effectiveLocale) }}&nbsp;
        </div>
        <div class="recovery-blank" />
      </div>
      <p class="version">
        {{ $t('shardDownloadPrompt', effectiveLocale, { link: 'nfcarchiver.com/banana' }) }}
        <br />
        {{ $t('shardVersionInfo', effectiveLocale, { version: gitRevision }) }}
      </p>
    </div>
  </div>
</template>

<script lang="ts">
import Vue from "vue";
export default Vue.extend({
  name: "ShardQrCode",
  props: {
    title: {
      type: String,
      required: true
    },
    shard: {
      type: String,
      required: true
    },
    requiredShards: {
      type: Number,
      required: true
    },
    locale: {
      type: String,
      default: ""
    }
  },
  computed: {
    effectiveLocale(): string {
      return this.locale || this.$i18n.locale;
    },
    needMoreText(): string {
      const count = this.requiredShards - 1;
      return this.$tc("shardNeedMore", count, this.effectiveLocale, { count });
    },
    gitRevision(): string {
      return process.env.GIT_REVISION || "";
    }
  }
});
</script>

<style>
@media screen {
  .print-only {
    display: none;
  }
}

@media print {
  .screen-only {
    display: none;
  }

  .qr-tile {
    display: flex;
    flex-direction: column;
    align-items: center;
    width: 100vw;
    height: 100vh;
    text-align: center;
    page-break-after: always;
  }

  canvas {
    height: min(80vw, 80vh);
    width: min(80vw, 80vh) !important;
  }

  @page {
    margin: 0;
    padding: 0;
  }
}
/*
@media print and (min-width: 20cm) {
  .qr-tile {
    text-align: left !important;
  }

  .print-only {
    padding: 0 10% 0 50% !important;
  }

  .qr-code {
    position: absolute;
    left: 0;
    top: 0;
    padding: 5% !important;
  }

  canvas {
    height: min(75vw, 75vh) !important;
    width: min(75vw, 75vh) !important;
  }
} */
h3,
h4 {
  font-weight: 400;
  margin: 0.25em 0 0 0;
}

.recovery-field {
  width: 100%;
  display: flex;
  margin-top: 2em;
  text-transform: uppercase;
}

.recovery-blank {
  width: 100%;
  border-bottom: 1px solid black;
}

.version {
  font-weight: 500;
  font-size: 75%;
  color: darkgray;
}
</style>
