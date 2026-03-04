/**
 * ChildGuard - 親への通知用 Cloud Functions
 *
 * registerParentToken: 親端末の FCM トークンを Firestore に保存（家族ID対応）
 * notifyParent: 子の制限到達時に呼ばれ、指定家族の親に FCM でプッシュ送信
 */

import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onRequest } from "firebase-functions/v2/https";

initializeApp();

const db = getFirestore();
const PARENT_DOC = "config/parent";
const FAMILIES_COLLECTION = "families";

/** 8桁の数字コードを生成（10000000 ～ 99999999） */
function generateFamilyId() {
  return String(10000000 + Math.floor(Math.random() * 90000000));
}

/** 未使用の家族IDを取得（最大5回リトライ） */
async function createUniqueFamilyId() {
  for (let i = 0; i < 5; i++) {
    const id = generateFamilyId();
    const ref = db.collection(FAMILIES_COLLECTION).doc(id);
    const snap = await ref.get();
    if (!snap.exists) return id;
  }
  throw new Error("Could not generate unique family ID");
}

/**
 * POST body: { "token": "fcm_token", "familyId"?: "12345678" }
 * - familyId なし: 新規に 8 桁家族ID を発行し、そのドキュメントにトークンを保存して familyId を返す。
 * - familyId あり: 既存の families/{familyId} のトークンを更新（再登録・トークン更新用）。
 * Response: { ok: true, familyId: string }
 */
export const registerParentToken = onRequest(
  { cors: true },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }
    const token =
      typeof req.body?.token === "string"
        ? req.body.token
        : req.body?.data?.token;
    if (!token) {
      res.status(400).json({ error: "Missing token" });
      return;
    }
    let familyId =
      typeof req.body?.familyId === "string"
        ? req.body.familyId.trim()
        : req.body?.data?.familyId;
    if (familyId && !/^\d{8}$/.test(familyId)) {
      res.status(400).json({ error: "Invalid familyId (must be 8 digits)" });
      return;
    }
    try {
      if (familyId) {
        const ref = db.collection(FAMILIES_COLLECTION).doc(familyId);
        await ref.set({ fcmToken: token }, { merge: true });
      } else {
        familyId = await createUniqueFamilyId();
        const ref = db.collection(FAMILIES_COLLECTION).doc(familyId);
        await ref.set({ fcmToken: token });
      }
      res.status(200).json({ ok: true, familyId });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: String(e.message) });
    }
  }
);

/**
 * POST body: { "familyId": "12345678" } （必須）
 * 指定した家族IDの親トークンに FCM で「制限がかかりました」を送る。
 */
export const notifyParent = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }
  const familyId =
    typeof req.body?.familyId === "string"
      ? req.body.familyId.trim()
      : req.body?.data?.familyId;
  if (!familyId || !/^\d{8}$/.test(familyId)) {
    res.status(400).json({ error: "Missing or invalid familyId (8 digits)" });
    return;
  }
  try {
    const ref = db.collection(FAMILIES_COLLECTION).doc(familyId);
    const snap = await ref.get();
    const token = snap?.data()?.fcmToken;
    if (!token) {
      res.status(404).json({ error: "No parent token for this family" });
      return;
    }
    const messaging = getMessaging();
    await messaging.send({
      token,
      notification: {
        title: "ChildGuard",
        body: "制限がかかりました",
      },
      apns: {
        payload: {
          aps: { sound: "default" },
        },
      },
    });
    res.status(200).json({ ok: true });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: String(e.message) });
  }
});
