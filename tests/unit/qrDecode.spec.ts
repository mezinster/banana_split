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
      // eslint-disable-next-line no-unused-vars
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
