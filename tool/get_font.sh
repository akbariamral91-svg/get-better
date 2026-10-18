#!/usr/bin/env bash
# دریافت فونت وزیرمتن (فقط Regular و Bold)، اعتبارسنجی فایل‌ها و ثبت آن‌ها در pubspec.yaml
# اجرا در ریشهٔ پروژه: bash tool/get_font.sh   (نیاز به اینترنت)
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p assets/fonts

# منبع‌ها به ترتیب: مخزن رسمی (GitHub) و آینهٔ npm روی jsDelivr (همان بستهٔ رسمی vazirmatn)
mirrors=(
  "https://github.com/rastikerdar/vazirmatn/raw/v33.003/fonts/ttf"
  "https://github.com/rastikerdar/vazirmatn/raw/master/fonts/ttf"
  "https://cdn.jsdelivr.net/npm/vazirmatn@33.0.3/fonts/ttf"
  "https://cdn.jsdelivr.net/gh/rastikerdar/vazirmatn@v33.003/fonts/ttf"
)

# فایل معتبر یعنی سرفصل TrueType (00 01 00 00) یا OpenType ('OTTO') و حجم بیش از ۵۰ کیلوبایت؛
# صفحهٔ خطای HTML یا فایل خالی هرگز به‌عنوان فونت پذیرفته نمی‌شود.
is_font() {
  local f="$1" magic size
  [ -s "$f" ] || return 1
  size=$(wc -c < "$f")
  [ "$size" -gt 51200 ] || return 1
  magic=$(head -c 4 "$f" | od -An -tx1 | tr -d ' \n')
  [ "$magic" = "00010000" ] || [ "$magic" = "4f54544f" ]
}

for w in Regular Bold; do
  dest="assets/fonts/Vazirmatn-$w.ttf"
  if is_font "$dest"; then echo "Vazirmatn-$w موجود و معتبر است."; continue; fi
  rm -f "$dest"
  ok=0
  for base in "${mirrors[@]}"; do
    tmp="$(mktemp)"
    if curl -fsSL --retry 2 --max-time 60 "$base/Vazirmatn-$w.ttf" -o "$tmp" && is_font "$tmp"; then
      mv "$tmp" "$dest"; ok=1; echo "Vazirmatn-$w از $base دریافت شد."; break
    fi
    rm -f "$tmp"
  done
  if [ "$ok" -ne 1 ]; then
    echo "خطا: دریافت Vazirmatn-$w ممکن نشد (اینترنت یا آدرس را بررسی کن). pubspec تغییر نکرد." >&2
    exit 1
  fi
done

# ثبت در pubspec.yaml فقط وقتی هر دو فایل معتبرند
if ! grep -q '^  fonts:' pubspec.yaml; then
  cat >> pubspec.yaml <<'YAML'
  fonts:
    - family: Vazirmatn
      fonts:
        - asset: assets/fonts/Vazirmatn-Regular.ttf
        - asset: assets/fonts/Vazirmatn-Bold.ttf
          weight: 700
YAML
  echo "بلوک fonts به pubspec.yaml اضافه شد."
fi
if command -v flutter >/dev/null; then flutter pub get; fi
echo "فونت وزیرمتن آماده است."
