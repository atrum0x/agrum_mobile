# Sharing the app (Firebase App Distribution)

Every push to `main` runs `.github/workflows/distribute.yml`. The workflow runs `flutter analyze` and
`flutter test`, builds a signed release APK and sends it to the Firebase tester group `testers`. The
commit message becomes the release notes. You can also start it by hand under
**Actions → Distribute → Run workflow**.

## One-time setup

### 1. Firebase project

1. Go to <https://console.firebase.google.com>, then **Add project** (no Google Analytics needed). The free
   Spark plan is enough.
2. **Add app → Android**. Package name: `com.atrum.agrum_mobile`. You can skip the
   `google-services.json` download, because the app doesn't use the Firebase SDK.
3. **Project settings → General → Your apps**: copy the **App ID** (`1:1234…:android:abcd…`).
4. **Release & Monitor → App Distribution → Get started**. On the **Testers & Groups** tab, create a group
   with the alias **`testers`** and add your testers' emails.

### 2. Service account for CI

1. Go to <https://console.cloud.google.com/iam-admin/serviceaccounts> and select the Firebase project.
2. **Create service account**, for example `github-distribute`, and give it the role
   **Firebase App Distribution Admin**.
3. Open it, go to **Keys → Add key → JSON**, and download the file. Keep the file private.

### 3. Release signing key

Create the key once and **back it up**. If you lose it, testers have to uninstall the app before they can
install updates.

```powershell
keytool -genkey -v -keystore $HOME\agrum-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\agrum-upload.jks")) | Set-Clipboard
```

The second line copies the keystore to your clipboard as base64, ready for the secret below.

To build signed APKs on your own PC as well, create `android/key.properties`, which git ignores:

```properties
storeFile=C:/Users/<you>/agrum-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

### 4. GitHub secrets

In the repo, go to **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the base64 text from step 3 |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | the key password (the same as the keystore password, unless you set a different one) |
| `FIREBASE_APP_ID` | the App ID from step 1 |
| `FIREBASE_SERVICE_ACCOUNT` | the whole content of the JSON key file from step 2 |
| `API_BASE_URL` | the backend URL phones use, for example `https://agrum-api.onrender.com` |

## For testers

1. Accept the email invite from Firebase App Distribution (open it on the phone).
2. Install the **App Tester** app when prompted, and allow installs from that source.
3. Each new build shows up in App Tester with a notification. Tap **Download** to update.

The app keeps its data across updates because each build has a higher build number (the workflow run
number) and is signed with the same key.
