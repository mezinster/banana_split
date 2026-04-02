<template>
  <div class="shard-input">
    <div v-if="mode === 'camera'" class="shard-input__camera">
      <qrcode-stream @decode="onCameraDecode" />
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
      <button class="button-card" @click="triggerFileInput">
        {{ $t('inputUploadImage') }}
      </button>
    </div>

    <div v-if="mode === 'paste'" class="shard-input__paste">
      <textarea
        v-model="pasteText"
        :placeholder="$t('inputPastePlaceholder')"
        class="shard-input__textarea"
      />
      <button class="button-card" @click="onPasteSubmit">
        {{ $t('inputPasteSubmit') }}
      </button>
    </div>

    <p v-if="feedback" class="shard-input__feedback" :class="feedback.type">
      {{ feedback.message }}
    </p>

    <div class="shard-input__modes">
      <button v-if="mode !== 'camera'" class="button-card" @click="switchMode('camera')">
        {{ $t('inputUseCamera') }}
      </button>
      <button v-if="mode !== 'upload'" class="button-card" @click="switchMode('upload')">
        {{ $t('inputUploadImage') }}
      </button>
      <button v-if="mode !== 'paste'" class="button-card" @click="switchMode('paste')">
        {{ $t('inputPasteText') }}
      </button>
    </div>
  </div>
</template>

<script lang="ts">
import Vue from "vue";
import { decodeQrFromImage } from "../util/qrDecode";

type ShardInputData = {
  mode: string;
  pasteText: string;
  feedback: { type: string; message: string } | null;
  feedbackTimer: number | null;
};

export default Vue.extend({
  name: "ShardInput",
  data(): ShardInputData {
    return {
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
.shard-input__file-hidden {
  display: none;
}
.shard-input__textarea {
  width: 100%;
  min-height: 120px;
}
.shard-input__feedback {
  font-size: 1.4rem;
  margin: 0.5rem 0;
}
.shard-input__feedback.success {
  color: #2e7d32;
}
.shard-input__feedback.error {
  color: darkred;
}
.shard-input__modes {
  display: flex;
  margin-top: 0.5rem;
}
.shard-input__modes button + button {
  margin-left: 1rem;
}
/* Camera rounded corners (moved from view-level CSS) */
.shard-input__camera .qrcode-stream {
  border-radius: 8px;
  overflow: hidden;
}
</style>
