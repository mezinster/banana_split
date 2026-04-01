import Vue from "vue";
import VueI18n from "vue-i18n";

import en from "./locales/en.json";
import ru from "./locales/ru.json";
import tr from "./locales/tr.json";
import be from "./locales/be.json";
import ka from "./locales/ka.json";
import uk from "./locales/uk.json";
import pl from "./locales/pl.json";

Vue.use(VueI18n);

const SUPPORTED_LOCALES = ["en", "ru", "tr", "be", "ka", "uk", "pl"];

function getQueryLang(): string {
  // Parse lang from hash query: #/path?lang=xx
  var hash = window.location.hash || "";
  var qIndex = hash.indexOf("?");
  if (qIndex === -1) return "";
  var params = new URLSearchParams(hash.slice(qIndex));
  var lang = params.get("lang") || "";
  if (lang && SUPPORTED_LOCALES.indexOf(lang) !== -1) {
    return lang;
  }
  return "";
}

function detectLocale(): string {
  var urlLang = getQueryLang();
  if (urlLang) return urlLang;
  var browserLang = navigator.language ? navigator.language.split("-")[0] : "";
  if (browserLang && SUPPORTED_LOCALES.indexOf(browserLang) !== -1) {
    return browserLang;
  }
  return "en";
}

// Slavic plural rule: one | few | many
function slavicPlural(choice: number): number {
  const abs = Math.abs(choice) % 100;
  const lastDigit = abs % 10;
  if (lastDigit === 1 && abs !== 11) return 0;
  if (lastDigit >= 2 && lastDigit <= 4 && (abs < 12 || abs > 14)) return 1;
  return 2;
}

const i18n = new VueI18n({
  locale: detectLocale(),
  fallbackLocale: "en",
  messages: { en, ru, tr, be, ka, uk, pl },
  pluralizationRules: {
    ru: slavicPlural,
    uk: slavicPlural,
    be: slavicPlural,
    pl: slavicPlural
  }
});

export default i18n;
export { SUPPORTED_LOCALES };
