#!/usr/bin/env bash
# اجرا در ریشهٔ پروژه: bash setup.sh
set -e
if ! command -v flutter >/dev/null; then echo "Flutter نصب نیست."; exit 1; fi
# فایل‌های بومی اندروید را می‌سازد (به lib و pubspec دست نمی‌زند)
flutter create --platforms=android --project-name masir_ghabuli --org ir.masir .
cp android_overrides/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
flutter pub get
echo
echo "مرحلهٔ دستی: coreLibraryDesugaring را طبق README به android/app/build.gradle(.kts) اضافه کن."
