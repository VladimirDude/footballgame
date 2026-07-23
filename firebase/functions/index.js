/**
 * FTMP — My Team sharing backend (Cloud Functions v2).
 *
 * Three callable functions the app invokes over HTTPS with the user's Firebase
 * Auth token. They run with Admin privileges (bypassing security rules), which
 * is why membership + redeem-code logic MUST live here rather than on the client.
 *
 *   createTeam({ name })                         → { teamId }
 *   createRedeemCode({ teamId, role, maxUses,    → { code }
 *                      expiresInDays })
 *   redeemCode({ code })                         → { teamId, role }
 *
 * Deploy:  firebase deploy --only functions,firestore:rules,storage
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");

initializeApp();
const db = getFirestore();

function requireAuth(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in first.");
  }
  return request.auth.uid;
}

/** Recomputes a user's `teams` / `adminTeams` custom claims from their memberships
 *  and writes them so Storage rules can gate photo access. */
async function syncMembershipClaims(uid) {
  const memberships = await db
    .collectionGroup("members")
    .where("uid", "==", uid)
    .get();

  const teams = [];
  const adminTeams = [];
  memberships.forEach((doc) => {
    const teamId = doc.ref.parent.parent.id;
    teams.push(teamId);
    if (["owner", "admin"].includes(doc.data().role)) adminTeams.push(teamId);
  });
  await getAuth().setCustomUserClaims(uid, { teams, adminTeams });
}

/** Creates a team and makes the caller its owner (atomically). */
exports.createTeam = onCall(async (request) => {
  const uid = requireAuth(request);
  const name = (request.data?.name || "My Team").toString().slice(0, 60);

  const teamRef = db.collection("teams").doc();
  await db.runTransaction(async (tx) => {
    tx.set(teamRef, {
      name,
      ownerUid: uid,
      data: { players: [], games: [] },
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: uid,
    });
    tx.set(teamRef.collection("members").doc(uid), {
      uid,
      role: "owner",
      joinedAt: FieldValue.serverTimestamp(),
    });
  });

  await syncMembershipClaims(uid);
  return { teamId: teamRef.id };
});

/** Admin-only: mints a redeem code for a team. */
exports.createRedeemCode = onCall(async (request) => {
  const uid = requireAuth(request);
  const { teamId, role = "viewer", maxUses = 0, expiresInDays = 0 } = request.data || {};

  if (!teamId) throw new HttpsError("invalid-argument", "teamId is required.");
  if (!["viewer", "admin"].includes(role)) {
    throw new HttpsError("invalid-argument", "role must be viewer or admin.");
  }

  const member = await db.doc(`teams/${teamId}/members/${uid}`).get();
  if (!member.exists || !["owner", "admin"].includes(member.data().role)) {
    throw new HttpsError("permission-denied", "Only team admins can create codes.");
  }

  // Human-friendly code, e.g. "FTMP-8XK2Q-P4M9".
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const block = (n) =>
    Array.from({ length: n }, () => alphabet[Math.floor(Math.random() * alphabet.length)]).join("");
  const code = `FTMP-${block(5)}-${block(4)}`;

  const expiresAt =
    expiresInDays > 0
      ? new Date(Date.now() + expiresInDays * 86400000)
      : null;

  await db.collection("redeemCodes").doc(code).set({
    teamId,
    role,
    active: true,
    maxUses: Number(maxUses) || 0, // 0 = unlimited
    uses: 0,
    expiresAt,
    createdBy: uid,
    createdAt: FieldValue.serverTimestamp(),
  });

  return { code };
});

/** Redeems a code: grants the caller membership of the code's team. */
exports.redeemCode = onCall(async (request) => {
  const uid = requireAuth(request);
  const code = (request.data?.code || "").toString().trim().toUpperCase();
  if (!code) throw new HttpsError("invalid-argument", "code is required.");

  const codeRef = db.collection("redeemCodes").doc(code);
  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(codeRef);
    if (!snap.exists) throw new HttpsError("not-found", "That code doesn't exist.");
    const c = snap.data();

    if (!c.active) throw new HttpsError("failed-precondition", "This code is no longer active.");
    if (c.expiresAt && c.expiresAt.toDate() < new Date()) {
      throw new HttpsError("failed-precondition", "This code has expired.");
    }
    if (c.maxUses > 0 && c.uses >= c.maxUses) {
      throw new HttpsError("resource-exhausted", "This code has been fully used.");
    }

    const memberRef = db.doc(`teams/${c.teamId}/members/${uid}`);
    tx.set(memberRef, {
      uid,
      role: c.role,
      joinedAt: FieldValue.serverTimestamp(),
      viaCode: code,
    }, { merge: true });
    tx.update(codeRef, { uses: FieldValue.increment(1) });

    return { teamId: c.teamId, role: c.role };
  });

  await syncMembershipClaims(uid);
  return result;
});
