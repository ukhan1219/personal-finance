import * as logger from "firebase-functions/logger";
import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {FieldValue} from "firebase-admin/firestore";
import {UserRecord} from "firebase-admin/auth";

// Initialize Firebase Admin SDK once with explicit project ID
admin.initializeApp({
  projectId: process.env.GOOGLE_CLOUD_PROJECT || "glance-prod-457519",
});

// Obtain Firestore instance and configure it for the named database
const firestore = admin.firestore();
firestore.settings({
  // Ensures the client connects to your 'glance-prod' database, not '(default)'
  databaseId: "glance-prod",
});

// Confirm Firestore settings have been applied
logger.info(`Firestore init for db 'glance-prod': ${Boolean(firestore)}`);

const usersCollection = "users";

export const createUserDocument = functions.auth
  .user()
  .onCreate(async (user: UserRecord) => {
    const {uid, email} = user;
    logger.info(`New user: UID=${uid}. Starting Firestore write.`);

    if (!uid) {
      logger.error("Missing UID in auth event; aborting user doc creation.");
      return;
    }

    const newUserData = {
      email: email ?? null,
      createdAt: FieldValue.serverTimestamp(),
    };

    const userDocRef = firestore.collection(usersCollection).doc(uid);
    try {
      await userDocRef.set(newUserData);
      logger.info(`User document created at /users/${uid}`);
    } catch (error) {
      logger.error(`Failed to create user document for UID=${uid}`, error);
    }
  });
