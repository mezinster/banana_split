import { shallowMount, createLocalVue } from "@vue/test-utils";
import ShardInput from "../../src/components/ShardInput.vue";

// Mock qrDecode module
jest.mock("../../src/util/qrDecode", () => ({
  decodeQrFromImage: jest.fn()
}));
import { decodeQrFromImage } from "../../src/util/qrDecode";
const mockDecode = decodeQrFromImage as jest.MockedFunction<typeof decodeQrFromImage>;
void mockDecode; // retained for future image upload tests

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
