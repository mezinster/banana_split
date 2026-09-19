import * as fs from "fs";
import * as path from "path";

// A language is wired in four places; PR #20 shipped a complete translation
// that reached only one of them. Nothing failed — the language simply never
// appeared in a picker. These tests make that a red build instead.

const root = path.join(__dirname, "..", "..");
const localesDir = path.join(root, "src", "locales");

function read(...parts: string[]): string {
  // eslint-disable-next-line security/detect-non-literal-fs-filename
  return fs.readFileSync(path.join(root, ...parts), "utf8");
}

// eslint-disable-next-line security/detect-non-literal-fs-filename
const localeFiles = fs.readdirSync(localesDir);

const codes = localeFiles
  .filter(f => f.endsWith(".json"))
  .map(f => f.replace(/\.json$/, ""))
  .sort();

function keysOf(code: string): string[] {
  return Object.keys(JSON.parse(read("src", "locales", code + ".json"))).sort();
}

describe("locales", () => {
  const reference = keysOf("en");

  it.each(codes)("%s has exactly the keys of en", code => {
    expect(keysOf(code)).toEqual(reference);
  });

  it.each(codes)("%s is registered in i18n.ts", code => {
    const source = read("src", "i18n.ts");
    const supported = /SUPPORTED_LOCALES\s*=\s*\[([^\]]*)\]/.exec(source);
    expect(supported).not.toBeNull();
    expect(supported ? supported[1] : "").toContain('"' + code + '"');
    expect(source).toContain('from "./locales/' + code + '.json"');
  });

  it.each(codes)("%s is offered by the language selector", code => {
    expect(read("src", "components", "LanguageSelector.vue")).toContain(
      'code: "' + code + '"'
    );
  });

  it.each(codes)("%s is offered by the print-locale picker", code => {
    expect(read("src", "views", "Share.vue")).toContain(
      '<option value="' + code + '">'
    );
  });
});
