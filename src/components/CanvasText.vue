<template>
  <canvas v-canvas-message="text" class="canvasText" width="0" height="24" />
</template>

<script lang="ts">
import Vue, { VNodeDirective } from "vue";

// The passphrase is painted on a canvas rather than rendered as text so it
// cannot be selected, copied or picked up by extensions reading the DOM.
const FONT_SIZE_PX = 16;
const LINE_HEIGHT_PX = 24;
const FONT =
  FONT_SIZE_PX + "px ui-monospace, SFMono-Regular, Menlo, Consolas, monospace";

function paint(el: HTMLElement, binding: VNodeDirective): void {
  const canvasElement = el as HTMLCanvasElement;
  const context = canvasElement.getContext("2d");
  if (!context) {
    // eslint-disable-next-line no-console
    console.warn("Failed to find canvasElement context");
    return;
  }
  const text = String(binding.value || "");
  const ratio = window.devicePixelRatio || 1;
  context.font = FONT;
  const textWidth = Math.ceil(context.measureText(text).width) || 300;

  // Resizing the backing store resets the context, so set font afterwards.
  canvasElement.width = textWidth * ratio;
  canvasElement.height = LINE_HEIGHT_PX * ratio;
  canvasElement.style.width = textWidth + "px";
  canvasElement.style.height = LINE_HEIGHT_PX + "px";
  context.setTransform(ratio, 0, 0, ratio, 0, 0);
  context.font = FONT;
  // Inherit the surrounding text colour so the passphrase stays legible in
  // dark mode; computed style is only available once the canvas is attached.
  context.fillStyle = window.getComputedStyle(canvasElement).color || "#222";
  context.textBaseline = "middle";
  context.fillText(text, 0, LINE_HEIGHT_PX / 2);
}

export default Vue.extend({
  name: "CanvasText",
  directives: {
    canvasMessage: {
      inserted: paint,
      update: paint
    }
  },
  props: {
    text: {
      type: String,
      required: true
    }
  }
});
</script>

<style>
.canvasText {
  display: block;
}
</style>
