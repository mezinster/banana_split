# Spanish (es) Translation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Spanish (`es`) as a fully supported locale across the web app, Flutter Android app, and Flutter Windows app.

**Architecture:** Two self-contained translation drops — one JSON file for the Vue 2 web app, one ARB file for the Flutter app — each wired into their respective language selector and locale registry. No new pluralization rules needed (Spanish uses standard 2-form European plural). The feature branch is linked to GitHub issue #2 by name.

**Tech Stack:** Vue 2 + vue-i18n v8 (web), Flutter `flutter_localizations` + ARB codegen (mobile/desktop), Git, Node 14 / Yarn, Flutter SDK.

---

## File Map

| Action | Path |
|--------|------|
| Create | `src/locales/es.json` |
| Modify | `src/i18n.ts` |
| Modify | `src/components/LanguageSelector.vue` |
| Create | `banana_split_flutter/lib/l10n/app_es.arb` |
| Modify | `banana_split_flutter/lib/widgets/language_selector.dart` |

---

### Task 1: Create feature branch

- [ ] **Step 1: Create and push the branch**

```bash
git checkout -b feature/issue-2-spanish-translation
git push -u origin feature/issue-2-spanish-translation
```

Expected: branch created locally and pushed. GitHub will auto-link it to issue #2 because the branch name contains `issue-2`.

---

### Task 2: Add `src/locales/es.json`

**Files:**
- Create: `src/locales/es.json`

- [ ] **Step 1: Create the file with all 69 translated keys**

```json
{
  "appTitle": "Banana Split",
  "tabCreate": "Crear",
  "tabRestore": "Restaurar",
  "tabPrint": "Imprimir",
  "createTitle": "Crear una división de secreto",
  "createNameLabel": "1. Nombre de su división",
  "createNameHint": "Ej: 'Mi frase semilla de Bitcoin'",
  "createSecretLabel": "2. Secreto",
  "createSecretHint": "Su secreto va aquí",
  "createSecretTooLong": "El secreto supera los 1024 caracteres",
  "createCharCounter": "{remaining} / 1024 caracteres restantes",
  "createShardsLabel": "3. Fragmentos",
  "createShardsRequire": "Requerirá cualquiera",
  "createShardsOutOf": "fragmentos de",
  "createShardsReconstruct": "para reconstruir",
  "createShardsInvalid": "El total de fragmentos debe ser 3–255, el quórum debe ser entre 2 y el total de fragmentos",
  "createPassphraseLabel": "4. Frase de recuperación",
  "createPassphraseHint": "Ingrese la frase de acceso (mínimo 8 caracteres)",
  "createPassphraseTooShort": "La frase de acceso debe tener al menos 8 caracteres",
  "createPassphraseCustom": "Usar frase de acceso personalizada",
  "createGenerateButton": "¡Generar códigos QR!",
  "createBackButton": "Volver a editar datos",
  "createPrintButton": "¡Imprimir!",
  "combineTitle": "Combinar fragmentos",
  "combineFor": "para",
  "combinePassphraseLabel": "1. Frase secreta",
  "combinePassphraseHint": "ingrese su frase de acceso",
  "combineSecretLabel": "2. Secreto",
  "combineReconstructButton": "Reconstruir secreto",
  "errorShardSeen": "Fragmento ya registrado",
  "errorTitleMismatch": "¡el título no coincide!",
  "errorNonceMismatch": "¡el nonce no coincide!",
  "errorRequiredMismatch": "los fragmentos requeridos no coinciden",
  "errorDecryptionFailed": "No se puede descifrar el secreto. Frase de acceso incorrecta o datos corruptos.",
  "printTitle": "Imprimir fragmentos",
  "printShardsLabel": "Fragmentos",
  "printShardsQuestion": "¿Cuántos fragmentos ha generado?",
  "printImportButton": "¡Importar códigos QR!",
  "printInvalidShards": "Ingrese un número válido de fragmentos entre 3 y 255.",
  "shardNeedMore": "Necesita {count} código QR más como este para reconstruir el secreto | Necesita {count} códigos QR más como este para reconstruir el secreto",
  "shardRecoveryPassphrase": "La frase de recuperación es",
  "shardDownloadPrompt": "Para reconstruir el secreto, vaya a {link}.",
  "shardVersionInfo": "Esto ha sido generado por BananaSplit versión {version}",
  "forkMe": "Ver en GitHub",
  "infoWhatIsThis": "¿Qué es esto?",
  "infoWhatIsThisBody": "Banana Split es una aplicación web que hace sus copias de seguridad en papel más resilientes y seguras usando {link}. Puede cifrar y dividir información especialmente sensible para que no esté almacenada físicamente en un solo lugar: su contraseña maestra, frase semilla, etc.",
  "infoShamirLink": "el esquema de compartición de secretos de Shamir",
  "infoHowDoesItWork": "¿Cómo funciona?",
  "infoHowBody1": "Después de ingresar su secreto en Banana Split, será cifrado con una frase de acceso autogenerada y dividido en N códigos QR, listos para imprimir. Necesitará N/2+1 de esas impresiones para reconstruir el secreto, y luego la frase de acceso para descifrarlo.",
  "infoHowBody2": "Banana Split intenta proteger su secreto de vectores de ataque como \"el atacante puede interceptar todo lo que envía a su impresora\", y por eso tendrá que escribir la frase de acceso en sus impresiones a mano.",
  "infoHowBody3": "Por supuesto, debe sellar sus impresiones en sobres opacos y distribuirlos en diferentes lugares tan pronto como termine de escribir su frase semilla: Banana Split solo es más seguro que un solo papel con su secreto siempre que los secretos no puedan perderse o robarse en su totalidad.",
  "infoHowBody4": "La recuperación se puede realizar en cualquier dispositivo con cámara web: simplemente muestre sus códigos QR a la cámara y siga las notificaciones en pantalla. También disponible como aplicación para Android/Windows.",
  "infoHowToUse": "¿Cómo usarlo?",
  "infoStep1": "Haga clic en Crear e ingrese su secreto",
  "infoStep2": "Elija el número de fragmentos e imprima o guarde los códigos QR",
  "infoStep3": "Escriba la frase de acceso a mano en cada impresión y distribúyalas en diferentes lugares",
  "infoMinimalRisk": "Toda la criptografía ocurre localmente en su navegador — nada se envía a ningún servidor.",
  "inputUploadImage": "Subir imagen",
  "inputPasteText": "Pegar texto",
  "inputUseCamera": "Usar cámara",
  "inputPastePlaceholder": "Pegue el JSON del fragmento aquí...",
  "inputPasteSubmit": "Enviar",
  "inputDecodeSuccess": "Decodificado {success} de {total} imágenes",
  "inputDecodeFail": "No se pudo decodificar el código QR de la imagen",
  "inputDecodePartial": "Decodificado {success} de {total} imágenes. {fail} no se pudieron leer.",
  "inputParseSuccess": "Analizado {success} de {total} fragmentos",
  "inputParseFail": "No se encontró JSON de fragmento válido",
  "inputParsePartial": "Analizado {success} de {total} entradas. {fail} no son válidas."
}
```

- [ ] **Step 2: Commit**

```bash
git add src/locales/es.json
git commit -m "feat: add Spanish locale strings for web app"
```

---

### Task 3: Wire Spanish into the web app locale registry

**Files:**
- Modify: `src/i18n.ts`

- [ ] **Step 1: Add the import and register `es` in `src/i18n.ts`**

Replace the imports block and `SUPPORTED_LOCALES` / `messages` entries. The diff is three additions:

```typescript
import en from "./locales/en.json";
import ru from "./locales/ru.json";
import tr from "./locales/tr.json";
import be from "./locales/be.json";
import ka from "./locales/ka.json";
import uk from "./locales/uk.json";
import pl from "./locales/pl.json";
import es from "./locales/es.json";   // ← add

// …

const SUPPORTED_LOCALES = ["en", "ru", "tr", "be", "ka", "uk", "pl", "es"];  // ← add "es"

// …

  messages: { en, ru, tr, be, ka, uk, pl, es },   // ← add es
```

No `pluralizationRules` entry needed — Spanish uses the default 2-form plural.

- [ ] **Step 2: Verify lint passes**

```bash
export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh" && yarn lint
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add src/i18n.ts
git commit -m "feat: register Spanish locale in web app i18n"
```

---

### Task 4: Add Spanish to the web app language picker

**Files:**
- Modify: `src/components/LanguageSelector.vue`

- [ ] **Step 1: Add the Spanish entry to the `LOCALES` array**

In `src/components/LanguageSelector.vue`, find the `LOCALES` constant (line ~24) and append the Spanish entry:

```typescript
const LOCALES = [
  { code: "en", flag: "🇬🇧", name: "English" },
  { code: "ru", flag: "🇷🇺", name: "Русский" },
  { code: "tr", flag: "🇹🇷", name: "Türkçe" },
  { code: "be", flag: "🇧🇾", name: "Беларуская" },
  { code: "ka", flag: "🇬🇪", name: "ქართული" },
  { code: "uk", flag: "🇺🇦", name: "Українська" },
  { code: "pl", flag: "🇵🇱", name: "Polski" },
  { code: "es", flag: "🇪🇸", name: "Español" }   // ← add
];
```

- [ ] **Step 2: Verify unit tests pass**

```bash
export NVM_DIR="$HOME/.nvm" && source "$NVM_DIR/nvm.sh" && yarn test:unit
```

Expected: all tests pass.

- [ ] **Step 3: Commit**

```bash
git add src/components/LanguageSelector.vue
git commit -m "feat: add Spanish to web app language picker"
```

---

### Task 5: Add `lib/l10n/app_es.arb`

**Files:**
- Create: `banana_split_flutter/lib/l10n/app_es.arb`

- [ ] **Step 1: Create the ARB file**

The file must include `@@locale` and every key from `app_en.arb`. Placeholder metadata entries (`@key` objects) are carried through unchanged — only the translatable string values change.

```json
{
  "@@locale": "es",
  "appTitle": "Banana Split",
  "tabCreate": "Crear",
  "tabRestore": "Restaurar",
  "tabAbout": "Acerca de",

  "createEncrypting": "Cifrando...",
  "createTitleLabel": "Título",
  "createTitleHint": "p. ej. Frase semilla de mi billetera",
  "createSecretLabel": "Secreto",
  "createSecretHint": "Ingrese el secreto a dividir",
  "createSecretTooLong": "El secreto supera los 1024 caracteres",
  "createSecretCharCount": "{count} / 1024 caracteres restantes",
  "@createSecretCharCount": { "placeholders": { "count": { "type": "int" } } },
  "createTotalShardsLabel": "Total de fragmentos",
  "createTotalShardsHint": "3–255",
  "createRequiredLabel": "Requeridos para restaurar",
  "createRequiredHint": "2–{max}",
  "@createRequiredHint": { "placeholders": { "max": { "type": "int" } } },
  "createQuorumHelper": "Se necesitan {required} de {total} fragmentos para restaurar",
  "@createQuorumHelper": { "placeholders": { "required": { "type": "int" }, "total": { "type": "int" } } },
  "createGenerateButton": "Generar fragmentos QR",
  "createSavePassphrase": "¡Guarde su frase de acceso!",
  "createPassphraseNeeded": "Necesitará esta frase de acceso para restaurar su secreto.",
  "createBack": "Atrás",
  "createSaveAllTooltip": "Guardar todos los fragmentos",
  "createSaveAsPdf": "Guardar como PDF",
  "createSaveAsPngs": "Guardar como PNGs",
  "createShareAllTooltip": "Compartir todos los fragmentos",
  "createSavedTo": "Guardado en {path}",
  "@createSavedTo": { "placeholders": { "path": { "type": "String" } } },

  "restoreCombineTitle": "Combinar fragmentos para \"{title}\"",
  "@restoreCombineTitle": { "placeholders": { "title": { "type": "String" } } },
  "restoreCombineTitleDefault": "Combinar fragmentos",
  "restoreStartOver": "Empezar de nuevo",
  "restoreAllCollected": "¡Todos los fragmentos recopilados!",
  "restorePassphraseLabel": "Frase de acceso",
  "restorePassphraseHint": "Ingrese la frase de acceso para descifrar",
  "restoreReconstructButton": "Reconstruir secreto",
  "restoreDecrypting": "Descifrando...",
  "restoreRecoveredSecret": "Secreto recuperado",
  "restoreShardScanned": "Fragmento {count} de {total} escaneado",
  "@restoreShardScanned": { "placeholders": { "count": { "type": "int" }, "total": { "type": "int" } } },

  "scannerScanFirst": "Escanee el primer fragmento...",
  "scannerProgress": "{count} de {total} escaneados",
  "@scannerProgress": { "placeholders": { "count": { "type": "int" }, "total": { "type": "int" } } },
  "scannerNoQrFound": "No se encontró código QR en la imagen",
  "scannerBulkResult": "{decoded} importados, {failed} fallidos",
  "@scannerBulkResult": { "placeholders": { "decoded": { "type": "int" }, "failed": { "type": "int" } } },
  "scannerCameraDenied": "Permiso de cámara denegado.\nConceda acceso a la cámara en Ajustes, o importe imágenes QR a continuación.",
  "scannerOpenSettings": "Abrir ajustes",
  "scannerCameraUnavailable": "Cámara no disponible.\nUse el botón de importar a continuación para cargar imágenes de códigos QR.",
  "scannerRetryCamera": "Reintentar cámara",
  "scannerImportGallery": "Importar de la galería",
  "scannerPasteText": "Pegar texto",
  "scannerBackToCamera": "Volver a la cámara",
  "scannerPasteHint": "Pegue uno o más JSON de fragmentos, uno por línea",
  "scannerPasteSubmit": "Enviar",
  "scannerPasteEmpty": "No hay texto para procesar",
  "scannerPasteAdded": "{count} fragmento(s) añadido(s)",
  "@scannerPasteAdded": { "placeholders": { "count": { "type": "int" } } },
  "scannerPasteFailed": "{count} línea(s) fallida(s)",
  "@scannerPasteFailed": { "placeholders": { "count": { "type": "int" } } },
  "scannerPasteDuplicate": "{count} duplicado(s)",
  "@scannerPasteDuplicate": { "placeholders": { "count": { "type": "int" } } },

  "passphraseTitle": "Frase de acceso",
  "passphraseAutoGenerate": "Generar automáticamente",
  "passphraseEnterManually": "Ingresar manualmente",
  "passphraseManualHint": "Ingrese su frase de acceso (mínimo 8 caracteres)",
  "passphraseRegenerateTooltip": "Generar nueva frase de acceso",

  "shardLabel": "Fragmento {index} de {total}",
  "@shardLabel": { "placeholders": { "index": { "type": "int" }, "total": { "type": "int" } } },
  "shardSaveTooltip": "Guardar este fragmento",
  "shardShareTooltip": "Compartir este fragmento",
  "shardSaved": "Fragmento guardado",

  "errorSaving": "Error al guardar: {error}",
  "@errorSaving": { "placeholders": { "error": { "type": "String" } } },
  "errorSharing": "Error al compartir: {error}",
  "@errorSharing": { "placeholders": { "error": { "type": "String" } } },

  "errorEmptyQr": "El código QR está vacío.",
  "errorDuplicateShard": "Este fragmento ya ha sido escaneado.",
  "errorParseFailed": "No se pudo analizar el fragmento: {detail}",
  "@errorParseFailed": { "placeholders": { "detail": { "type": "String" } } },
  "errorTitleMismatch": "El título no coincide: se esperaba \"{expected}\", se obtuvo \"{actual}\".",
  "@errorTitleMismatch": { "placeholders": { "expected": { "type": "String" }, "actual": { "type": "String" } } },
  "errorNonceMismatch": "El nonce no coincide: este fragmento pertenece a un secreto diferente.",
  "errorRequiredMismatch": "Los fragmentos requeridos no coinciden: este fragmento pertenece a un conjunto diferente.",
  "errorVersionMismatch": "La versión no coincide: este fragmento pertenece a un conjunto diferente.",
  "errorNotEnoughShards": "Fragmentos insuficientes: se necesitan {required}, se obtuvieron {got}.",
  "@errorNotEnoughShards": { "placeholders": { "required": { "type": "int" }, "got": { "type": "int" } } },
  "errorDecryptionFailed": "No se puede descifrar el secreto. Frase de acceso incorrecta o datos corruptos.",

  "pdfShardLabel": "Fragmento {index} de {total}",
  "@pdfShardLabel": { "placeholders": { "index": { "type": "int" }, "total": { "type": "int" } } },
  "pdfRequiresShards": "Requiere {count} fragmentos para reconstruir",
  "@pdfRequiresShards": { "placeholders": { "count": { "type": "int" } } },
  "pdfPassphrasePlaceholder": "Escriba su frase de acceso aquí: ___________________________",

  "aboutHeading": "Acerca de Banana Split",
  "aboutDescription": "Banana Split le permite dividir de forma segura un secreto —como una contraseña, frase semilla o clave privada— en múltiples fragmentos usando el Esquema de Compartición de Secretos de Shamir.",
  "aboutWhatIsSss": "¿Qué es el Esquema de Compartición de Secretos de Shamir?",
  "aboutSssExplanation": "El Esquema de Compartición de Secretos de Shamir (SSS) es un algoritmo criptográfico inventado por Adi Shamir en 1979. Divide un secreto en N partes (fragmentos) de manera que cualquier K de ellas (el umbral) son suficientes para reconstruir el secreto original, pero K–1 o menos fragmentos no revelan nada sobre el secreto.",
  "aboutHowItWorks": "Cómo funciona Banana Split",
  "aboutHowItWorksBody": "1. Ingresa un secreto y una frase de acceso.\n2. El secreto se cifra con su frase de acceso usando NaCl secretbox (XSalsa20-Poly1305).\n3. Los datos cifrados se dividen en N fragmentos usando el Esquema de Compartición de Secretos de Shamir sobre GF(256).\n4. Cada fragmento se codifica como un código QR que puede imprimir o distribuir a custodios de confianza.\n5. Para recuperar el secreto, escanee al menos K fragmentos e ingrese la frase de acceso. Los fragmentos se recombinan y los datos se descifran.",
  "aboutSecurityNotes": "Notas de seguridad",
  "aboutSecurityNotesBody": "• Todas las operaciones criptográficas ocurren en el dispositivo. Nunca se transmiten datos a un servidor.\n• La frase de acceso añade una capa adicional de protección: incluso si suficientes fragmentos se ven comprometidos, el atacante aún necesita la frase de acceso para descifrar el secreto.\n• Guarde los fragmentos por separado y en lugares físicamente seguros.",
  "aboutVersion": "Versión {version} (Build {build})",
  "@aboutVersion": { "placeholders": { "version": { "type": "String" }, "build": { "type": "String" } } },
  "aboutPrivacyPolicy": "Política de privacidad",
  "aboutLicenses": "Licencias de código abierto",

  "privacyPolicyTitle": "Política de privacidad",
  "privacyPolicyViewOnline": "Ver en línea",
  "privacyPolicyBody": "Política de privacidad de Banana Split\n\nÚltima actualización: marzo de 2026\n\n1. Recopilación de datos\nBanana Split no recopila, almacena ni transmite ningún dato personal. Todas las operaciones criptográficas se realizan íntegramente en su dispositivo.\n\n2. Acceso a la red\nBanana Split no se conecta a ningún servidor. Sus secretos, frases de acceso y fragmentos nunca abandonan su dispositivo, a menos que los exporte o comparta explícitamente usando las funciones de exportación integradas.\n\n3. Acceso a la cámara\nBanana Split solicita acceso a la cámara únicamente para escanear códigos QR que contienen fragmentos. Los datos de la cámara se procesan en el dispositivo y nunca se graban ni transmiten.\n\n4. Almacenamiento\nLos archivos exportados (imágenes PNG, documentos PDF) se guardan en el almacenamiento local de su dispositivo. Usted es responsable de gestionar y proteger estos archivos.\n\n5. Servicios de terceros\nBanana Split no se integra con ningún servicio de análisis, publicidad o seguimiento de terceros.\n\n6. Código abierto\nBanana Split es software de código abierto con licencia GNU General Public License v3.0. El código fuente está disponible en https://github.com/mezinster/banana_split.\n\n7. Contacto\nPara preguntas sobre esta política de privacidad, abra un issue en el repositorio de GitHub.",
  "tabFiles": "Archivos",
  "filesEmpty": "No hay archivos guardados.\nCree fragmentos y guárdelos para verlos aquí.",
  "filesDeleteConfirmTitle": "¿Eliminar archivo?",
  "filesDeleteConfirmBody": "Esto eliminará permanentemente {filename}.",
  "@filesDeleteConfirmBody": { "placeholders": { "filename": { "type": "String" } } },
  "filesDeleteButton": "Eliminar",
  "filesCancelButton": "Cancelar",
  "filesDeleted": "Archivo eliminado",
  "filesShareError": "Error al compartir el archivo",
  "filesDeleteError": "Error al eliminar el archivo",
  "aboutForkNotice": "Esta aplicación es una bifurcación de {repoName} por {author}.",
  "@aboutForkNotice": { "placeholders": { "repoName": { "type": "String" }, "author": { "type": "String" } } },
  "aboutForkCopyright": "Obra original © 2019–2020 Parity Technologies.\nEsta bifurcación © 2026 Evgeny Mezin.",
  "aboutSourceCode": "Código fuente",
  "aboutWebApp": "Aplicación web"
}
```

- [ ] **Step 2: Run `flutter gen-l10n` to verify the ARB is valid**

```bash
cd banana_split_flutter && flutter gen-l10n
```

Expected: exits 0, generates `lib/l10n/app_localizations_es.dart` (and updates `app_localizations.dart`). If it exits non-zero, fix the JSON syntax error it reports before continuing.

- [ ] **Step 3: Commit**

```bash
git add banana_split_flutter/lib/l10n/app_es.arb
git add banana_split_flutter/lib/l10n/
git commit -m "feat: add Spanish locale strings for Flutter app"
```

---

### Task 6: Wire Spanish into the Flutter language picker

**Files:**
- Modify: `banana_split_flutter/lib/widgets/language_selector.dart`

- [ ] **Step 1: Add the Spanish entry to `_localeData`**

In `lib/widgets/language_selector.dart`, find the `_localeData` list (line ~8) and append:

```dart
static const _localeData = [
  (locale: Locale('en'), flag: '🇺🇸', name: 'English'),
  (locale: Locale('ru'), flag: '🇷🇺', name: 'Русский'),
  (locale: Locale('tr'), flag: '🇹🇷', name: 'Türkçe'),
  (locale: Locale('be'), flag: '🇧🇾', name: 'Беларуская'),
  (locale: Locale('ka'), flag: '🇬🇪', name: 'ქართული'),
  (locale: Locale('uk'), flag: '🇺🇦', name: 'Українська'),
  (locale: Locale('pl'), flag: '🇵🇱', name: 'Polski'),
  (locale: Locale('es'), flag: '🇪🇸', name: 'Español'),  // ← add
];
```

- [ ] **Step 2: Run `flutter analyze`**

```bash
cd banana_split_flutter && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Run the Flutter test suite**

```bash
cd banana_split_flutter && sh tests/run_all.sh
```

Expected: all tests pass, summary shows 0 failures.

- [ ] **Step 4: Commit**

```bash
git add banana_split_flutter/lib/widgets/language_selector.dart
git commit -m "feat: add Spanish to Flutter language picker"
```

---

### Task 7: Open the pull request

- [ ] **Step 1: Push the branch**

```bash
git push
```

- [ ] **Step 2: Create the PR linked to issue #2**

```bash
gh pr create \
  --title "feat: add Spanish (es) translation" \
  --body "$(cat <<'EOF'
## Summary

- Adds `src/locales/es.json` with all 69 web app strings translated to Spanish
- Registers `es` in `src/i18n.ts` and `LanguageSelector.vue` (🇪🇸 Español)
- Adds `lib/l10n/app_es.arb` with all 136 Flutter strings translated to Spanish
- Registers `es` in `lib/widgets/language_selector.dart`

Closes #2

## Test plan

- [ ] `yarn lint` passes on web app
- [ ] `yarn test:unit` passes on web app
- [ ] `flutter gen-l10n` succeeds (no missing/extra keys)
- [ ] `flutter analyze` reports no issues
- [ ] `sh tests/run_all.sh` passes in `banana_split_flutter/`
- [ ] Browser set to `es` auto-selects Spanish on page load
- [ ] Flutter language picker shows 🇪🇸 Español and switches UI language

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Expected: PR URL printed. GitHub will show the branch as linked to issue #2.
