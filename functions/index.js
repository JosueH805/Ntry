const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {setGlobalOptions} = require("firebase-functions");
const {defineString} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const crypto = require("node:crypto");

const admin = require("firebase-admin");

admin.initializeApp();

const JWT_SECRET = defineString("JWT_SECRET");

setGlobalOptions({maxInstances: 10});

exports.registerDevice = onCall(
    {enforceAppCheck: false},
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Must be authenticated.");
      }

      const {deviceId} = request.data;
      if (!deviceId || typeof deviceId !== "string") {
        throw new HttpsError("invalid-argument", "deviceId is required.");
      }

      const deviceRef = admin.firestore().collection("devices").doc(deviceId);
      const snap = await deviceRef.get();

      if (!snap.exists) {
        throw new HttpsError("not-found", "Device not registered.");
      }

      const data = snap.data();
      if (data.ownedBy !== request.auth.uid) {
        throw new HttpsError(
            "permission-denied", "Device not owned by caller.");
      }

      if (data.hmacSecret) {
        return {secret: data.hmacSecret};
      }

      const secretB64 = crypto.randomBytes(32).toString("base64");
      await deviceRef.update({
        hmacSecret: secretB64,
        secretProvisionedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {secret: secretB64};
    },
);

exports.validateBleToken = onRequest(
    {invoker: "public"},
    async (req, res) => {
      if (req.method !== "POST") {
        res.status(405).json({error: "Method not allowed"});
        return;
      }
      const {token, lockId} = req.body;
      if (!token || typeof token !== "string") {
        res.status(400).json({error: "token required"});
        return;
      }

      // Strip hyphens and validate Ntry prefix ("4e54" = "NT")
      const hex = token.toLowerCase().replace(/-/g, "");
      if (!hex.startsWith("4e54") || hex.length !== 32) {
        res.json({valid: false, ownedBy: null, displayName: null});
        return;
      }

      // Bytes 2-15 of the UUID are the 14-byte HMAC payload
      const tokenHex = hex.substring(4);

      // Filter by lockId when provided — avoids scanning all devices
      let query = admin.firestore().collection("devices");
      if (lockId && typeof lockId === "string") {
        query = query.where("lockId", "==", lockId);
      }
      const snap = await query.get();
      if (snap.empty) {
        res.json({valid: false, ownedBy: null, displayName: null});
        return;
      }

      const nowWindow = Math.floor(Date.now() / 30000);

      for (const doc of snap.docs) {
        const data = doc.data();
        if (data.isRevoked === true || !data.hmacSecret) continue;

        const key = Buffer.from(data.hmacSecret, "base64");
        const matched = [nowWindow, nowWindow - 1].some((w) => {
          const expected = crypto
              .createHmac("sha256", key)
              .update(String(w))
              .digest()
              .subarray(0, 14)
              .toString("hex");
          if (expected.length !== tokenHex.length) return false;
          return crypto.timingSafeEqual(
              Buffer.from(expected, "hex"),
              Buffer.from(tokenHex, "hex"),
          );
        });

        if (!matched) continue;

        const uid = data.ownedBy || null;
        let displayName = uid;
        if (uid) {
          const userSnap = await admin.firestore()
              .collection("users").doc(uid).get();
          if (userSnap.exists) {
            const u = userSnap.data();
            const name = ((u.first_name || "") + " " +
                (u.last_name || "")).trim();
            if (name) displayName = name;
          }
        }
        res.json({valid: true, ownedBy: uid, displayName});
        return;
      }

      res.json({valid: false, ownedBy: null, displayName: null});
    },
);

exports.signGuestPass = onDocumentCreated(
    "passkeys/{passId}",
    async (event) => {
      try {
        const data = event.data.data();

        if (!data.expTime) {
          throw new Error("Missing expTime");
        }

        const expMillis = data.expTime.toMillis();

        // Compact token: {passId}|{exp}|{name}|{hmac16}
        // Much shorter than a JWT (~55 chars vs ~200), producing a version-3 QR
        // code that the M5Stack camera can reliably decode at QVGA resolution.
        const expSeconds = Math.floor(expMillis / 1000);
        const nameStr = data.name || "";
        const signingInput =
          `${event.params.passId}|${expSeconds}|${data.lockId}|${nameStr}`;
        const sig = crypto
            .createHmac("sha256", JWT_SECRET.value())
            .update(signingInput)
            .digest("base64url")
            .substring(0, 16);
        const token = `${event.params.passId}|${expSeconds}|${nameStr}|${sig}`;

        await event.data.ref.update({token});

        return null;
      } catch (error) {
        logger.error("FULL ERROR:", error);
        throw error;
      }
    },
);
