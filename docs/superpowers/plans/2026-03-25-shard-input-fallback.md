# ShardInput Multi-Method Input Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add camera fallback input methods (image upload, text paste) to the Combine and Print pages via a shared `<ShardInput>` component.

**Architecture:** A new `ShardInput.vue` component wraps the existing `<qrcode-stream>` and adds two alternative input modes (image upload with jsqr decoding, text paste with JSON parsing). It emits `decode(string)` matching the existing interface, so parent views need only a one-line template swap.

**Tech Stack:** Vue 2, TypeScript, jsqr (existing dep), vue-i18n v8

**Spec:** `docs/superpowers/specs/2026-03-25-shard-input-fallback-design.md`

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `src/components/ShardInput.vue` | Multi-method shard input component |
| Create | `src/util/qrDecode.ts` | Image-to-QR decode helper (canvas + jsqr) |
| Create | `tests/unit/qrDecode.spec.ts` | Unit tests for QR decode helper |
| Create | `tests/unit/shardInput.spec.ts` | Unit tests for ShardInput component |
| Modify | `src/views/Combine.vue` | Replace `<qrcode-stream>` with `<ShardInput>` |
| Modify | `src/views/Print.vue` | Replace `<qrcode-stream>` with `<ShardInput>` |
| Modify | `src/locales/en.json` | Add 11 new i18n keys |
| Modify | `src/locales/ru.json` | Add 11 new i18n keys (English placeholders) |
| Modify | `src/locales/tr.json` | Add 11 new i18n keys (English placeholders) |
| Modify | `src/locales/be.json` | Add 11 new i18n keys (English placeholders) |
| Modify | `src/locales/ka.json` | Add 11 new i18n keys (English placeholders) |
| Modify | `src/locales/uk.json` | Add 11 new i18n keys (English placeholders) |

---

### Task 1: Add localization keys

**Files:**
- Modify: `src/locales/en.json`
- Modify: `src/locales/ru.json`
- Modify: `src/locales/tr.json`
- Modify: `src/locales/be.json`
- Modify: `src/locales/ka.json`
- Modify: `src/locales/uk.json`

- [ ] **Step 1: Add keys to en.json**

Add these 11 keys before the closing `}` in `src/locales/en.json` (after the `"infoMinimalRisk"` line):

```json
"inputUploadImage": "Upload image",
"inputPasteText": "Paste text",
"inputUseCamera": "Use camera",
"inputPastePlaceholder": "Paste shard JSON here...",
"inputPasteSubmit": "Submit",
"inputDecodeSuccess": "Decoded {success} of {total} images",
"inputDecodeFail": "Could not decode QR code from image",
"inputDecodePartial": "Decoded {success} of {total} images. {fail} could not be read.",
"inputParseSuccess": "Parsed {success} of {total} shards",
"inputParseFail": "No valid shard JSON found",
"inputParsePartial": "Parsed {success} of {total} entries. {fail} not valid."
```

- [ ] **Step 2: Add same keys to all 5 other locale files**

Add the same 11 English keys to `ru.json`, `tr.json`, `be.json`, `ka.json`, `uk.json` — English strings as placeholders.

- [ ] **Step 3: Run lint to verify JSON is valid**

Run: `source "$NVM_DIR/nvm.sh" && yarn lint`
Expected: No errors related to locale files.

- [ ] **Step 4: Commit**

```bash
git add src/locales/*.json
git commit -m "feat: add i18n keys for ShardInput multi-method input"
```

---

### Task 2: Create QR decode helper

**Files:**
- Create: `src/util/qrDecode.ts`
- Create: `tests/unit/qrDecode.spec.ts`

- [ ] **Step 1: Write failing tests for qrDecode**

Create `tests/unit/qrDecode.spec.ts`:

```typescript
import { decodeQrFromImage } from "../../src/util/qrDecode";

// Mock jsQR
jest.mock("jsqr", () => {
  return jest.fn();
});
import jsQR from "jsqr";
const mockJsQR = jsQR as jest.MockedFunction<typeof jsQR>;

describe("decodeQrFromImage", () => {
  let originalImage: typeof Image;
  let originalCreateElement: typeof document.createElement;

  beforeEach(() => {
    jest.clearAllMocks();
    originalImage = (global as any).Image;
    originalCreateElement = document.createElement.bind(document);
  });

  afterEach(() => {
    (global as any).Image = originalImage;
    document.createElement = originalCreateElement;
  });

  test("returns decoded string on success", async () => {
    // Mock Image
    (global as any).Image = class {
      width = 100;
      height = 100;
      onload: (() => void) | null = null;
      set src(_: string) {
        setTimeout(() => {
          if (this.onload) this.onload();
        }, 0);
      }
    };

    // Mock canvas
    const mockGetImageData = jest.fn().mockReturnValue({
      data: new Uint8ClampedArray(100 * 100 * 4),
      width: 100,
      height: 100
    });
    const mockDrawImage = jest.fn();
    const mockContext = {
      drawImage: mockDrawImage,
      getImageData: mockGetImageData
    };

    document.createElement = jest.fn().mockReturnValue({
      getContext: jest.fn().mockReturnValue(mockContext),
      width: 0,
      height: 0
    }) as any;

    mockJsQR.mockReturnValue({ data: '{"v":1,"t":"test"}' } as any);

    const result = await decodeQrFromImage("data:image/png;base64,abc");
    expect(result).toBe('{"v":1,"t":"test"}');
    expect(mockJsQR).toHaveBeenCalledTimes(1);
  });

  test("returns null when jsQR finds no QR code", async () => {
    (global as any).Image = class {
      width = 100;
      height = 100;
      onload: (() => void) | null = null;
      set src(_: string) {
        setTimeout(() => {
          if (this.onload) this.onload();
        }, 0);
      }
    };

    const mockContext = {
      drawImage: jest.fn(),
      getImageData: jest.fn().mockReturnValue({
        data: new Uint8ClampedArray(100 * 100 * 4),
        width: 100,
        height: 100
      })
    };
    document.createElement = jest.fn().mockReturnValue({
      getContext: jest.fn().mockReturnValue(mockContext),
      width: 0,
      height: 0
    }) as any;

    mockJsQR.mockReturnValue(null);

    const result = await decodeQrFromImage("data:image/png;base64,abc");
    expect(result).toBeNull();
  });

  test("returns null when canvas context is null", async () => {
    (global as any).Image = class {
      width = 100;
      height = 100;
      onload: (() => void) | null = null;
      set src(_: string) {
        setTimeout(() => {
          if (this.onload) this.onload();
        }, 0);
      }
    };

    document.createElement = jest.fn().mockReturnValue({
      getContext: jest.fn().mockReturnValue(null),
      width: 0,
      height: 0
    }) as any;

    const result = await decodeQrFromImage("data:image/png;base64,abc");
    expect(result).toBeNull();
    expect(mockJsQR).not.toHaveBeenCalled();
  });

  test("returns null when image fails to load", async () => {
    (global as any).Image = class {
      onerror: ((e: any) => void) | null = null;
      set src(_: string) {
        setTimeout(() => {
          if (this.onerror) this.onerror(new Error("load failed"));
        }, 0);
      }
    };

    const result = await decodeQrFromImage("data:image/png;base64,bad");
    expect(result).toBeNull();
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `source "$NVM_DIR/nvm.sh" && yarn test:unit --testPathPattern=qrDecode`
Expected: FAIL — `Cannot find module '../../src/util/qrDecode'`

- [ ] **Step 3: Implement qrDecode.ts**

Create `src/util/qrDecode.ts`:

```typescript
import jsQR from "jsqr";

/**
 * Decode a QR code from an image data URL.
 * Returns the decoded string, or null if decoding fails.
 */
export function decodeQrFromImage(dataUrl: string): Promise<string | null> {
  return new Promise(function(resolve) {
    var img = new Image();
    img.onload = function() {
      var canvas = document.createElement("canvas");
      canvas.width = img.width;
      canvas.height = img.height;
      var ctx = canvas.getContext("2d");
      if (!ctx) {
        resolve(null);
        return;
      }
      ctx.drawImage(img, 0, 0);
      var imageData = ctx.getImageData(0, 0, img.width, img.height);
      var code = jsQR(imageData.data, imageData.width, imageData.height);
      resolve(code ? code.data : null);
    };
    img.onerror = function() {
      resolve(null);
    };
    img.src = dataUrl;
  });
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `source "$NVM_DIR/nvm.sh" && yarn test:unit --testPathPattern=qrDecode`
Expected: 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add src/util/qrDecode.ts tests/unit/qrDecode.spec.ts
git commit -m "feat: add QR decode helper for image-to-text via jsqr"
```

---

### Task 3: Create ShardInput component

**Files:**
- Create: `src/components/ShardInput.vue`

- [ ] **Step 1: Create ShardInput.vue**

Create `src/components/ShardInput.vue`:

```vue
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
/* Camera mirror + rounded corners (moved from view-level CSS) */
.shard-input__camera .qrcode-stream {
  transform: scaleX(-1);
  border-radius: 8px;
  overflow: hidden;
}
</style>
```

- [ ] **Step 2: Verify lint passes**

Run: `source "$NVM_DIR/nvm.sh" && yarn lint`
Expected: No errors in ShardInput.vue

- [ ] **Step 3: Commit**

```bash
git add src/components/ShardInput.vue
git commit -m "feat: create ShardInput component with camera, upload, and paste modes"
```

---

### Task 4: Write ShardInput component tests

**Files:**
- Create: `tests/unit/shardInput.spec.ts`

- [ ] **Step 1: Write component tests**

Create `tests/unit/shardInput.spec.ts`:

```typescript
import { shallowMount, createLocalVue } from "@vue/test-utils";
import ShardInput from "../../src/components/ShardInput.vue";

// Mock qrDecode module
jest.mock("../../src/util/qrDecode", () => ({
  decodeQrFromImage: jest.fn()
}));
import { decodeQrFromImage } from "../../src/util/qrDecode";
const mockDecode = decodeQrFromImage as jest.MockedFunction<typeof decodeQrFromImage>;

const localVue = createLocalVue();

// Stub for qrcode-stream (registered globally via Vue.use in main.ts).
// Passed via shallowMount `stubs` option so Vue Test Utils doesn't replace it.
const QrcodeStreamStub = {
  template: "<div class='qrcode-stream-stub'></div>"
};

// Minimal i18n stub
const $t = function(key: string, params?: Record<string, unknown>) {
  if (params) {
    var result = key;
    Object.keys(params).forEach(function(k) {
      result = result.replace("{" + k + "}", String(params[k]));
    });
    return result;
  }
  return key;
};

function mountShardInput() {
  return shallowMount(ShardInput, {
    localVue,
    mocks: { $t: $t },
    stubs: { "qrcode-stream": QrcodeStreamStub }
  });
}

describe("ShardInput", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test("defaults to camera mode", () => {
    var wrapper = mountShardInput();
    expect(wrapper.find(".shard-input__camera").exists()).toBe(true);
    expect(wrapper.find(".shard-input__upload").exists()).toBe(false);
    expect(wrapper.find(".shard-input__paste").exists()).toBe(false);
  });

  test("shows upload and paste buttons in camera mode", () => {
    var wrapper = mountShardInput();
    var buttons = wrapper.findAll(".shard-input__modes button");
    expect(buttons.length).toBe(2);
    expect(buttons.at(0).text()).toContain("inputUploadImage");
    expect(buttons.at(1).text()).toContain("inputPasteText");
  });

  test("switches to paste mode", async () => {
    var wrapper = mountShardInput();
    var pasteBtn = wrapper.findAll(".shard-input__modes button").at(1);
    await pasteBtn.trigger("click");
    expect(wrapper.find(".shard-input__paste").exists()).toBe(true);
    expect(wrapper.find(".shard-input__camera").exists()).toBe(false);
  });

  test("switches to upload mode", async () => {
    var wrapper = mountShardInput();
    var uploadBtn = wrapper.findAll(".shard-input__modes button").at(0);
    await uploadBtn.trigger("click");
    expect(wrapper.find(".shard-input__upload").exists()).toBe(true);
    expect(wrapper.find(".shard-input__camera").exists()).toBe(false);
  });

  test("emits decode on camera scan", () => {
    var wrapper = mountShardInput();
    var stream = wrapper.find(".qrcode-stream-stub");
    stream.vm.$emit("decode", '{"v":1}');
    expect(wrapper.emitted("decode")).toBeTruthy();
    expect(wrapper.emitted("decode")![0]).toEqual(['{"v":1}']);
  });

  test("paste mode: parses single JSON line and emits decode", async () => {
    var wrapper = mountShardInput();
    wrapper.setData({ mode: "paste", pasteText: '{"v":1,"t":"test","r":3,"d":"abc","n":"xyz"}' });
    await wrapper.vm.$nextTick();
    var submitBtn = wrapper.find(".shard-input__paste .button-card");
    await submitBtn.trigger("click");
    expect(wrapper.emitted("decode")).toBeTruthy();
    expect(wrapper.emitted("decode")!.length).toBe(1);
  });

  test("paste mode: parses multiple JSON lines and emits decode per line", async () => {
    var wrapper = mountShardInput();
    var multiLine = '{"v":1,"t":"a","r":2,"d":"x","n":"y"}\n{"v":1,"t":"a","r":2,"d":"z","n":"y"}';
    wrapper.setData({ mode: "paste", pasteText: multiLine });
    await wrapper.vm.$nextTick();
    var submitBtn = wrapper.find(".shard-input__paste .button-card");
    await submitBtn.trigger("click");
    expect(wrapper.emitted("decode")!.length).toBe(2);
  });

  test("paste mode: shows error for empty input", async () => {
    var wrapper = mountShardInput();
    wrapper.setData({ mode: "paste", pasteText: "   " });
    await wrapper.vm.$nextTick();
    var submitBtn = wrapper.find(".shard-input__paste .button-card");
    await submitBtn.trigger("click");
    expect(wrapper.emitted("decode")).toBeFalsy();
    expect(wrapper.find(".shard-input__feedback.error").exists()).toBe(true);
  });

  test("paste mode: shows error for invalid JSON", async () => {
    var wrapper = mountShardInput();
    wrapper.setData({ mode: "paste", pasteText: "not json at all" });
    await wrapper.vm.$nextTick();
    var submitBtn = wrapper.find(".shard-input__paste .button-card");
    await submitBtn.trigger("click");
    expect(wrapper.emitted("decode")).toBeFalsy();
    expect(wrapper.find(".shard-input__feedback.error").exists()).toBe(true);
  });

  test("switching mode clears feedback", async () => {
    var wrapper = mountShardInput();
    wrapper.setData({ mode: "paste", pasteText: "bad", feedback: { type: "error", message: "err" } });
    await wrapper.vm.$nextTick();
    expect(wrapper.find(".shard-input__feedback").exists()).toBe(true);

    // Switch to camera
    var cameraBtn = wrapper.findAll(".shard-input__modes button").at(0);
    await cameraBtn.trigger("click");
    expect(wrapper.find(".shard-input__feedback").exists()).toBe(false);
  });
});
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `source "$NVM_DIR/nvm.sh" && yarn test:unit --testPathPattern=shardInput`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add tests/unit/shardInput.spec.ts
git commit -m "test: add unit tests for ShardInput component"
```

---

### Task 5: Integrate ShardInput into Combine.vue

**Files:**
- Modify: `src/views/Combine.vue:11` (template swap)
- Modify: `src/views/Combine.vue:63` (import)
- Modify: `src/views/Combine.vue:168-178` (remove CSS)

- [ ] **Step 1: Replace qrcode-stream with ShardInput in template**

In `src/views/Combine.vue`, line 11, replace:
```html
        <qrcode-stream @decode="onDecode" />
```
with:
```html
        <ShardInput @decode="onDecode" />
```

- [ ] **Step 2: Add ShardInput import and component registration**

In `src/views/Combine.vue`, after line 63 (`import crypto, { Shard } from "../util/crypto";`), add:
```typescript
import ShardInput from "../components/ShardInput.vue";
```

Then in the `Vue.extend({` block (around line 77), change:
```typescript
export default Vue.extend({
  name: "Combine",
```
to:
```typescript
export default Vue.extend({
  name: "Combine",
  components: { ShardInput },
```

- [ ] **Step 3: Remove the view-level .qrcode-stream CSS**

In `src/views/Combine.vue`, remove lines 173-178:
```css
/* Flip video to make it easier to use */
.qrcode-stream {
  transform: scaleX(-1);
  border-radius: 8px;
  overflow: hidden;
}
```

- [ ] **Step 4: Run lint**

Run: `source "$NVM_DIR/nvm.sh" && yarn lint`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add src/views/Combine.vue
git commit -m "feat: integrate ShardInput into Combine page"
```

---

### Task 6: Integrate ShardInput into Print.vue

**Files:**
- Modify: `src/views/Print.vue:29` (template swap)
- Modify: `src/views/Print.vue:66` (import)
- Modify: `src/views/Print.vue:81` (component registration — already has ShardInfo)
- Modify: `src/views/Print.vue:160-170` (remove CSS)

- [ ] **Step 1: Replace qrcode-stream with ShardInput in template**

In `src/views/Print.vue`, line 29, replace:
```html
        <qrcode-stream @decode="onDecode" />
```
with:
```html
        <ShardInput @decode="onDecode" />
```

- [ ] **Step 2: Add ShardInput import and component registration**

In `src/views/Print.vue`, after line 66 (`import crypto, { Shard } from "../util/crypto";`), add:
```typescript
import ShardInput from "../components/ShardInput.vue";
```

In the components object (line 83), change:
```typescript
  components: { ShardInfo },
```
to:
```typescript
  components: { ShardInfo, ShardInput },
```

- [ ] **Step 3: Remove the view-level .qrcode-stream CSS**

In `src/views/Print.vue`, remove lines 165-170 (keep `</style>` on line 171):
```css
/* Flip video to make it easier to use */
.qrcode-stream {
  transform: scaleX(-1);
  border-radius: 8px;
  overflow: hidden;
}
```

- [ ] **Step 4: Run lint**

Run: `source "$NVM_DIR/nvm.sh" && yarn lint`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add src/views/Print.vue
git commit -m "feat: integrate ShardInput into Print page"
```

---

### Task 7: Final verification

**Files:** None (verification only)

- [ ] **Step 1: Run all unit tests**

Run: `source "$NVM_DIR/nvm.sh" && yarn test:unit`
Expected: All tests pass (existing crypto tests + new qrDecode + shardInput tests)

- [ ] **Step 2: Run lint**

Run: `source "$NVM_DIR/nvm.sh" && yarn lint`
Expected: No errors

- [ ] **Step 3: Run build**

Run: `source "$NVM_DIR/nvm.sh" && yarn build`
Expected: Build succeeds, produces self-contained HTML in `dist/`

- [ ] **Step 4: Manual smoke test (optional)**

Run: `source "$NVM_DIR/nvm.sh" && yarn serve`
Open browser to the Combine page:
1. Verify camera mode shows by default with "Upload image" and "Paste text" buttons below
2. Click "Upload image" — verify file picker opens and can select images
3. Click "Paste text" — verify textarea appears, paste a shard JSON, click Submit
4. Click "Use camera" — verify camera re-initializes
5. Navigate to Print page — verify same three input methods appear
