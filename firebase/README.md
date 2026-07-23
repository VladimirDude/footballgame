# My Team Sharing — Firebase Backend

Lets a **team admin edit team data** and everyone else **join with a redeem code**
to see it. Two backend options are implemented; the app defaults to the simpler
**Storage-only** one.

---

## Option A — Storage-only (default) ✅

**No Firestore, no Cloud Functions, no Blaze plan.** Just Cloud Storage + Anonymous Auth.

### How it works — "capability code"
A team is a folder under an unguessable code:
```
teams/{code}/team.json          the team data (the app's exported-team JSON)
teams/{code}/players/{key}.jpg  player photos
```
- The **redeem code IS the access key** — a long random string like `FTMP-8XK2Q-P4M9` (an unguessable share link). Knowing it grants access.
- **Roles via owner-write:** the first publish stamps the publisher's Anonymous-Auth UID into `team.json`'s `ownerUid` metadata. `storage.rules` only lets that UID edit afterward, so everyone else who has the code is **read-only (viewer)**.

### What you set up
1. Firebase project → enable **Authentication → Anonymous** and **Storage**.
2. Deploy the rules:
   ```bash
   firebase deploy --only storage
   ```
3. In the app: the Firebase SDK products **FirebaseStorage + FirebaseAuth** are
   already added, `FirebaseApp.configure()` runs at launch, and
   `StorageOnlyTeamRemoteStore` is the active remote. Nothing else to wire.

### Client flow (already implemented)
- **Admin**: creates a team (mints a code) → edits → **Publish Changes** writes `team.json` (+ uploads photos) and stamps ownership.
- **Viewer**: enters the code → app reads `team.json` (+ downloads photos). They're read-only because their UID ≠ `ownerUid`.

### The one limitation
"Admin" is the **creator's device/account** (its anonymous UID). One person managing
the roster → perfect. If that account is lost (reinstall without restoring), they
become a viewer of their own team. If you need **multiple admins, code expiry,
usage caps, or true revocation → use Option B.**

### Files
| File | Purpose |
|------|---------|
| `storage.rules` | Read = any code-holder; edit = the owner UID only. |

---

## Option B — Firestore + Cloud Functions (optional, richer)

Use this only if you outgrow Option A. It adds server-validated codes (roles,
expiry, max-uses), multiple admins, and real-time updates — at the cost of the
Blaze plan and a bigger app (Firestore pulls in gRPC).

To switch: add `FirebaseFirestore` + `FirebaseFunctions` back to the SPM package,
set `TeamSyncService.defaultRemote` to `FirestoreTeamRemoteStore()`, and deploy:
```bash
cd firebase/functions && npm install && cd ..
firebase deploy --only functions,firestore:rules,storage
```

### Files
| File | Purpose |
|------|---------|
| `firestore.rules` | Read = members, write = admins; codes/members are function-only. |
| `functions/index.js` | `createTeam`, `createRedeemCode`, `redeemCode` callables. |
| `functions/package.json` | Functions dependencies (Node 20). |

---

## Analytics (both options)

`FirebaseAnalytics` is added and `FirebaseAnalyticsBackend` is registered at
launch, so every `AnalyticsService` event flows to Firebase automatically.
**Remember to update `test/PrivacyInfo.xcprivacy`** to declare the analytics data
you collect before shipping.
