const functions = require('firebase-functions');
const admin = require('firebase-admin');
const textToSpeech = require('@google-cloud/text-to-speech');

admin.initializeApp();
const ttsClient = new textToSpeech.TextToSpeechClient();

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

exports.synthesizeTagalog = functions.https.onRequest(async (req, res) => {
  try {
    const { text } = req.body;
    if (!text || typeof text !== 'string') {
      return res.status(400).json({ error: 'Text is required.' });
    }

    const request = {
      input: { text },
      voice: {
        languageCode: 'tl-PH',
        name: 'tl-PH-Wavenet-A',
        ssmlGender: 'FEMALE',
      },
      audioConfig: {
        audioEncoding: 'MP3',
      },
    };

    const [response] = await ttsClient.synthesizeSpeech(request);
    const audioContent = response.audioContent;
    if (!audioContent) {
      return res.status(500).json({ error: 'Failed to generate speech.' });
    }

    const audioBase64 = audioContent.toString('base64');
    return res.json({ audio: audioBase64 });
  } catch (error) {
    console.error('synthesizeTagalog error:', error);
    return res.status(500).json({ error: 'Text-to-Speech request failed.' });
  }
});
