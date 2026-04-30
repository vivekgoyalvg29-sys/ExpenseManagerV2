/**
 * verifyPlaySubscription — validates Android subscription via Google Play Developer API,
 * then writes entitlement fields on users/{uid} (krchabookdb) with Admin SDK.
 *
 * Secret PLAY_SERVICE_ACCOUNT_JSON: full JSON of a Play Console–linked service account.
 * Deploy: firebase functions:secrets:set PLAY_SERVICE_ACCOUNT_JSON
 */
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {setGlobalOptions} = require('firebase-functions/v2');
const {initializeApp, getApps, getApp} = require('firebase-admin/app');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');
const {defineSecret} = require('firebase-functions/params');
const {google} = require('googleapis');

setGlobalOptions({region: 'us-central1'});

const playServiceAccountJson = defineSecret('PLAY_SERVICE_ACCOUNT_JSON');

/** Keep in sync with lib/config/app_config.dart */
const DEFAULT_PACKAGE_NAME = 'vivek.fintrack.app';
const DEFAULT_PRO_PRODUCT_ID = 'kharcha_pro_yearly';

if (!getApps().length) {
  initializeApp();
}
const db = getFirestore(getApp(), 'krchabookdb');

/**
 * @param {import('firebase-functions/v2/https').CallableRequest} request
 */
async function handleVerifyPlaySubscription(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'Sign in required.');
  }

  const raw = request.data;
  const purchaseToken =
    typeof raw === 'object' && raw !== null && typeof raw.purchaseToken === 'string'
      ? raw.purchaseToken.trim()
      : '';
  const productId =
    typeof raw === 'object' && raw !== null && typeof raw.productId === 'string'
      ? raw.productId.trim()
      : DEFAULT_PRO_PRODUCT_ID;
  const packageName =
    typeof raw === 'object' &&
    raw !== null &&
    typeof raw.packageName === 'string' &&
    raw.packageName.trim().length > 0
      ? raw.packageName.trim()
      : DEFAULT_PACKAGE_NAME;

  if (!purchaseToken) {
    throw new HttpsError('invalid-argument', 'purchaseToken is required.');
  }

  let credentials;
  try {
    credentials = JSON.parse(playServiceAccountJson.value());
  } catch (e) {
    throw new HttpsError(
      'failed-precondition',
      'PLAY_SERVICE_ACCOUNT_JSON secret is missing or invalid JSON.',
    );
  }

  const auth = new google.auth.GoogleAuth({
    credentials: {
      client_email: credentials.client_email,
      private_key: credentials.private_key,
    },
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  const authClient = await auth.getClient();
  const androidPublisher = google.androidpublisher({version: 'v3', auth: authClient});

  let subV2;
  try {
    const res = await androidPublisher.purchases.subscriptionsv2.get({
      packageName,
      token: purchaseToken,
    });
    subV2 = res.data;
  } catch (err) {
    const msg = err?.message || String(err);
    console.error('subscriptionsv2.get failed', msg);
    throw new HttpsError(
      'internal',
      'Play API verification failed. Check service account + Play Console API access.',
    );
  }

  const state = subV2.subscriptionState || '';
  const lineItems = Array.isArray(subV2.lineItems) ? subV2.lineItems : [];

  /** @type {string[]} */
  const expiries = [];
  const matchesProduct = (pid) => {
    if (!pid || typeof pid !== 'string') return false;
    if (pid === productId) return true;
    // Play may return "subId:basePlanId" or other composite ids.
    return pid.startsWith(`${productId}:`) || pid.includes(productId);
  };

  for (const li of lineItems) {
    if (!li || typeof li !== 'object') continue;
    const pid = li.productId;
    if (pid && !matchesProduct(String(pid))) continue;
    const et = li.expiryTime || li.expiry_time;
    if (typeof et === 'string') expiries.push(et);
  }
  if (expiries.length === 0) {
    for (const li of lineItems) {
      if (li && typeof li === 'object') {
        const et = li.expiryTime || li.expiry_time;
        if (typeof et === 'string') expiries.push(et);
      }
    }
  }

  let latestExpiryMs = 0;
  for (const iso of expiries) {
    const t = Date.parse(iso);
    if (!Number.isNaN(t) && t > latestExpiryMs) {
      latestExpiryMs = t;
    }
  }

  const now = Date.now();
  const noAccessStates = new Set([
    'SUBSCRIPTION_STATE_EXPIRED',
    'SUBSCRIPTION_STATE_REVOKED',
  ]);
  const activeLikeStates = new Set([
    'SUBSCRIPTION_STATE_ACTIVE',
    'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
  ]);

  let hasFutureAccess =
    !noAccessStates.has(state) && latestExpiryMs > now;

  // Play sometimes omits lineItems.expiryTime in responses we still need to honor.
  if (
    !hasFutureAccess &&
    activeLikeStates.has(state) &&
    !noAccessStates.has(state)
  ) {
    const fallbackMs = now + 366 * 24 * 60 * 60 * 1000;
    latestExpiryMs = fallbackMs;
    hasFutureAccess = true;
    console.warn(
      'verifyPlaySubscription: using fallback expiry for state',
      state,
    );
  }

  const uid = request.auth.uid;
  const userRef = db.collection('users').doc(uid);

  if (hasFutureAccess) {
    await userRef.set(
      {
        accountStatus: 'pro',
        proExpiresAt: Timestamp.fromMillis(latestExpiryMs),
        lastPurchaseProductId: productId,
        playSubscriptionState: state,
        entitlementUpdatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
    );
    return {
      accountStatus: 'pro',
      proExpiresAtMillis: latestExpiryMs,
      playSubscriptionState: state,
    };
  }

  await userRef.set(
    {
      accountStatus: 'free',
      proExpiresAt: FieldValue.delete(),
      playSubscriptionState: state,
      entitlementUpdatedAt: FieldValue.serverTimestamp(),
    },
    {merge: true},
  );
  return {
    accountStatus: 'free',
    playSubscriptionState: state,
  };
}

exports.verifyPlaySubscription = onCall(
  {
    secrets: [playServiceAccountJson],
    enforceAppCheck: false,
  },
  async (request) => {
    try {
      return await handleVerifyPlaySubscription(request);
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      console.error(e);
      throw new HttpsError('internal', 'Verification failed.');
    }
  },
);
