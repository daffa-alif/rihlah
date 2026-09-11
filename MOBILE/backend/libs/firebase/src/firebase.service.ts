import { Injectable, OnModuleInit } from '@nestjs/common';
import * as admin from 'firebase-admin';

@Injectable()
export class FirebaseService implements OnModuleInit {
  private app: admin.app.App;

  onModuleInit() {
    if (admin.apps.length === 0) {
      this.app = admin.initializeApp({
        projectId: process.env.FIREBASE_PROJECT_ID || 'rihlah-75a1b',
        // In production, GOOGLE_APPLICATION_CREDENTIALS env var is used.
        // In dev, you can set FIREBASE_AUTH_EMULATOR_HOST for local testing.
      });
    } else {
      this.app = admin.apps[0] as admin.app.App;
    }
  }

  get auth(): admin.auth.Auth {
    return this.app.auth();
  }

  get firestore(): admin.firestore.Firestore {
    return this.app.firestore();
  }

  get messaging(): admin.messaging.Messaging {
    return this.app.messaging();
  }

  /** Verify a Firebase ID token and return the decoded claims. */
  async verifyToken(token: string): Promise<admin.auth.DecodedIdToken> {
    return this.auth.verifyIdToken(token);
  }

  /** Set a custom claim on a Firebase Auth user. */
  async setUserRole(uid: string, role: string): Promise<void> {
    await this.auth.setCustomUserClaims(uid, { role });
  }

  /** Send a push notification via FCM to a device token or topic. */
  async sendPush(
    tokenOrTopic: string,
    payload: admin.messaging.Message,
  ): Promise<string> {
    if (tokenOrTopic.startsWith('/topics/')) {
      return this.messaging.send({ ...payload, topic: tokenOrTopic });
    }
    return this.messaging.send({ ...payload, token: tokenOrTopic });
  }
}
