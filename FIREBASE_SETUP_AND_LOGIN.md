# 🔥 BKH Business Manager - Firebase Setup & Login Guide

## ✅ APK Build Status
**Location:** `build\app\outputs\flutter-apk\app-release.apk` (54.2MB)
**Status:** ✅ Build Successful with Fixed Login Logic

---

## 🔥 Firebase Firestore Setup (REQUIRED!)

### Step 1: Open Firebase Console
1. যান: https://console.firebase.google.com/
2. আপনার project: **bkh-66405** select করুন

### Step 2: Create Firestore Database
1. Left menu থেকে **"Build"** > **"Firestore Database"** ক্লিক করুন
2. **"Create database"** button ক্লিক করুন
3. **"Start in test mode"** select করুন (Important!)
4. Location: **asia-south1 (Mumbai)** select করুন
5. **"Enable"** ক্লিক করুন

### Step 3: Verify Test Mode Rules
Rules automatically এভাবে সেট হবে:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.time < timestamp.date(2025, 12, 31);
    }
  }
}
```

---

## 🔐 Default Login Credentials

### 👨‍💼 Administrator Login
```
Email: admin@bkh.com
Password: admin123
```
- **কিভাবে login করবেন:**
  1. App open করুন
  2. "Login" button tap করুন (bottom left)
  3. Email: `admin@bkh.com` দিন
  4. Password: `admin123` দিন
  5. Login button ক্লিক করুন

### 👤 Reseller Login
```
First Time: Register করতে হবে!
```
- **Register করার জন্য:**
  1. App open করুন → "Become a Reseller" page আসবে
  2. Full Name দিন
  3. Mobile Number দিন
  4. Email Address দিন
  5. Password তৈরি করুন
  6. Confirm Password দিন
  7. Terms checkbox check করুন
  8. "Register" button ক্লিক করুন

- **Register এর পর Login:**
  1. "Login" button tap করুন (bottom left)
  2. আপনার registered email দিন
  3. আপনার password দিন
  4. Login button ক্লিক করুন

---

## ✅ Fixed Issues

### 1. ✅ Login System Fixed
- **Admin:** Firestore থেকে credentials verify করে
- **Reseller:** Firestore থেকে registered data verify করে
- Error handling added for better user experience

### 2. ✅ Data Persistence (Firebase Firestore)
- Customers → Firestore `customers` collection
- Products → Firestore `products` collection
- Resellers → Firestore `resellers` collection
- Admin Credentials → Firestore `admin` collection
- Logout করলেও data থাকবে!

### 3. ✅ Reseller Dashboard
- শুধু logged-in reseller এর own stats দেখাবে
- অন্যের data দেখবে না

### 4. ✅ Delete Reseller
- Properly Firestore থেকে delete হবে

### 5. ✅ Batch Settlement Logic
- Current batch complete → Previous batch settled → Next batch created
- Automatic background checks every 1 minute

### 6. ✅ Round-Robin Assignment
- Customers, Products, Orders সব resellers এ equally distribute হবে

---

## 📱 Testing Checklist

### First Time Setup:
- [ ] Firebase Console এ Firestore Database create করুন (test mode)
- [ ] APK install করুন
- [ ] App open হচ্ছে কিনা check করুন

### Admin Testing:
- [ ] Login page এ যান (bottom left "Login" button)
- [ ] Email: `admin@bkh.com`, Password: `admin123` দিয়ে login করুন
- [ ] Dashboard দেখতে পাচ্ছেন কিনা
- [ ] Customer add করুন
- [ ] Product add করুন
- [ ] Logout করুন
- [ ] আবার login করে data আছে কিনা check করুন ✅

### Reseller Testing:
- [ ] Register করুন (Full info দিয়ে)
- [ ] Registration successful message দেখতে পাবেন
- [ ] Login page এ automatically যাবে
- [ ] আপনার email/password দিয়ে login করুন
- [ ] Dashboard এ শুধু আপনার stats দেখছেন কিনা
- [ ] Logout করুন
- [ ] আবার login করে data আছে কিনা ✅

### Data Persistence Testing:
- [ ] Customer/Product add করুন
- [ ] App close করুন
- [ ] App আবার open করুন → Data আছে ✅
- [ ] Logout করুন
- [ ] Login করুন → Data আছে ✅

---

## ⚠️ Troubleshooting

### যদি App Open না হয়:
```bash
# Connect phone with USB and run:
flutter run --release
```
Console এ error message দেখাবে।

### যদি Login করতে না পারেন:
1. **Firebase Console check করুন:**
   - Firestore Database create করেছেন কিনা
   - Test mode enabled আছে কিনা

2. **Internet connection check করুন:**
   - Firestore এ data save/load করতে internet লাগবে

3. **Admin Login:**
   - Email: `admin@bkh.com` (exactly এটাই)
   - Password: `admin123` (exactly এটাই)

4. **Reseller Login:**
   - প্রথমে Register করতে হবে
   - তারপর registered email/password দিয়ে login করতে হবে

### যদি Data Save না হয়:
1. Firebase Console এ যান
2. Firestore Database → Data tab check করুন
3. Collections দেখতে পাচ্ছেন কিনা: `customers`, `products`, `resellers`, `admin`

---

## 🎉 Success Criteria

App সফলভাবে কাজ করছে যদি:
1. ✅ App open হয়
2. ✅ Admin login হয়
3. ✅ Reseller register + login হয়
4. ✅ Customer/Product add করলে Firestore এ save হয়
5. ✅ Logout করে login করলেও data থাকে
6. ✅ Reseller dashboard তে শুধু নিজের stats দেখায়
7. ✅ Delete reseller কাজ করে

---

## 📞 Support

যদি কোন সমস্যা হয়:
1. Firebase Console check করুন
2. Internet connection verify করুন
3. Console logs দেখুন: `flutter run --release`
4. Error screenshot নিয়ে support এ যোগাযোগ করুন

---

**Last Updated:** November 3, 2026
**APK Version:** 54.2MB (Release)
**Firebase Project:** bkh-66405
