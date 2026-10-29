// SETUP GUIDE STEP 3: paste your Firebase values here.
//
// ANDROID values come from the google-services.json file Firebase gives you:
//   apiKey            -> "AIzaSyA8inRvH8H0BGJBQ54RDzFqyfJh1fO6prw"
//   appId             ->  "1:995974469429:android:6a3a5c6b434262bf181e7c"
//   messagingSenderId ->  "995974469429"
//   projectId         -> "bm-work-tracker-22cbb"
//   storageBucket     -> "bm-work-tracker-22cbb.firebasestorage.app"
//
// WEB values come from Firebase console > Project settings > Your apps >
// (Web app) > "SDK setup and configuration" > Config  (the firebaseConfig block).
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

const androidOptions = FirebaseOptions(
  apiKey: 'PASTE_ANDROID_API_KEY',
  appId: 'PASTE_ANDROID_APP_ID',
  messagingSenderId: 'PASTE_PROJECT_NUMBER',
  projectId: 'PASTE_PROJECT_ID',
  storageBucket: 'PASTE_STORAGE_BUCKET',
);

const webOptions = FirebaseOptions(
  apiKey: 'PASTE_WEB_API_KEY',
  appId: 'PASTE_WEB_APP_ID',
  messagingSenderId: 'PASTE_PROJECT_NUMBER',
  projectId: 'PASTE_PROJECT_ID',
  authDomain: 'PASTE_PROJECT_ID.firebaseapp.com',
  storageBucket: 'PASTE_STORAGE_BUCKET',
);

FirebaseOptions get currentFirebaseOptions => kIsWeb ? webOptions : androidOptions;
