const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

exports.sendPushOnNotificationCreate = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    if (!notification) {
      return null;
    }

    const userId = notification.userId;
    if (!userId) {
      return null;
    }

    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return null;
    }

    const userData = userDoc.data();
    const tokens = userData?.fcmTokens;
    if (!Array.isArray(tokens) || tokens.length === 0) {
      return null;
    }

    const title = notification.title || 'New Notification';
    const body = notification.body || '';
    const payloadType = notification.type || '';

    const message = {
      notification: {
        title,
        body,
      },
      data: {
        type: payloadType,
        notificationId: context.params.notificationId || '',
      },
      tokens,
    };

    const response = await admin.messaging().sendMulticast(message);

    const invalidTokens = [];
    response.responses.forEach((resp, index) => {
      if (!resp.success) {
        const errorCode = resp.error?.code;
        if (
          errorCode === 'messaging/invalid-registration-token' ||
          errorCode === 'messaging/registration-token-not-registered'
        ) {
          invalidTokens.push(tokens[index]);
        }
      }
    });

    if (invalidTokens.length > 0) {
      const validTokens = tokens.filter((token) => !invalidTokens.includes(token));
      await userDoc.ref.update({ fcmTokens: validTokens });
    }

    return null;
  });
