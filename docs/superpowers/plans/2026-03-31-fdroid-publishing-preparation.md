# F-Droid Publishing Preparation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare the Banana Split Flutter app for F-Droid submission — correct application ID, GPLv3 derivative work attribution, fastlane metadata, and anti-features declaration.

**Architecture:** Config changes to Android build files + Kotlin package move, new metadata files in fastlane structure, i18n additions to all 7 ARB files, and About screen UI changes. No crypto or business logic changes.

**Tech Stack:** Flutter/Dart, Gradle, Fastlane metadata format, ARB localization files.

**Spec:** `docs/superpowers/specs/2026-03-31-fdroid-publishing-preparation-design.md`

---

## File Map

### New files
| File | Purpose |
|------|---------|
| `NOTICE` | GPLv3 derivative work copyright notice |
| `banana_split_flutter/.fdroid.yml` | F-Droid anti-features + categories declaration |
| `banana_split_flutter/android/app/src/main/kotlin/com/nfcarchiver/banana_split/MainActivity.kt` | Relocated MainActivity with new package |
| `banana_split_flutter/fastlane/metadata/android/<locale>/title.txt` | App title per locale (7 locales) |
| `banana_split_flutter/fastlane/metadata/android/<locale>/short_description.txt` | Short description per locale |
| `banana_split_flutter/fastlane/metadata/android/<locale>/full_description.txt` | Full description per locale |
| `banana_split_flutter/fastlane/metadata/android/<locale>/changelogs/1.txt` | Changelog for versionCode 1 per locale |

### Modified files
| File | Change |
|------|--------|
| `banana_split_flutter/android/app/build.gradle` | `namespace` + `applicationId` → `com.nfcarchiver.banana_split` |
| `banana_split_flutter/pubspec.yaml` | Update `description` |
| `banana_split_flutter/lib/screens/about_screen.dart` | Add fork attribution section + source code link |
| `banana_split_flutter/lib/l10n/app_en.arb` | Add 3 new i18n keys |
| `banana_split_flutter/lib/l10n/app_ru.arb` | Add 3 new i18n keys |
| `banana_split_flutter/lib/l10n/app_tr.arb` | Add 3 new i18n keys |
| `banana_split_flutter/lib/l10n/app_be.arb` | Add 3 new i18n keys |
| `banana_split_flutter/lib/l10n/app_ka.arb` | Add 3 new i18n keys |
| `banana_split_flutter/lib/l10n/app_uk.arb` | Add 3 new i18n keys |
| `banana_split_flutter/lib/l10n/app_pl.arb` | Add 3 new i18n keys |
| `README.md` | Add fork notice after badges |

### Deleted files
| File | Reason |
|------|--------|
| `banana_split_flutter/android/app/src/main/kotlin/com/example/banana_split_flutter/MainActivity.kt` | Replaced by relocated file |

---

## Task 1: Change Android Application ID

**Files:**
- Modify: `banana_split_flutter/android/app/build.gradle:9,24`
- Create: `banana_split_flutter/android/app/src/main/kotlin/com/nfcarchiver/banana_split/MainActivity.kt`
- Delete: `banana_split_flutter/android/app/src/main/kotlin/com/example/banana_split_flutter/MainActivity.kt`

- [ ] **Step 1: Update build.gradle namespace and applicationId**

In `banana_split_flutter/android/app/build.gradle`, change both occurrences:

```groovy
// Line 9: namespace
namespace = "com.nfcarchiver.banana_split"

// Line 24: applicationId
applicationId = "com.nfcarchiver.banana_split"
```

- [ ] **Step 2: Create new Kotlin directory and move MainActivity**

Create `banana_split_flutter/android/app/src/main/kotlin/com/nfcarchiver/banana_split/MainActivity.kt` with:

```kotlin
package com.nfcarchiver.banana_split

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity()
```

- [ ] **Step 3: Delete old MainActivity directory tree**

Delete the entire old path:
```bash
rm -rf banana_split_flutter/android/app/src/main/kotlin/com/example
```

- [ ] **Step 4: Verify the build compiles**

```bash
cd banana_split_flutter && flutter build apk --debug 2>&1 | tail -5
```

Expected: BUILD SUCCESSFUL (the APK should compile with the new application ID).

- [ ] **Step 5: Commit**

```bash
git add banana_split_flutter/android/app/build.gradle \
  banana_split_flutter/android/app/src/main/kotlin/com/nfcarchiver/banana_split/MainActivity.kt
git rm banana_split_flutter/android/app/src/main/kotlin/com/example/banana_split_flutter/MainActivity.kt
git commit -m "feat: change application ID to com.nfcarchiver.banana_split for F-Droid"
```

---

## Task 2: Update pubspec.yaml Description

**Files:**
- Modify: `banana_split_flutter/pubspec.yaml:2`

- [ ] **Step 1: Replace the placeholder description**

In `banana_split_flutter/pubspec.yaml`, change line 2:

```yaml
description: "Split secrets into QR-code shards using Shamir's Secret Sharing. Offline, open-source, cross-platform."
```

- [ ] **Step 2: Commit**

```bash
git add banana_split_flutter/pubspec.yaml
git commit -m "chore: update pubspec.yaml description from placeholder"
```

---

## Task 3: Add NOTICE File (GPLv3 Derivative Work Attribution)

**Files:**
- Create: `NOTICE` (repo root)

- [ ] **Step 1: Create the NOTICE file**

Create `NOTICE` at the repo root with:

```
Banana Split
Copyright © 2026 Evgeny Mezin

This program is a derivative work (fork) of:
  banana_split — https://github.com/paritytech/banana_split
  Copyright © 2019–2020 Parity Technologies (UK) Ltd.

Both the original work and this derivative are licensed under the
GNU General Public License v3.0. See the LICENSE file for details.
```

- [ ] **Step 2: Commit**

```bash
git add NOTICE
git commit -m "docs: add NOTICE file with GPLv3 derivative work attribution"
```

---

## Task 4: Add Fork Notice to README

**Files:**
- Modify: `README.md:4-5` (insert after the badges block)

- [ ] **Step 1: Insert fork notice after the badges**

In `README.md`, insert a new block between the badge lines (line 4) and the blank line + description (line 6). The result should read:

```markdown
[![Release](https://github.com/mezinster/banana_split/actions/workflows/release.yml/badge.svg)](https://github.com/mezinster/banana_split/actions/workflows/release.yml)

> **Fork Notice:** This project is a fork of [banana_split](https://github.com/paritytech/banana_split) originally developed by [Parity Technologies](https://www.parity.io/). Original work © 2019–2020 Parity Technologies. This fork © 2026 Evgeny Mezin. Licensed under [GPLv3](LICENSE).

Banana Split uses [Shamir's Secret Sharing](https://en.wikipedia.org/wiki/Shamir%27s_Secret_Sharing) to split secrets into QR-code shards. Any majority of shards can reconstruct the secret — fewer reveal nothing.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add fork attribution notice to README"
```

---

## Task 5: Add i18n Keys for About Screen Attribution

**Files:**
- Modify: `banana_split_flutter/lib/l10n/app_en.arb`
- Modify: `banana_split_flutter/lib/l10n/app_ru.arb`
- Modify: `banana_split_flutter/lib/l10n/app_tr.arb`
- Modify: `banana_split_flutter/lib/l10n/app_be.arb`
- Modify: `banana_split_flutter/lib/l10n/app_ka.arb`
- Modify: `banana_split_flutter/lib/l10n/app_uk.arb`
- Modify: `banana_split_flutter/lib/l10n/app_pl.arb`

- [ ] **Step 1: Add keys to app_en.arb**

Add before the closing `}` in `banana_split_flutter/lib/l10n/app_en.arb`:

```json
  "aboutForkNotice": "This app is a fork of {repoName} by {author}.",
  "@aboutForkNotice": { "placeholders": { "repoName": { "type": "String" }, "author": { "type": "String" } } },
  "aboutForkCopyright": "Original work © 2019–2020 Parity Technologies.\nThis fork © 2026 Evgeny Mezin.",
  "aboutSourceCode": "Source Code"
```

- [ ] **Step 2: Add keys to app_ru.arb**

Add before the closing `}`:

```json
  "aboutForkNotice": "Это приложение является форком {repoName} от {author}.",
  "@aboutForkNotice": { "placeholders": { "repoName": { "type": "String" }, "author": { "type": "String" } } },
  "aboutForkCopyright": "Оригинал © 2019–2020 Parity Technologies.\nЭтот форк © 2026 Евгений Мезин.",
  "aboutSourceCode": "Исходный код"
```

- [ ] **Step 3: Add keys to app_tr.arb**

Add before the closing `}`:

```json
  "aboutForkNotice": "Bu uygulama {author} tarafından geliştirilen {repoName} projesinin bir çatalıdır.",
  "@aboutForkNotice": { "placeholders": { "repoName": { "type": "String" }, "author": { "type": "String" } } },
  "aboutForkCopyright": "Orijinal eser © 2019–2020 Parity Technologies.\nBu çatal © 2026 Evgeny Mezin.",
  "aboutSourceCode": "Kaynak Kod"
```

- [ ] **Step 4: Add keys to app_be.arb**

Add before the closing `}`:

```json
  "aboutForkNotice": "Гэта дадатак з'яўляецца форкам {repoName} ад {author}.",
  "@aboutForkNotice": { "placeholders": { "repoName": { "type": "String" }, "author": { "type": "String" } } },
  "aboutForkCopyright": "Арыгінал © 2019–2020 Parity Technologies.\nГэты форк © 2026 Яўген Мезін.",
  "aboutSourceCode": "Зыходны код"
```

- [ ] **Step 5: Add keys to app_ka.arb**

Add before the closing `}`:

```json
  "aboutForkNotice": "ეს აპლიკაცია არის {repoName}-ის ფორკი {author}-ისგან.",
  "@aboutForkNotice": { "placeholders": { "repoName": { "type": "String" }, "author": { "type": "String" } } },
  "aboutForkCopyright": "ორიგინალი © 2019–2020 Parity Technologies.\nეს ფორკი © 2026 ევგენი მეზინი.",
  "aboutSourceCode": "წყაროს კოდი"
```

- [ ] **Step 6: Add keys to app_uk.arb**

Add before the closing `}`:

```json
  "aboutForkNotice": "Цей додаток є форком {repoName} від {author}.",
  "@aboutForkNotice": { "placeholders": { "repoName": { "type": "String" }, "author": { "type": "String" } } },
  "aboutForkCopyright": "Оригінал © 2019–2020 Parity Technologies.\nЦей форк © 2026 Євген Мезін.",
  "aboutSourceCode": "Вихідний код"
```

- [ ] **Step 7: Add keys to app_pl.arb**

Add before the closing `}`:

```json
  "aboutForkNotice": "Ta aplikacja jest forkiem {repoName} autorstwa {author}.",
  "@aboutForkNotice": { "placeholders": { "repoName": { "type": "String" }, "author": { "type": "String" } } },
  "aboutForkCopyright": "Oryginał © 2019–2020 Parity Technologies.\nTen fork © 2026 Evgeny Mezin.",
  "aboutSourceCode": "Kod źródłowy"
```

- [ ] **Step 8: Run flutter gen-l10n to regenerate**

```bash
cd banana_split_flutter && flutter gen-l10n
```

Expected: No errors. Generated files updated in `.dart_tool/flutter_gen/gen_l10n/`.

- [ ] **Step 9: Commit**

```bash
git add banana_split_flutter/lib/l10n/app_*.arb
git commit -m "i18n: add fork attribution and source code keys for all 7 locales"
```

---

## Task 6: Update About Screen with Fork Attribution and Source Code Link

**Files:**
- Modify: `banana_split_flutter/lib/screens/about_screen.dart`

- [ ] **Step 1: Add url_launcher import**

Add at the top of `about_screen.dart`, after the existing imports:

```dart
import 'package:url_launcher/url_launcher.dart';
```

- [ ] **Step 2: Add fork attribution section**

In `about_screen.dart`, insert the following widgets between the `aboutSecurityNotesBody` Text widget and the `Divider(height: 32)` (i.e., between lines 32 and 33):

```dart
          const SizedBox(height: 16),
          Text(
            l10n.aboutForkNotice('banana_split', 'Parity Technologies'),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.aboutForkCopyright,
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => launchUrl(
              Uri.parse('https://github.com/paritytech/banana_split'),
              mode: LaunchMode.externalApplication,
            ),
            child: Text(
              'github.com/paritytech/banana_split',
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
```

- [ ] **Step 3: Add source code ListTile**

Insert a new `ListTile` after the existing "Open-source licenses" ListTile (after line 75 in the original file):

```dart
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(l10n.aboutSourceCode),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => launchUrl(
              Uri.parse('https://github.com/mezinster/banana_split'),
              mode: LaunchMode.externalApplication,
            ),
          ),
```

- [ ] **Step 4: Verify the app builds and the About screen renders**

```bash
cd banana_split_flutter && flutter build apk --debug 2>&1 | tail -5
```

Expected: BUILD SUCCESSFUL.

- [ ] **Step 5: Commit**

```bash
git add banana_split_flutter/lib/screens/about_screen.dart
git commit -m "feat: add fork attribution and source code link to About screen"
```

---

## Task 7: Create .fdroid.yml Anti-Features Declaration

**Files:**
- Create: `banana_split_flutter/.fdroid.yml`

- [ ] **Step 1: Create the .fdroid.yml file**

Create `banana_split_flutter/.fdroid.yml`:

```yaml
Categories:
  - Security
  - Connectivity
  - System

AntiFeatures:
  NonFreeDep:
    en-US: |
      Uses Google ML Kit (via mobile_scanner package) for QR code scanning on Android.
      ML Kit is a proprietary Google library bundled in the APK.
      A pure open-source alternative (zxing2) is used on Windows/Linux.
```

- [ ] **Step 2: Commit**

```bash
git add banana_split_flutter/.fdroid.yml
git commit -m "feat: add .fdroid.yml with anti-features and categories for F-Droid"
```

---

## Task 8: Create Fastlane Metadata — English (en-US)

**Files:**
- Create: `banana_split_flutter/fastlane/metadata/android/en-US/title.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/en-US/short_description.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/en-US/full_description.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/en-US/changelogs/1.txt`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p banana_split_flutter/fastlane/metadata/android/en-US/changelogs
```

- [ ] **Step 2: Create title.txt**

```
Banana Split
```

- [ ] **Step 3: Create short_description.txt**

```
Split secrets into QR-code shards using Shamir's Secret Sharing
```

(64 chars — under the 80 char limit)

- [ ] **Step 4: Create full_description.txt**

```
Banana Split uses Shamir's Secret Sharing to split secrets into QR-code shards. Any majority of shards can reconstruct the secret — fewer reveal nothing.

<b>How it works</b>

1. Enter your secret (e.g., a seed phrase, private key, password).
2. Choose how many shards to create and how many are required to reconstruct.
3. Use the auto-generated passphrase or enter your own.
4. Banana Split encrypts the secret with the passphrase, then splits the ciphertext into N QR codes using Shamir's scheme.
5. Print or save the QR codes. Write the passphrase by hand on every sheet.

To reconstruct: scan a majority of QR code shards, enter the passphrase, and your secret is restored.

<b>Features</b>

• Offline — all cryptography happens on-device, no server communication
• Save shards as PNGs or PDF with full Unicode font support
• Camera and gallery QR scanning with multi-file import
• Custom or auto-generated passphrases
• User-selectable quorum (how many shards needed)
• 7 languages: English, Russian, Turkish, Belarusian, Georgian, Ukrainian, Polish
• Cross-platform shard compatibility with the Banana Split web app

<b>Security</b>

Encryption: scrypt key derivation + NaCl secretbox (XSalsa20-Poly1305).
Splitting: Shamir's Secret Sharing over GF(256).
No data collection, no analytics, no trackers.

<b>Open Source</b>

This app is a fork of banana_split by Parity Technologies, licensed under GPLv3.
Source code: https://github.com/mezinster/banana_split
```

- [ ] **Step 5: Create changelogs/1.txt**

```
• Polish language support — full translations for all 131 UI strings
• Multi-method shard input: camera, gallery import, and paste text mode
• Save shards as PNGs or PDF with Unicode font support
• 7 languages: English, Russian, Turkish, Belarusian, Georgian, Ukrainian, Polish
• Cross-platform shard compatibility with the web app
```

- [ ] **Step 6: Commit**

```bash
git add banana_split_flutter/fastlane/
git commit -m "feat: add fastlane metadata for F-Droid (en-US)"
```

---

## Task 9: Create Fastlane Metadata — Russian (ru)

**Files:**
- Create: `banana_split_flutter/fastlane/metadata/android/ru/title.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/ru/short_description.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/ru/full_description.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/ru/changelogs/1.txt`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p banana_split_flutter/fastlane/metadata/android/ru/changelogs
```

- [ ] **Step 2: Create title.txt**

```
Banana Split
```

- [ ] **Step 3: Create short_description.txt**

```
Разделите секреты на QR-фрагменты с помощью схемы Шамира
```

- [ ] **Step 4: Create full_description.txt**

```
Banana Split использует схему разделения секрета Шамира для разбиения секретов на QR-фрагменты. Любое большинство фрагментов позволяет восстановить секрет — меньшее количество не раскрывает ничего.

<b>Как это работает</b>

1. Введите секрет (например, сид-фразу, приватный ключ, пароль).
2. Выберите количество фрагментов и сколько нужно для восстановления.
3. Используйте автоматически сгенерированную парольную фразу или введите свою.
4. Banana Split шифрует секрет парольной фразой, затем разбивает шифротекст на N QR-кодов по схеме Шамира.
5. Распечатайте или сохраните QR-коды. Напишите парольную фразу от руки на каждом листе.

Для восстановления: отсканируйте большинство QR-фрагментов, введите парольную фразу — секрет восстановлен.

<b>Возможности</b>

• Офлайн — вся криптография выполняется на устройстве, без связи с сервером
• Сохранение фрагментов в формате PNG или PDF с поддержкой Unicode
• Сканирование QR камерой и импорт из галереи
• Пользовательская или автоматическая парольная фраза
• Настраиваемый кворум (сколько фрагментов нужно)
• 7 языков: английский, русский, турецкий, белорусский, грузинский, украинский, польский
• Совместимость фрагментов с веб-приложением Banana Split

<b>Безопасность</b>

Шифрование: scrypt + NaCl secretbox (XSalsa20-Poly1305).
Разделение: схема Шамира над GF(256).
Без сбора данных, аналитики и трекеров.

<b>Открытый исходный код</b>

Это приложение — форк banana_split от Parity Technologies, лицензия GPLv3.
Исходный код: https://github.com/mezinster/banana_split
```

- [ ] **Step 5: Create changelogs/1.txt**

```
• Поддержка польского языка — полный перевод всех 131 строк интерфейса
• Многорежимный ввод фрагментов: камера, импорт из галереи, вставка текста
• Сохранение фрагментов в PNG или PDF с поддержкой Unicode-шрифтов
• 7 языков: английский, русский, турецкий, белорусский, грузинский, украинский, польский
• Совместимость фрагментов с веб-приложением
```

- [ ] **Step 6: Commit**

```bash
git add banana_split_flutter/fastlane/metadata/android/ru/
git commit -m "feat: add fastlane metadata for F-Droid (ru)"
```

---

## Task 10: Create Fastlane Metadata — Turkish (tr)

**Files:**
- Create: `banana_split_flutter/fastlane/metadata/android/tr/title.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/tr/short_description.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/tr/full_description.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/tr/changelogs/1.txt`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p banana_split_flutter/fastlane/metadata/android/tr/changelogs
```

- [ ] **Step 2: Create title.txt**

```
Banana Split
```

- [ ] **Step 3: Create short_description.txt**

```
Shamir'in Gizli Paylaşımı ile sırları QR kod parçalarına bölün
```

- [ ] **Step 4: Create full_description.txt**

```
Banana Split, sırları QR kod parçalarına bölmek için Shamir'in Gizli Paylaşımı algoritmasını kullanır. Parçaların çoğunluğu sırrı yeniden oluşturabilir — daha azı hiçbir şey açığa çıkarmaz.

<b>Nasıl çalışır</b>

1. Sırrınızı girin (örn. tohum ifadesi, özel anahtar, şifre).
2. Kaç parça oluşturulacağını ve yeniden oluşturma için kaç tane gerektiğini seçin.
3. Otomatik oluşturulan parolayı kullanın veya kendinizinkini girin.
4. Banana Split sırrı parolayla şifreler, ardından şifreli metni Shamir şeması ile N QR koduna böler.
5. QR kodları yazdırın veya kaydedin. Parolayı her sayfaya elle yazın.

Yeniden oluşturmak için: QR kod parçalarının çoğunluğunu tarayın, parolayı girin — sırrınız geri yüklenir.

<b>Özellikler</b>

• Çevrimdışı — tüm kriptografi cihazda gerçekleşir, sunucu bağlantısı yok
• Parçaları PNG veya PDF olarak kaydetme, Unicode yazı tipi desteği
• Kamera ve galeri QR tarama, çoklu dosya içe aktarma
• Özel veya otomatik oluşturulan parola
• Ayarlanabilir çoğunluk (kaç parça gerekli)
• 7 dil: İngilizce, Rusça, Türkçe, Belarusça, Gürcüce, Ukraynaca, Lehçe
• Banana Split web uygulaması ile parça uyumluluğu

<b>Güvenlik</b>

Şifreleme: scrypt + NaCl secretbox (XSalsa20-Poly1305).
Bölme: GF(256) üzerinde Shamir'in Gizli Paylaşımı.
Veri toplama, analitik veya izleyici yok.

<b>Açık Kaynak</b>

Bu uygulama Parity Technologies tarafından geliştirilen banana_split'in bir çatalıdır, GPLv3 lisansı altındadır.
Kaynak kod: https://github.com/mezinster/banana_split
```

- [ ] **Step 5: Create changelogs/1.txt**

```
• Lehçe dil desteği — tüm 131 arayüz dizesinin tam çevirisi
• Çok yöntemli parça girişi: kamera, galeri içe aktarma ve metin yapıştırma
• Parçaları PNG veya PDF olarak kaydetme, Unicode yazı tipi desteği
• 7 dil: İngilizce, Rusça, Türkçe, Belarusça, Gürcüce, Ukraynaca, Lehçe
• Web uygulaması ile parça uyumluluğu
```

- [ ] **Step 6: Commit**

```bash
git add banana_split_flutter/fastlane/metadata/android/tr/
git commit -m "feat: add fastlane metadata for F-Droid (tr)"
```

---

## Task 11: Create Fastlane Metadata — Belarusian (be)

**Files:**
- Create: `banana_split_flutter/fastlane/metadata/android/be/title.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/be/short_description.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/be/full_description.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/be/changelogs/1.txt`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p banana_split_flutter/fastlane/metadata/android/be/changelogs
```

- [ ] **Step 2: Create title.txt**

```
Banana Split
```

- [ ] **Step 3: Create short_description.txt**

```
Падзяліце сакрэты на QR-фрагменты з дапамогай схемы Шаміра
```

- [ ] **Step 4: Create full_description.txt**

```
Banana Split выкарыстоўвае схему сакрэтнага падзелу Шаміра для разбіцця сакрэтаў на QR-фрагменты. Любая большасць фрагментаў дазваляе аднавіць сакрэт — менш не раскрывае нічога.

<b>Як гэта працуе</b>

1. Увядзіце сакрэт (напрыклад, сід-фразу, прыватны ключ, пароль).
2. Абярыце колькасць фрагментаў і колькі трэба для аднаўлення.
3. Выкарыстоўвайце аўтаматычна згенераваную парольную фразу або ўвядзіце сваю.
4. Banana Split шыфруе сакрэт парольнай фразай, затым разбівае шыфратэкст на N QR-кодаў па схеме Шаміра.
5. Надрукуйце або захавайце QR-коды. Напішыце парольную фразу ўручную на кожным лісце.

Для аднаўлення: адсканіруйце большасць QR-фрагментаў, увядзіце парольную фразу — сакрэт адноўлены.

<b>Магчымасці</b>

• Афлайн — уся крыптаграфія выконваецца на прыладзе, без сувязі з серверам
• Захаванне фрагментаў у фармаце PNG або PDF з падтрымкай Unicode
• Сканаванне QR камерай і імпарт з галерэі
• Карыстальніцкая або аўтаматычная парольная фраза
• Настройваемы кворум (колькі фрагментаў патрэбна)
• 7 моў: англійская, руская, турэцкая, беларуская, грузінская, украінская, польская
• Сумяшчальнасць фрагментаў з вэб-дадаткам Banana Split

<b>Бяспека</b>

Шыфраванне: scrypt + NaCl secretbox (XSalsa20-Poly1305).
Падзел: схема Шаміра над GF(256).
Без збору даных, аналітыкі і трэкераў.

<b>Адкрыты зыходны код</b>

Гэта дадатак — форк banana_split ад Parity Technologies, ліцэнзія GPLv3.
Зыходны код: https://github.com/mezinster/banana_split
```

- [ ] **Step 5: Create changelogs/1.txt**

```
• Падтрымка польскай мовы — поўны пераклад усіх 131 радкоў інтэрфейсу
• Шматрэжымны ўвод фрагментаў: камера, імпарт з галерэі, устаўка тэксту
• Захаванне фрагментаў у PNG або PDF з падтрымкай Unicode-шрыфтоў
• 7 моў: англійская, руская, турэцкая, беларуская, грузінская, украінская, польская
• Сумяшчальнасць фрагментаў з вэб-дадаткам
```

- [ ] **Step 6: Commit**

```bash
git add banana_split_flutter/fastlane/metadata/android/be/
git commit -m "feat: add fastlane metadata for F-Droid (be)"
```

---

## Task 12: Create Fastlane Metadata — Georgian (ka)

**Files:**
- Create: `banana_split_flutter/fastlane/metadata/android/ka/title.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/ka/short_description.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/ka/full_description.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/ka/changelogs/1.txt`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p banana_split_flutter/fastlane/metadata/android/ka/changelogs
```

- [ ] **Step 2: Create title.txt**

```
Banana Split
```

- [ ] **Step 3: Create short_description.txt**

```
გაყავით საიდუმლოებები QR-კოდის ფრაგმენტებად შამირის სქემით
```

- [ ] **Step 4: Create full_description.txt**

```
Banana Split იყენებს შამირის საიდუმლო გაზიარების სქემას საიდუმლოებების QR-კოდის ფრაგმენტებად დასაყოფად. ფრაგმენტების უმრავლესობა საშუალებას იძლევა აღადგინოთ საიდუმლო — ნაკლები არაფერს ამჟღავნებს.

<b>როგორ მუშაობს</b>

1. შეიყვანეთ საიდუმლო (მაგ., სიდ-ფრაზა, პირადი გასაღები, პაროლი).
2. აირჩიეთ ფრაგმენტების რაოდენობა და რამდენია საჭირო აღდგენისთვის.
3. გამოიყენეთ ავტომატურად გენერირებული პაროლი ან შეიყვანეთ საკუთარი.
4. Banana Split შიფრავს საიდუმლოს პაროლით, შემდეგ ყოფს შიფრტექსტს N QR-კოდად შამირის სქემით.
5. დაბეჭდეთ ან შეინახეთ QR-კოდები. დაწერეთ პაროლი ხელით ყველა ფურცელზე.

აღდგენისთვის: დაასკანერეთ QR-ფრაგმენტების უმრავლესობა, შეიყვანეთ პაროლი — საიდუმლო აღდგენილია.

<b>შესაძლებლობები</b>

• ოფლაინ — ყველა კრიპტოგრაფია ხორციელდება მოწყობილობაზე, სერვერთან კავშირი არ არის
• ფრაგმენტების შენახვა PNG ან PDF ფორმატში Unicode მხარდაჭერით
• QR სკანირება კამერით და გალერეიდან იმპორტი
• მორგებული ან ავტომატური პაროლი
• კონფიგურირებადი კვორუმი (რამდენი ფრაგმენტია საჭირო)
• 7 ენა: ინგლისური, რუსული, თურქული, ბელარუსული, ქართული, უკრაინული, პოლონური
• ფრაგმენტების თავსებადობა Banana Split ვებ-აპლიკაციასთან

<b>უსაფრთხოება</b>

დაშიფვრა: scrypt + NaCl secretbox (XSalsa20-Poly1305).
დაყოფა: შამირის სქემა GF(256)-ზე.
მონაცემების შეგროვება, ანალიტიკა ან ტრეკერები არ არის.

<b>ღია წყაროს კოდი</b>

ეს აპლიკაცია არის Parity Technologies-ის banana_split-ის ფორკი, GPLv3 ლიცენზიით.
წყაროს კოდი: https://github.com/mezinster/banana_split
```

- [ ] **Step 5: Create changelogs/1.txt**

```
• პოლონური ენის მხარდაჭერა — ინტერფეისის ყველა 131 სტრიქონის სრული თარგმანი
• მრავალრეჟიმიანი ფრაგმენტების შეყვანა: კამერა, გალერეიდან იმპორტი, ტექსტის ჩასმა
• ფრაგმენტების შენახვა PNG ან PDF ფორმატში Unicode შრიფტების მხარდაჭერით
• 7 ენა: ინგლისური, რუსული, თურქული, ბელარუსული, ქართული, უკრაინული, პოლონური
• ვებ-აპლიკაციასთან ფრაგმენტების თავსებადობა
```

- [ ] **Step 6: Commit**

```bash
git add banana_split_flutter/fastlane/metadata/android/ka/
git commit -m "feat: add fastlane metadata for F-Droid (ka)"
```

---

## Task 13: Create Fastlane Metadata — Ukrainian (uk)

**Files:**
- Create: `banana_split_flutter/fastlane/metadata/android/uk/title.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/uk/short_description.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/uk/full_description.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/uk/changelogs/1.txt`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p banana_split_flutter/fastlane/metadata/android/uk/changelogs
```

- [ ] **Step 2: Create title.txt**

```
Banana Split
```

- [ ] **Step 3: Create short_description.txt**

```
Розділіть секрети на QR-фрагменти за допомогою схеми Шаміра
```

- [ ] **Step 4: Create full_description.txt**

```
Banana Split використовує схему секретного розділення Шаміра для розбиття секретів на QR-фрагменти. Будь-яка більшість фрагментів дозволяє відновити секрет — менше не розкриває нічого.

<b>Як це працює</b>

1. Введіть секрет (наприклад, сід-фразу, приватний ключ, пароль).
2. Оберіть кількість фрагментів і скільки потрібно для відновлення.
3. Використовуйте автоматично згенеровану парольну фразу або введіть свою.
4. Banana Split шифрує секрет парольною фразою, потім розбиває шифротекст на N QR-кодів за схемою Шаміра.
5. Надрукуйте або збережіть QR-коди. Напишіть парольну фразу вручну на кожному аркуші.

Для відновлення: відскануйте більшість QR-фрагментів, введіть парольну фразу — секрет відновлено.

<b>Можливості</b>

• Офлайн — уся криптографія виконується на пристрої, без зв'язку з сервером
• Збереження фрагментів у форматі PNG або PDF з підтримкою Unicode
• Сканування QR камерою та імпорт з галереї
• Користувацька або автоматична парольна фраза
• Налаштовуваний кворум (скільки фрагментів потрібно)
• 7 мов: англійська, російська, турецька, білоруська, грузинська, українська, польська
• Сумісність фрагментів з веб-додатком Banana Split

<b>Безпека</b>

Шифрування: scrypt + NaCl secretbox (XSalsa20-Poly1305).
Розділення: схема Шаміра над GF(256).
Без збору даних, аналітики та трекерів.

<b>Відкритий вихідний код</b>

Цей додаток — форк banana_split від Parity Technologies, ліцензія GPLv3.
Вихідний код: https://github.com/mezinster/banana_split
```

- [ ] **Step 5: Create changelogs/1.txt**

```
• Підтримка польської мови — повний переклад усіх 131 рядків інтерфейсу
• Багаторежимне введення фрагментів: камера, імпорт з галереї, вставка тексту
• Збереження фрагментів у PNG або PDF з підтримкою Unicode-шрифтів
• 7 мов: англійська, російська, турецька, білоруська, грузинська, українська, польська
• Сумісність фрагментів з веб-додатком
```

- [ ] **Step 6: Commit**

```bash
git add banana_split_flutter/fastlane/metadata/android/uk/
git commit -m "feat: add fastlane metadata for F-Droid (uk)"
```

---

## Task 14: Create Fastlane Metadata — Polish (pl)

**Files:**
- Create: `banana_split_flutter/fastlane/metadata/android/pl/title.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/pl/short_description.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/pl/full_description.txt`
- Create: `banana_split_flutter/fastlane/metadata/android/pl/changelogs/1.txt`

- [ ] **Step 1: Create directory structure**

```bash
mkdir -p banana_split_flutter/fastlane/metadata/android/pl/changelogs
```

- [ ] **Step 2: Create title.txt**

```
Banana Split
```

- [ ] **Step 3: Create short_description.txt**

```
Podziel sekrety na fragmenty QR za pomocą schematu Shamira
```

- [ ] **Step 4: Create full_description.txt**

```
Banana Split wykorzystuje schemat dzielenia sekretów Shamira do podziału sekretów na fragmenty QR. Większość fragmentów pozwala odtworzyć sekret — mniejsza liczba nie ujawnia niczego.

<b>Jak to działa</b>

1. Wprowadź sekret (np. frazę seed, klucz prywatny, hasło).
2. Wybierz liczbę fragmentów i ile jest potrzebnych do odtworzenia.
3. Użyj automatycznie wygenerowanego hasła lub wprowadź własne.
4. Banana Split szyfruje sekret hasłem, a następnie dzieli szyfrogramu na N kodów QR za pomocą schematu Shamira.
5. Wydrukuj lub zapisz kody QR. Napisz hasło ręcznie na każdej stronie.

Aby odtworzyć: zeskanuj większość fragmentów QR, wprowadź hasło — sekret zostanie przywrócony.

<b>Funkcje</b>

• Offline — cała kryptografia odbywa się na urządzeniu, bez połączenia z serwerem
• Zapisywanie fragmentów jako PNG lub PDF z obsługą czcionek Unicode
• Skanowanie QR kamerą i import z galerii z obsługą wielu plików
• Własne lub automatycznie generowane hasło
• Konfigurowalny próg (ile fragmentów potrzeba)
• 7 języków: angielski, rosyjski, turecki, białoruski, gruziński, ukraiński, polski
• Kompatybilność fragmentów z aplikacją webową Banana Split

<b>Bezpieczeństwo</b>

Szyfrowanie: scrypt + NaCl secretbox (XSalsa20-Poly1305).
Podział: schemat Shamira nad GF(256).
Bez zbierania danych, analityki ani trackerów.

<b>Otwarte źródło</b>

Ta aplikacja jest forkiem banana_split autorstwa Parity Technologies, licencja GPLv3.
Kod źródłowy: https://github.com/mezinster/banana_split
```

- [ ] **Step 5: Create changelogs/1.txt**

```
• Obsługa języka polskiego — pełne tłumaczenie wszystkich 131 ciągów interfejsu
• Wielometodowe wprowadzanie fragmentów: kamera, import z galerii, wklejanie tekstu
• Zapisywanie fragmentów jako PNG lub PDF z obsługą czcionek Unicode
• 7 języków: angielski, rosyjski, turecki, białoruski, gruziński, ukraiński, polski
• Kompatybilność fragmentów z aplikacją webową
```

- [ ] **Step 6: Commit**

```bash
git add banana_split_flutter/fastlane/metadata/android/pl/
git commit -m "feat: add fastlane metadata for F-Droid (pl)"
```

---

## Task 15: Run Tests and Final Verification

**Files:** None (verification only)

- [ ] **Step 1: Run Flutter analyze**

```bash
cd banana_split_flutter && flutter analyze
```

Expected: No issues found.

- [ ] **Step 2: Run Flutter tests**

```bash
cd banana_split_flutter && sh tests/run_all.sh
```

Expected: All tests pass (no crypto or logic changes were made).

- [ ] **Step 3: Verify Android debug build**

```bash
cd banana_split_flutter && flutter build apk --debug 2>&1 | tail -5
```

Expected: BUILD SUCCESSFUL with application ID `com.nfcarchiver.banana_split`.

- [ ] **Step 4: Verify fastlane directory structure**

```bash
find banana_split_flutter/fastlane -type f | sort
```

Expected: 28 files (4 per locale × 7 locales).

- [ ] **Step 5: Verify all short_description.txt files are under 80 characters**

```bash
for f in banana_split_flutter/fastlane/metadata/android/*/short_description.txt; do
  len=$(wc -c < "$f")
  echo "$f: $len chars"
done
```

Expected: All under 80 characters.
