import * as logger from "firebase-functions/logger";
import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin"; // Import Firebase Admin SDK
import {FieldValue} from "firebase-admin/firestore"; // Import FieldValue
import {UserRecord} from "firebase-admin/auth";

// Initialize Firebase Admin SDK ONLY ONCE at the top level
// This uses the default credentials of the Cloud Functions runtime environment
admin.initializeApp();

const firestore = admin.firestore(); // Get Firestore instance
const usersCollection = "users"; // Define collection name

/**
 * Cloud Function triggered when a new Firebase Authentication user is created.
 * Creates a corresponding document in the 'users' collection in Firestore.
 */
export const createUserDocument = functions.auth
  .user()
  .onCreate(async (user: UserRecord) => {
    const {uid, email} = user;

    logger.info(
      "New user signed up: " +
      `UID=${uid}, ` +
      "Creating Firestore doc."
    );

    if (!uid) {
      logger.error("User UID is missing in the auth event. Cannot create doc.");
      return;
    }

    // Prepare the data for the new user document
    const newUserData = {
      email: email ?? null,
      createdAt: FieldValue.serverTimestamp(),
    };

    // Get a reference to the document path: /users/{userID}
    const userDocRef = firestore.collection(usersCollection).doc(uid);

    try {
      // Set the data in Firestore
      await userDocRef.set(newUserData);
      logger.info(
        "Successfully created Firestore document for user: " +
        `${uid}`
      );
    } catch (error) {
      logger.error(
        "Failed to create Firestore document for user: " +
        `${uid}`,
        error
      );
      // Consider adding more robust error handling or retries if needed
    }
  });

// You can add other functions (HTTP, Firestore triggers, etc.) here as needed
// e.g., export const anotherFunction = onRequest(...)
