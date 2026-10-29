#!/usr/bin/env bash
# Run once after "flutter create": sets Android/Web names and Firebase-friendly minSdk.
set -e
if [ -f android/app/build.gradle.kts ]; then
  G=android/app/build.gradle.kts
  sed -i 's/minSdk = flutter.minSdkVersion/minSdk = maxOf(flutter.minSdkVersion, 23)/' "$G"
else
  G=android/app/build.gradle
  sed -i 's/minSdkVersion flutter.minSdkVersion/minSdkVersion Math.max(flutter.minSdkVersion, 23)/; s/minSdk = flutter.minSdkVersion/minSdk = Math.max(flutter.minSdkVersion, 23)/' "$G"
fi
grep -n "minSdk" "$G" || true

M=android/app/src/main/AndroidManifest.xml
sed -i 's/android:label="bm_work_tracker"/android:label="BM Work Tracker"/' "$M"
grep -q 'android.permission.INTERNET' "$M" || \
  sed -i '0,/<application/s##<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$M"

if [ -f web/index.html ]; then
  sed -i 's#<title>bm_work_tracker</title>#<title>BM Work Tracker</title>#' web/index.html
fi
if [ -f web/manifest.json ]; then
  sed -i 's/"name": "bm_work_tracker"/"name": "BM Work Tracker"/; s/"short_name": "bm_work_tracker"/"short_name": "BM Tracker"/' web/manifest.json
fi
echo "Patched."
