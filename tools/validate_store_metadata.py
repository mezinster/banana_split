#!/usr/bin/env python3
"""Validate the F-Droid metadata and the fastlane store listings.

Neither CI workflow used to look at fastlane/ or fdroid/, which is how the
0.8.5 release managed to go out with an unbumped versionCode and no changelogs.
Run locally with:

    python3 tools/validate_store_metadata.py

Exits non-zero and prints every problem it found, rather than stopping at the
first one — a release checklist is more useful complete than early.
"""

import os
import re
import sys

import yaml

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUBSPEC = os.path.join(REPO, "banana_split_flutter", "pubspec.yaml")
FDROID = os.path.join(REPO, "fdroid", "com.nfcarchiver.banana_split.yml")
LISTINGS = os.path.join(REPO, "fastlane", "metadata", "android")
ARB_DIR = os.path.join(REPO, "banana_split_flutter", "lib", "l10n")

# F-Droid renders changelogs in a fixed-width column and truncates past this.
CHANGELOG_MAX_CHARS = 500
REQUIRED_LISTING_FILES = ("title.txt", "short_description.txt", "full_description.txt")

problems = []


def fail(msg):
    problems.append(msg)


def read_pubspec_version():
    """Return (versionName, versionCode) from the committed pubspec."""
    with open(PUBSPEC, encoding="utf-8") as fh:
        for line in fh:
            m = re.match(r"^version:\s*(\S+)\+(\d+)\s*$", line)
            if m:
                return m.group(1), int(m.group(2))
    fail("pubspec.yaml has no 'version: <name>+<code>' line")
    return None, None


def check_fdroid(version_name, version_code):
    with open(FDROID, encoding="utf-8") as fh:
        meta = yaml.safe_load(fh)

    builds = meta.get("Builds") or []
    if not builds:
        fail("fdroid metadata has no Builds entries")
        return

    codes = [b.get("versionCode") for b in builds]
    dupes = {c for c in codes if codes.count(c) > 1}
    if dupes:
        fail("fdroid metadata has duplicate versionCode(s): %s" % sorted(dupes))

    for b in builds:
        for key in ("versionName", "versionCode", "commit", "subdir"):
            if not b.get(key):
                fail("fdroid build %s is missing '%s'" % (b.get("versionName", "?"), key))
        commit = str(b.get("commit", ""))
        if commit and not re.fullmatch(r"[0-9a-f]{40}", commit):
            fail(
                "fdroid build %s pins commit '%s' — expected a full 40-char sha"
                % (b.get("versionName"), commit)
            )

    cur_code = meta.get("CurrentVersionCode")
    cur_name = str(meta.get("CurrentVersion"))

    # F-Droid's UpdateCheckData reads the versionCode out of the committed
    # pubspec. If CurrentVersionCode runs ahead of it, F-Droid believes it has
    # already shipped a build that does not exist in the tree.
    if cur_code is not None and version_code is not None and cur_code > version_code:
        fail(
            "fdroid CurrentVersionCode (%s) is ahead of pubspec versionCode (%s)"
            % (cur_code, version_code)
        )

    if cur_code is not None and cur_code not in codes:
        fail(
            "fdroid CurrentVersionCode (%s) has no matching build entry (have %s)"
            % (cur_code, sorted(c for c in codes if c is not None))
        )

    if cur_code is not None and cur_name:
        match = [b for b in builds if b.get("versionCode") == cur_code]
        if match and str(match[0].get("versionName")) != cur_name:
            fail(
                "fdroid CurrentVersion '%s' disagrees with the versionCode %s build entry ('%s')"
                % (cur_name, cur_code, match[0].get("versionName"))
            )


def check_listings(version_code):
    if not os.path.isdir(LISTINGS):
        fail("missing fastlane listings directory: %s" % LISTINGS)
        return

    locales = sorted(
        d for d in os.listdir(LISTINGS) if os.path.isdir(os.path.join(LISTINGS, d))
    )
    if not locales:
        fail("no locale directories under %s" % LISTINGS)
        return

    for loc in locales:
        base = os.path.join(LISTINGS, loc)

        for name in REQUIRED_LISTING_FILES:
            path = os.path.join(base, name)
            if not os.path.isfile(path):
                fail("%s: missing %s" % (loc, name))
                continue
            with open(path, encoding="utf-8") as fh:
                if not fh.read().strip():
                    fail("%s: %s is empty" % (loc, name))

        if version_code is None:
            continue

        changelog = os.path.join(base, "changelogs", "%d.txt" % version_code)
        if not os.path.isfile(changelog):
            fail(
                "%s: no changelog for versionCode %d (expected changelogs/%d.txt)"
                % (loc, version_code, version_code)
            )
            continue

        with open(changelog, encoding="utf-8") as fh:
            text = fh.read()
        if not text.strip():
            fail("%s: changelogs/%d.txt is empty" % (loc, version_code))
        elif len(text) > CHANGELOG_MAX_CHARS:
            fail(
                "%s: changelogs/%d.txt is %d chars, over F-Droid's %d limit"
                % (loc, version_code, len(text), CHANGELOG_MAX_CHARS)
            )

    return locales


def check_app_locales_have_listings(store_locales):
    """Every language the app ships in needs a store listing.

    This is the check that would have caught the Spanish release: app_es.arb
    was added and the app shipped in Spanish, but fastlane had no es-ES
    directory, so Spanish users saw an English store page. Iterating the
    listing directories alone cannot catch a listing that was never created.
    """
    if not os.path.isdir(ARB_DIR):
        fail("missing ARB directory: %s" % ARB_DIR)
        return

    app_locales = set()
    for name in os.listdir(ARB_DIR):
        m = re.fullmatch(r"app_([A-Za-z]{2,3})\.arb", name)
        if m:
            app_locales.add(m.group(1).lower())

    if not app_locales:
        fail("no app_<locale>.arb files found in %s" % ARB_DIR)
        return

    # Store dirs are region-qualified (es-ES, ka-GE) or bare (uk); compare on
    # the language subtag only.
    store_languages = {loc.split("-")[0].lower() for loc in store_locales}

    for lang in sorted(app_locales - store_languages):
        fail(
            "app ships locale '%s' (app_%s.arb) but no fastlane store listing exists for it"
            % (lang, lang)
        )

    for lang in sorted(store_languages - app_locales):
        fail(
            "fastlane has a store listing for '%s' but the app has no app_%s.arb"
            % (lang, lang)
        )

    print("app locales: %s" % ", ".join(sorted(app_locales)))


def main():
    version_name, version_code = read_pubspec_version()
    print("pubspec version: %s+%s" % (version_name, version_code))

    check_fdroid(version_name, version_code)
    locales = check_listings(version_code) or []
    print("store locales checked: %s" % ", ".join(locales))
    check_app_locales_have_listings(locales)

    if problems:
        print("\n%d problem(s):" % len(problems), file=sys.stderr)
        for p in problems:
            print("  - %s" % p, file=sys.stderr)
        return 1

    print("\nstore metadata OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
