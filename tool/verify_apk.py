#!/usr/bin/env python3
"""Check a built APK for the two things this app must ship with: the AdMob
app id that matches the AdMob console, and both locales (en + id).

Reading a binary AndroidManifest or a compiled res/*.xml with plain string
search is unreliable -- attribute *names* live in a UTF-8 string pool while
some compiled values are UTF-16LE, and resource *values* like
`@xml/locales_config` are stored as resource ids, never as text. So this
script looks for every encoding and also checks resources.arsc, where the
resource *name* is kept even in a shrunk release build.

Usage: python3 verify_apk.py build/app/outputs/flutter-apk/app-release.apk
"""
import sys
import zipfile

ADMOB_APP_ID = "ca-app-pub-5168743842779308~5416336913"
LIVE_BANNER = "ca-app-pub-5168743842779308/6314485619"
TEST_BANNER = "ca-app-pub-3940256099942544/6300978111"
ID_STRINGS = ["Bahasa Indonesia", "Ikuti sistem", "Bahasa disimpan"]
EN_STRINGS = ["System default", "Language"]


def pools(blob: bytes, needle: str) -> bool:
    """True if `needle` appears as UTF-8 or UTF-16LE text in `blob`."""
    return needle.encode() in blob or needle.encode("utf-16-le") in blob


def main(path: str) -> int:
    z = zipfile.ZipFile(path)
    names = z.namelist()
    man = z.read("AndroidManifest.xml")
    arsc = z.read("resources.arsc") if "resources.arsc" in names else b""
    so = z.read("lib/arm64-v8a/libapp.so")
    dex = b"".join(z.read(n) for n in names if n.endswith(".dex"))

    checks = [
        ("manifest: AdMob app id", pools(man, ADMOB_APP_ID)),
        ("manifest: APPLICATION_ID meta-data", pools(man, "com.google.android.gms.ads.APPLICATION_ID")),
        ("manifest: localeConfig attribute", pools(man, "localeConfig")),
        ("resources.arsc: locales_config entry", b"locales_config" in arsc),
        ("dex: AdMob sdk classes", pools(dex, "com.google.android.gms.ads.MobileAds")),
        ("libapp.so: live banner unit", LIVE_BANNER.encode() in so),
    ]
    for s in ID_STRINGS:
        checks.append((f"libapp.so: id string {s!r}", s.encode() in so))
    for s in EN_STRINGS:
        checks.append((f"libapp.so: en string {s!r}", s.encode() in so))

    # In a release AOT snapshot `kDebugMode ? test : live` folds to the live id,
    # so the test unit is shed. Its absence is the proof, not a failure -- this
    # line is informational so the summary stays honest about which is which.
    test_shed = TEST_BANNER.encode() not in so
    checks.append(("libapp.so: test unit shed (expected in release)", test_shed))

    # The compiled locales_config.xml is one of the small res/*.xml entries and
    # carries the two locale tags inside its string pool.
    xml_with_locales = [
        n for n in names
        if n.startswith("res/") and n.endswith(".xml") and pools(z.read(n), "locale-config")
    ]
    checks.append(("res/*.xml: compiled locale-config present", bool(xml_with_locales)))

    bad = 0
    for label, ok in checks:
        print(f"  [{'OK ' if ok else 'FAIL'}] {label}")
        bad += 0 if ok else 1
    print(f"  [info] test unit still present: {not test_shed}")
    print(f"\nAPK: {path}")
    print(f"entries: {len(names)}  size: {len(open(path,'rb').read())} bytes")
    if xml_with_locales:
        print(f"locale config resource: {xml_with_locales}")
    print(f"-> {'PASS' if bad == 0 else f'{bad} CHECK(S) FAILED'}")
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1] if len(sys.argv) > 1 else "build/app/outputs/flutter-apk/app-release.apk"))
