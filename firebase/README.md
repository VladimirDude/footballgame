# My Team Sharing — Firebase Backend

Lets a team **admin edit team data** and everyone else **join with a redeem code**
to see (and, if granted, edit) that same team. This is what needs to be set up on
the Firebase side.

## Product choice (important)

Your request said "Firebase Storage," but editable, access-controlled team data is
a **database** job, not blob storage. So:

| Data | Firebase product | Why |
|------|------------------|-----|
| Team data (players, games, scores) | **Cloud Firestore** | Structured, editable, real-time, rule-enforced per team. |
| Player photos | **Cloud Storage** | Binary files; gated by auth custom claims. |
| Team membership + redeem codes | **Cloud Firestore + Cloud Functions** | Codes must be validated server-side. |
| Who a user is | **Firebase Auth (Anonymous)** | Zero-friction identity so rules can gate access. |

## Data model (Firestore)

```
teams/{teamId}
  name: string
  ownerUid: string
  data: { players: [...], games: [...] }     ← the app's exported-team JSON
  updatedAt: timestamp
  updatedBy: uid

teams/{teamId}/members/{uid}
  uid: string
  role: "owner" | "admin" | "viewer"
  joinedAt: timestamp

redeemCodes/{CODE}                            ← e.g. redeemCodes/FTMP-8XK2Q-P4M9
  teamId: string
  role: "viewer" | "admin"
  active: bool
  maxUses: number        (0 = unlimited)
  uses: number
  expiresAt: timestamp?   (null = never)
```

## How the two flows work

**Admin edits → everyone updates.** The admin's app writes `teams/{teamId}.data`
directly (allowed by `firestore.rules` only for owner/admin members). Viewers'
apps read that document (and can subscribe for real-time updates).

**Redeem code → access.** The user's app calls the `redeemCode` Cloud Function with
the code. The function (running with admin rights) validates the code, creates the
caller's `members/{uid}` doc with the code's role, bumps `uses`, and sets Auth
**custom claims** (`teams`, `adminTeams`) so Storage photo access works too. The
app then pulls the team snapshot.

## What you need to implement / deploy

Everything is in this folder. Steps:

1. **Create a Firebase project** and enable: **Authentication → Anonymous**,
   **Firestore**, **Storage**, **Functions** (Functions requires the Blaze plan).
2. **Install the CLI** and log in: `npm i -g firebase-tools && firebase login`.
3. From `firebase/`, run `firebase init` (or reuse the files here) and set the
   project: `firebase use --add`.
4. **Deploy:**
   ```bash
   cd firebase/functions && npm install && cd ..
   firebase deploy --only functions,firestore:rules,storage
   ```
5. **In the iOS app** (Phase 2): add the Firebase SDK via SPM
   (`FirebaseAuth`, `FirebaseFirestore`, `FirebaseFunctions`, `FirebaseStorage`),
   drop in `GoogleService-Info.plist`, call `FirebaseApp.configure()` at launch,
   then swap `LocalTeamRemoteStore` for `FirestoreTeamRemoteStore`
   (already written, guarded behind `#if canImport(FirebaseFirestore)`).

## Creating the first team & codes

- The first admin's app calls `createTeam` (or create the `teams/{id}` doc +
  owner `members/{uid}` doc by hand in the console).
- Admins mint codes with the `createRedeemCode` callable
  (`{ teamId, role: "viewer", maxUses: 50, expiresInDays: 30 }`) — or create a
  `redeemCodes/{CODE}` doc manually in the console for a quick start.
- Hand the code (e.g. `FTMP-8XK2Q-P4M9`) to users; they enter it in the app.

## Files

| File | Purpose |
|------|---------|
| `firestore.rules` | Read = members, write = admins; codes/members are function-only. |
| `storage.rules` | Photo read/write gated by `teams`/`adminTeams` custom claims. |
| `functions/index.js` | `createTeam`, `createRedeemCode`, `redeemCode` callables. |
| `functions/package.json` | Functions dependencies (Node 20). |

## Cost

Firestore + Auth stay in the free tier for small teams. **Functions requires the
Blaze (pay-as-you-go) plan**, but redeem/create calls are rare, so real cost is
effectively zero. If you want to avoid Blaze entirely, codes can be created in the
console and redemption done via a Firestore transaction from a trusted admin
device — but the Cloud Function is the correct, secure approach.
