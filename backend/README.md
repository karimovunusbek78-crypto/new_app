# Backend guide — new_app (Gravitas Auto)

This is for the backend programmers. It explains how the app talks to its backend today, what is
missing or unsafe, and what to build, in priority order. Everything here was taken from the Flutter
code in `lib/` (file references are given so you can check).

Files in this folder:

| File | What it is |
|---|---|
| `README.md` | this guide |
| `firestore.rules` | Firestore security rules matching the current app (phase 1, section 6) |
| `storage.rules` | Firebase Storage rules |
| `firestore.indexes.json` | composite indexes the app's queries need |

---

## 1. What the app is

A car marketplace (Uzbekistan, UI in Russian). Users:

- browse cars in a list and in a TikTok-style **video feed**;
- like, save, add to favourites, comment and reply, follow sellers;
- get **in-app notifications** (likes, comments, replies, new followers);
- **sell a car** (private seller) or open an **autosalon** (dealer page with locations and many cars).
  Both need a **one-time permission from an admin** first (section 3.9).

## 2. Stack and access

There is **no custom server**. The app talks straight to Firebase:

| Service | Used for |
|---|---|
| Firebase Auth | email + password sign-up / sign-in (`lib/src/authentifications/`) |
| Cloud Firestore | all data (section 3) |
| Firebase Storage | photos, videos, avatars, logos (section 4) |

- Firebase project id: **`gravitas-auto`** (`firebase.json`, `lib/firebase_options.dart`).
- Platforms configured: Android, iOS, macOS, web, Windows.
- Other outside services the app calls directly:
  - `photon.komoot.io` and `nominatim.openstreetmap.org` for address search and reverse geocoding
    (`lib/src/pages/autoslon/location/location_add_page.dart`);
  - `wa.me`, `t.me/automarket_support` and `tel:` links for contacting support and sellers.
- **Not used yet:** Cloud Functions, push notifications (FCM), Remote Config, App Check, Analytics.

Setup for a backend developer:

```bash
npm install -g firebase-tools        # needs Node 18+; the emulator needs Java 21+
firebase login                        # an account with access to gravitas-auto
cd new_app
firebase use gravitas-auto
```

Ask the project owner to add you in **Firebase console → Project settings → Users and permissions**.

## 3. Firestore data model

Rule of thumb: **the app reads these field names exactly. Don't rename or retype a field without
changing the app at the same time.** Several numbers are stored as **strings** (price, year, km);
see section 5.

### 3.1 `users/{uid}` — profile

| Field | Type | Written by |
|---|---|---|
| `name`, `email`, `phone`, `telegram` | string | profile page (`pages/profile/profile_page.dart` → `ProfileHistoryService.saveProfile`) |
| `avatarUrl` | string (Storage URL) | profile page, `video/video page/profile/user_stats_page.dart` |
| `subscribersCount` | int | follow / unfollow by **other users** (`pages/home/providers/subscribtion_provider.dart`) |
| `createdAt`, `updatedAt` | timestamp | sign-up / profile save |
| `canPublish` | bool | **legacy**, read by `CarSellPermissionNotifier`; admin-only. Replaced by `publish_permissions` |

Since this update, sign-up creates this document (`name`, `email`, `subscribersCount: 0`, `createdAt`).
Older accounts may still have no document. The app now creates it on first follow, but a one-off
backfill script is a good idea.

Sub-collections:

| Path | Fields | Notes |
|---|---|---|
| `users/{uid}/favorites/{carId}` | `addedAt` | private list |
| `users/{uid}/savedCars/{carId}` | `savedAt` | private list (mirrors `cars/{id}/savedBy`) |
| `users/{uid}/history/{autoId}` | `changes: {field: {from, to}}`, `changedBy`, `changedAt` | append-only log of profile edits |
| `users/{uid}/notifications/{autoId}` | `type` (`like`/`comment`/`reply`/`subscribe`), `fromUid`, `fromName`, `fromAvatarUrl`, `carId`, `carName`, `commentId`, `text`, `createdAt`, `read` | written by **other users' apps** (`pages/home/notification/notification_sender.dart`); owner sets `read: true` |

### 3.2 `cars/{carId}` — listings

Model: `lib/src/pages/home/models/car.dart`.

| Field | Type | Notes |
|---|---|---|
| `name`, `year`, `km`, `price`, `transmission`, `fuelType`, `engineCapacity`, `bodyType`, `color`, `location`, `ownersCount`, `description`, `driveType`, `condition`, `changesDescription`, `phone` | **string** | free text from the form, even the numbers |
| `priceNegotiable`, `contactWhatsapp`, `contactTelegram` | bool | |
| `photoPaths` | string[] | Storage download URLs |
| `videoPath` | string or null | Storage download URL |
| `ownerId` | string | uid of the seller |
| `likesCount`, `viewsCount`, `savesCount` | int | changed by **any** user's app with `FieldValue.increment(±1)` |
| `autosalonId`, `autosalonName`, `autosalonLogoUrl` | string or null | set for dealer cars |
| `isAutosalonCar` | bool | |
| `createdAt` | timestamp | |

Doc id: a private seller's car uses **`DateTime.now().millisecondsSinceEpoch`** as its id
(`pages/car_sell/car_publish/car_publish_page.dart`); dealer cars use an auto id.

Sub-collections:

| Path | Fields | Notes |
|---|---|---|
| `cars/{id}/likedBy/{uid}` | `uid`, `likedAt` | queried with `collectionGroup('likedBy').where('uid', ==, me)` (`cars_provider.dart`) |
| `cars/{id}/savedBy/{uid}` | `savedAt` | |
| `cars/{id}/viewLog/{autoId}` | `viewerUid`, `viewedAt` | one doc per view; "views today" query on `viewedAt` |
| `cars/{id}/deleteLog/{autoId}` | `reason`, `deletedBy`, `deletedAt` | written just before the car is deleted |
| `cars/{id}/comments/{autoId}` | `text`, `uid`, `authorName`, `authorAvatarUrl`, `createdAt`, `pinned`, `editedAt` | car owner can pin; author edits; author or car owner deletes |
| `cars/{id}/comments/{cid}/replies/{autoId}` | same as comment + `carId` (no `pinned`) | |

Code: `pages/home/providers/cars_provider.dart`, `pages/saved/provider/saved_cars_provider.dart`,
`video/video page/comments/comments_sheet.dart`.

### 3.3 `subscriptions/{followerUid}_{targetUid}`

`followerUid`, `targetUid`, `createdAt`. Created and deleted by the follower; the follower's app also
bumps `users/{targetUid}.subscribersCount`.

### 3.4 `autosalons/{ownerUid}` — dealer page

`ownerId`, `name`, `tagline`, `yearsOnMarket`, `logoUrl`, `description`, `phone`, `photoUrls[]`,
`videoUrl`, `carsCount`, `locationsCount`, `createdAt`, `updatedAt`.

Sub-collection `autosalons/{uid}/locations/{id}`: `city`, `address`, `lat`, `lng`, `photoUrls[]`,
`createdAt`.

Written by `pages/autoslon/autoslon_publish/autoslon_publish_page.dart` (first publish) and
`video/video page/profile/autosalon_stats_page.dart` (dealer dashboard: edit profile, add/remove
locations, add cars). The list on Home sorts by `updatedAt`.

### 3.5 `publish_permissions/{uid}` — admin approval

```
autoslonRequested : bool    // user tapped "contact us" for an autosalon
autoslonGranted   : bool    // ADMIN sets true to approve one autosalon publish
carsellRequested  : bool    // same for selling one car
carsellGranted    : bool    // ADMIN sets true to approve one car listing
updatedAt         : timestamp
```

Flow (`pages/autoslon/permission/publish_permission.dart`):

1. User opens "Sell a car" or "Autosalon" → the app shows contact buttons (WhatsApp, Telegram, phone).
2. Tapping one writes `…Requested: true` and the user talks to support.
3. **Today an admin approves by hand in the Firebase console**: open `publish_permissions/{uid}`
   and set `carsellGranted` or `autoslonGranted` to `true`. The app listens live and opens the form.
4. After publishing, the app itself sets `…Granted: false, …Requested: false` (one-time use).

## 4. Storage layout

| Path | Content | Written by |
|---|---|---|
| `avatars/{uid}.{ext}` | user avatar | profile page, user stats page (the old file is deleted by URL) |
| `cars/{ownerUid}/{carId}/photo_{n}.jpg` | car photos | car publish, autosalon publish, dealer dashboard |
| `cars/{ownerUid}/{carId}/video.mp4` | car video (up to ~6 min upload timeout on client) | same |
| `autosalons/{uid}/logo_{ms}.jpg` | dealer logo | autosalon publish / dashboard |
| `autosalons/{uid}/gallery/photo_{ms}_{n}.jpg`, `video_{ms}.mp4` | dealer gallery | autosalon publish |
| `autosalons/{uid}/locations/{i or docId}/photo_….jpg` | location photos | autosalon publish / dashboard |

The app stores the **download URL** (with token) in Firestore, not the path.

## 5. Problems found, by priority

### P0 — security (do first)

1. **No security rules in the repo.** We can't see which rules are live. If the project is in
   "test mode", the database is either open to anyone or will start rejecting everything when the
   test period ends. Check **Firestore → Rules** and **Storage → Rules** in the console today.
2. **Users can approve themselves.** `publish_permissions/{uid}` is written by the app, so a modified
   client can set `carsellGranted: true` and skip the admin. The new rules block this.
3. **Counters and other people's data are written by clients.** Any user can change any car's
   `likesCount`/`viewsCount`/`savesCount`, any user's `subscribersCount`, and create notifications for
   anyone. Phase 1 rules limit this to ±1 steps; phase 2 moves it to Cloud Functions.
4. **No admin role.** Admins should be marked with a custom claim, then use an admin page or a function
   instead of the raw console:

   ```js
   // one-off Node script with a service-account key (never commit the key)
   const admin = require('firebase-admin');
   admin.initializeApp();
   await admin.auth().setCustomUserClaims('<ADMIN_UID>', { admin: true });
   ```

### P1 — correctness

5. **Permission is used up by the client.** If the app crashes after publishing, the permission stays
   and can be reused. Use a Cloud Function on `cars/{id}` create that sets `carsellGranted: false`
   (and on `autosalons/{uid}` create → `autoslonGranted: false`).
6. **Deleting a car leaves junk behind:** Storage files `cars/{owner}/{carId}/…`, its `likedBy`,
   `savedBy`, `comments` (+ `replies`) and `viewLog`, and entries in other users' `favorites` and
   `savedCars`. Add an `onDocumentDeleted('cars/{carId}')` function that cleans these up (keep
   `deleteLog` if you want an audit trail; then move it to a top-level `deleted_cars` collection,
   because sub-collections of a deleted document are hard to find).
7. **No push notifications.** Notifications only show while the app is open. Add `firebase_messaging`
   to the app and store device tokens in `users/{uid}/fcmTokens/{token}`. Then have a function on
   `users/{uid}/notifications/{id}` create send the push.
8. **Autosalon `createdAt` is overwritten** on every publish (`set(..., merge: true)` with
   `createdAt: serverTimestamp()` in `autoslon_publish_page.dart`). Only set it on create.
9. **Autosalon publish deletes and recreates all locations** each time, so their ids change.

### P2 — scale and data quality

10. **The whole `cars` collection is loaded at once** (`CarsProvider`, ordered by `createdAt`), and
    search and filters run on the phone (`pages/search/search_page.dart`). This works for hundreds of
    cars, not thousands. Plan pagination (`limit` + `startAfter`) and server-side filtering.
11. **Price, year and mileage are strings.** You can't sort or filter them in Firestore. Add numeric
    copies (`priceNum`, `yearNum`, `kmNum`), filled by a function on write, then add indexes, or use
    a search service (Algolia / Typesense) for full search.
12. **`viewLog` grows forever** (one document per view). Set a TTL policy on `viewedAt` (e.g. 90 days)
    or aggregate into daily counters.
13. **Car ids from a millisecond timestamp** can clash when two people publish at the same moment.
    Prefer `collection('cars').doc().id`.
14. **Geocoding goes straight to Nominatim and Photon.** Nominatim's usage policy requires a real
    `User-Agent` and at most 1 request/second per app; heavy use will get blocked. Put a small
    caching proxy (Cloud Function) in front, or use a paid geocoder.
15. **Support contacts are hard-coded** in the app (WhatsApp number, `t.me/automarket_support`,
    phone in `autoslon_page.dart` and `car_sell_page.dart`). Move them to Remote Config or a
    `config/support` document so they can change without an app release.
16. **Legacy `users.canPublish`** is still read by `CarSellPermissionNotifier`. Remove it once
    `publish_permissions` is the only source of truth.
17. **Turn on App Check** (Play Integrity / DeviceCheck) so only the real app can call Firebase.

## 6. Security rules — how to roll out

Phase 1 (the files in this folder) keeps the current app working and closes the worst holes:

- signed-in users can read listings, profiles, comments and dealer pages;
- users write only their own profile, lists, likes, comments, cars, dealer page;
- counters can only move by ±1 (views by +1), and owners can't reset their own counters;
- `…Granted` can only be set to `true` by an admin;
- a car can only be created with an active permission, or by an existing autosalon;
- Storage: write only inside your own folder; photos < 15 MB, videos < 300 MB, avatars < 10 MB.

**Test before deploying. A wrong rule breaks the app for everyone.** These rules haven't been run in
the emulator yet. On this machine the emulator needs Java 21 (`brew install openjdk@21`).

1. Point the project config at these files (add to `firebase.json`, next to the existing `flutter` key):

   ```json
   "firestore": { "rules": "backend/firestore.rules", "indexes": "backend/firestore.indexes.json" },
   "storage": { "rules": "backend/storage.rules" }
   ```

2. Run the emulators and the app against them, and click through every feature in section 8:

   ```bash
   firebase emulators:start --only auth,firestore,storage
   ```

   In the app, temporarily call `FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080)`,
   `FirebaseStorage.instance.useStorageEmulator('localhost', 9199)` and
   `FirebaseAuth.instance.useAuthEmulator('localhost', 9099)` in `main.dart` (debug builds only).

3. Also check in the console's **Rules Playground** that a normal user **cannot** set
   `carsellGranted: true`, edit another user's car, or read another user's notifications.

4. Deploy:

   ```bash
   firebase deploy --only firestore:rules,firestore:indexes,storage
   ```

5. Keep the previous rules (console → Rules → history) so you can roll back in one click.

Phase 2: after the Cloud Functions in section 7 exist, remove the client-side counter and
notification branches from the rules (`bumped(...)` updates and the notifications `create`).

## 7. Cloud Functions to build (phase 2)

Create them with `firebase init functions` (TypeScript, Node 20, region close to users, e.g.
`europe-west1`). Suggested set:

| Trigger | Does |
|---|---|
| `cars/{carId}/likedBy/{uid}` created / deleted | `likesCount ±1`; on create, notify the owner (`type: like`) |
| `cars/{carId}/savedBy/{uid}` created / deleted | `savesCount ±1` |
| `cars/{carId}/viewLog/{id}` created | `viewsCount +1` (skip if viewer is the owner) |
| `subscriptions/{id}` created / deleted | `users/{target}.subscribersCount ±1`; notify (`subscribe`) |
| `cars/{carId}/comments/{id}` created | notify the car owner (`comment`) |
| `…/comments/{cid}/replies/{id}` created | notify the parent comment's author (`reply`) |
| `cars/{carId}` created | consume `publish_permissions.carsellGranted`; fill `priceNum`/`yearNum`/`kmNum` |
| `cars/{carId}` deleted | clean up Storage + sub-collections + favorites/savedCars (P1-6) |
| `users/{uid}/notifications/{id}` created | send FCM push to the user's tokens |
| callable `grantPublish({uid, type})` | admin-only: set `…Granted: true` (replaces console editing) |

Example of the pattern:

```ts
import { onDocumentCreated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

initializeApp();
const db = getFirestore();

export const onLike = onDocumentCreated('cars/{carId}/likedBy/{uid}', async (e) => {
  const { carId, uid } = e.params;
  const carRef = db.doc(`cars/${carId}`);
  const car = (await carRef.get()).data();
  if (!car) return;
  await carRef.update({ likesCount: FieldValue.increment(1) });
  if (car.ownerId && car.ownerId !== uid) {
    const from = (await db.doc(`users/${uid}`).get()).data() ?? {};
    await db.collection(`users/${car.ownerId}/notifications`).add({
      type: 'like', fromUid: uid, fromName: from.name ?? 'Пользователь',
      fromAvatarUrl: from.avatarUrl ?? null, carId, carName: car.name ?? null,
      commentId: null, text: null, read: false, createdAt: FieldValue.serverTimestamp(),
    });
  }
});

export const onUnlike = onDocumentDeleted('cars/{carId}/likedBy/{uid}', async (e) => {
  await db.doc(`cars/${e.params.carId}`)
    .update({ likesCount: FieldValue.increment(-1) })
    .catch(() => {}); // the car itself may have been deleted
});
```

When a function takes over a job, **the app must stop doing it at the same release.** Otherwise
counters double and notifications arrive twice. Agree each change with the Flutter developers (the
client code to remove is listed in section 3 next to each field).

## 8. Checklist after any backend change

Sign in as two test users (A and B) and check:

- [ ] Sign up creates `users/{uid}`; sign in / sign out work
- [ ] Home list, video feed, car detail open; photos and videos load
- [ ] A likes B's car → count changes, B gets a notification; unlike works
- [ ] Save / favourite / remove work and survive an app restart
- [ ] Comment, reply, edit own comment, B (car owner) pins and deletes A's comment
- [ ] A follows B → B's subscriber count and notification; unfollow
- [ ] Profile edit + avatar upload; history entry appears
- [ ] Sell a car: request → admin grants → form opens → publish → permission is used up
- [ ] Autosalon: request → grant → publish with locations and cars → dashboard edits work
- [ ] Owner deletes a car → it disappears for everyone; files are cleaned up (after P1-6)
- [ ] User A **cannot** grant themselves, edit B's car or profile, or read B's notifications

## 9. Contacts

Flutter app repo: `github.com/karimovunusbek78-crypto/new_app` (branch `dev`). Ask the Flutter team
before changing any field name, type or path listed above.
