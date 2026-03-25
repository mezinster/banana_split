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
