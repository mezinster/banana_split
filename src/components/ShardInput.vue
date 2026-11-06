<template>
  <div class="shard-input">
    <div class="segmented shard-input__modes" role="group">
      <button
        v-for="m in modes"
        :key="m.id"
        type="button"
        class="segmented__item"
        :class="{ 'is-active': mode === m.id }"
        :aria-pressed="String(mode === m.id)"
        @click="switchMode(m.id)"
      >
        {{ $t(m.label) }}
      </button>
    </div>

    <div v-if="mode === 'camera'" class="shard-input__camera">
      <qrcode-stream @decode="onCameraDecode">
        <div class="shard-input__frame" aria-hidden="true">
          <span /><span /><span /><span />
        </div>
        <p class="shard-input__hint">
          {{ $t('combineScanHint') }}
        </p>
      </qrcode-stream>
    </div>

    <div v-if="mode === 'upload'" class="shard-input__upload">
      <input
        ref="fileInput"
        type="file"
        accept="image/*"
        multiple
        class="shard-input__file-hidden"
        @change="onFilesSelected"
      />
      <button type="button" class="btn btn--secondary shard-input__upload-btn" @click="triggerFileInput">
        <svg viewBox="0 0 24 24" aria-hidden="true" class="shard-input__icon">
          <path d="M12 16V4M7 9l5-5 5 5M4 16v3a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-3" />
        </svg>
        {{ $t('inputUploadImage') }}
      </button>
    </div>

    <div v-if="mode === 'paste'" class="shard-input__paste">
      <textarea
        v-model="pasteText"
        :placeholder="$t('inputPastePlaceholder')"
        class="input input--mono shard-input__textarea"
      />
      <button type="button" class="btn btn--primary btn--block shard-input__submit" @click="onPasteSubmit">
        {{ $t('inputPasteSubmit') }}
      </button>
    </div>

    <p v-if="feedback" class="shard-input__feedback" :class="feedback.type" role="status">
      {{ feedback.message }}
    </p>
  </div>
</template>

<script lang="ts">
import Vue from "vue";
import { decodeQrFromImage } from "../util/qrDecode";

const MODES = [
  { id: "camera", label: "inputModeCamera" },
  { id: "upload", label: "inputModeUpload" },
  { id: "paste", label: "inputModePaste" }
];

type ShardInputData = {
  modes: typeof MODES;
  mode: string;
  pasteText: string;
  feedback: { type: string; message: string } | null;
  feedbackTimer: number | null;
};

export default Vue.extend({
  name: "ShardInput",
  data(): ShardInputData {
    return {
      modes: MODES,
      mode: "camera",
      pasteText: "",
      feedback: null,
      feedbackTimer: null
    };
  },
  beforeDestroy: function() {
    this.clearFeedbackTimer();
  },
  methods: {
    clearFeedbackTimer: function() {
      if (this.feedbackTimer !== null) {
        clearTimeout(this.feedbackTimer);
        this.feedbackTimer = null;
      }
    },
    setFeedback: function(type: string, message: string, autoClear: boolean) {
      this.clearFeedbackTimer();
      this.feedback = { type: type, message: message };
      if (autoClear) {
        var self = this;
        this.feedbackTimer = window.setTimeout(function() {
          self.feedback = null;
          self.feedbackTimer = null;
        }, 2000);
      }
    },
    switchMode: function(newMode: string) {
      this.clearFeedbackTimer();
      this.feedback = null;
      this.mode = newMode;
    },
    onCameraDecode: function(result: string) {
      this.$emit("decode", result);
    },
    triggerFileInput: function() {
      var input = this.$refs.fileInput as HTMLInputElement;
      if (input) {
        input.value = "";
        input.click();
      }
    },
    onFilesSelected: function(event: Event) {
      var input = event.target as HTMLInputElement;
      var files = input.files;
      if (!files || files.length === 0) {
        return;
      }

      var self = this;
      var total = files.length;
      var success = 0;
      var processed = 0;

      for (var i = 0; i < files.length; i++) {
        // eslint-disable-next-line security/detect-object-injection
        var file = files[i];
        (function(f) {
          var reader = new FileReader();
          reader.onload = function() {
            var dataUrl = reader.result as string;
            decodeQrFromImage(dataUrl).then(function(decoded) {
              processed++;
              if (decoded) {
                success++;
                self.$emit("decode", decoded);
              }
              if (processed === total) {
                self.showImageFeedback(success, total);
              }
            });
          };
          reader.onerror = function() {
            processed++;
            if (processed === total) {
              self.showImageFeedback(success, total);
            }
          };
          reader.readAsDataURL(f);
        })(file);
      }
    },
    showImageFeedback: function(success: number, total: number) {
      var fail = total - success;
      if (success === total) {
        this.setFeedback(
          "success",
          this.$t("inputDecodeSuccess", { success: success, total: total }) as string,
          true
        );
      } else if (success > 0) {
        this.setFeedback(
          "error",
          this.$t("inputDecodePartial", { success: success, total: total, fail: fail }) as string,
          false
        );
      } else {
        this.setFeedback(
          "error",
          this.$t("inputDecodeFail") as string,
          false
        );
      }
    },
    onPasteSubmit: function() {
      var text = this.pasteText.trim();
      if (!text) {
        this.setFeedback("error", this.$t("inputParseFail") as string, false);
        return;
      }

      var lines = text.split("\n");
      var total = 0;
      var success = 0;

      for (var i = 0; i < lines.length; i++) {
        // eslint-disable-next-line security/detect-object-injection
        var line = lines[i].trim();
        if (!line) {
          continue;
        }
        total++;
        try {
          JSON.parse(line);
          success++;
          this.$emit("decode", line);
        } catch (e) {
          // not valid JSON, skip
        }
      }

      if (total === 0) {
        this.setFeedback("error", this.$t("inputParseFail") as string, false);
      } else if (success === total) {
        this.pasteText = "";
        this.setFeedback(
          "success",
          this.$t("inputParseSuccess", { success: success, total: total }) as string,
          true
        );
      } else if (success > 0) {
        this.pasteText = "";
        var fail = total - success;
        this.setFeedback(
          "error",
          this.$t("inputParsePartial", { success: success, total: total, fail: fail }) as string,
          false
        );
      } else {
        this.setFeedback("error", this.$t("inputParseFail") as string, false);
      }
    }
  }
});
</script>

<style>
.shard-input__modes {
  margin-bottom: 12px;
}
.shard-input__file-hidden {
  display: none;
}
.shard-input__camera .qrcode-stream {
  position: relative;
  aspect-ratio: 1 / 1;
  background: #000;
  border-radius: var(--radius-card);
  overflow: hidden;
}
.shard-input__camera .qrcode-stream__inner-wrapper,
.shard-input__camera .qrcode-stream__camera,
.shard-input__camera .qrcode-stream__pause-frame {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.shard-input__frame {
  position: absolute;
  inset: 18%;
  pointer-events: none;
}
.shard-input__frame span {
  position: absolute;
  width: 28px;
  height: 28px;
  border: 0 solid #fff;
}
.shard-input__frame span:nth-child(1) {
  top: 0;
  left: 0;
  border-top-width: 3px;
  border-left-width: 3px;
  border-top-left-radius: 8px;
}
.shard-input__frame span:nth-child(2) {
  top: 0;
  right: 0;
  border-top-width: 3px;
  border-right-width: 3px;
  border-top-right-radius: 8px;
}
.shard-input__frame span:nth-child(3) {
  bottom: 0;
  left: 0;
  border-bottom-width: 3px;
  border-left-width: 3px;
  border-bottom-left-radius: 8px;
}
.shard-input__frame span:nth-child(4) {
  bottom: 0;
  right: 0;
  border-bottom-width: 3px;
  border-right-width: 3px;
  border-bottom-right-radius: 8px;
}
.shard-input__hint {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 12px;
  padding: 0 16px;
  text-align: center;
  font-size: 0.8125rem;
  color: rgba(255, 255, 255, 0.8);
  pointer-events: none;
}
.shard-input__upload {
  display: flex;
  justify-content: center;
  padding: 32px 16px;
  border: 1px dashed var(--border);
  border-radius: var(--radius-card);
  background: var(--surface-muted);
}
.shard-input__icon {
  fill: none;
  stroke: currentColor;
  stroke-width: 2;
  stroke-linecap: round;
  stroke-linejoin: round;
}
.shard-input__textarea {
  margin-bottom: 12px;
}
.shard-input__feedback {
  margin-top: 12px;
  padding: 10px 14px;
  font-size: 0.875rem;
  border-radius: var(--radius-ctl);
}
.shard-input__feedback.success {
  color: var(--success);
  background: var(--success-bg);
}
.shard-input__feedback.error {
  color: var(--danger);
  background: var(--danger-bg);
}
</style>
