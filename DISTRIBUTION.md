# Sharing the app (Firebase App Distribution)

## One app per backend

The app is built in **flavors**. Each one is a separate app on the phone, so a tester can have UAT and
prod installed side by side. Each has its own name, its own data, login and fingerprint key, and talks
to its own backend.

| Flavor | App id (package name) | Name on the phone | Built by |
|---|---|---|---|
| `dev` | `com.atrum.agrum_mobile.dev` | **Agrum DEV** | only `flutter run` on your PC; never built by CI |
| `uat` | `com.atrum.agrum_mobile.uat` | **Agrum UAT** | every push to `uat` |
| `prod` | `com.atrum.agrum_mobile` | **Agrum** | every push to `main` |

The DEV app exists so that running the app from your PC doesn't replace the UAT app installed from
Firebase. It needs no Firebase app and no GitHub environment.

The DEV and UAT apps show a **"DEV – test system" / "UAT – test system"** badge on the login screen. The
prod app shows none. `prod` keeps the original app id, so phones that already had the app keep their
data and receive the prod builds.

`.github/workflows/distribute.yml` picks the flavor from the branch, runs `flutter analyze` and
`flutter test`, builds a signed release APK with `--flavor`, and sends it to the Firebase tester group
`testers`. The commit message becomes the release notes. **Run workflow** builds `uat` or `prod` by hand.

Flow, the same as the backend and web:

```
feature branch → merge into uat → Agrum UAT build → testers check it
              → merge uat into main → Agrum (prod) build
```

Locally, plain `flutter run` builds the **dev** app (`default-flavor: dev` in `pubspec.yaml`). Pick another
with `--flavor`:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080              # Agrum DEV, local backend
flutter run --flavor uat --dart-define=API_BASE_URL=https://uat-api.yourdomain
flutter build apk --release --flavor prod --dart-define=API_BASE_URL=https://api.yourdomain
# APK: build/app/outputs/flutter-apk/app-<flavor>-release.apk
```

## One-time setup

### 1. Firebase project

1. Go to <https://console.firebase.google.com>, then **Add project** (no Google Analytics needed). The free
   Spark plan is enough.
2. **Add app → Android**, once per distributed flavor, in the **same** Firebase project:
   - `com.atrum.agrum_mobile` (prod; this one already exists)
   - `com.atrum.agrum_mobile.uat`

   You can skip the `google-services.json` download, because the app doesn't use the Firebase SDK.
3. **Project settings → General → Your apps**: copy each app's **App ID** (`1:1234…:android:abcd…`). They
   are all different; each goes in its own GitHub environment (step 4).
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

**a) Shared by both apps:** repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the base64 text from step 3 |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | the key password (the same as the keystore password, unless you set a different one) |
| `FIREBASE_SERVICE_ACCOUNT` | the whole content of the JSON key file from step 2 |

One signing key signs both apps. That's fine: they have different app ids.

**b) One environment per app:** repo → **Settings → Environments → New environment**. Create `uat` and
`prod` (exactly these names). In each, under **Environment secrets → Add secret**, add:

| Secret | `uat` | `prod` |
|---|---|---|
| `API_BASE_URL` | `https://uat-api.yourdomain` | `https://api.yourdomain` |
| `FIREBASE_APP_ID` | App ID of `com.atrum.agrum_mobile.uat` | App ID of `com.atrum.agrum_mobile` |

The URL has no trailing `/`. If an environment is missing either secret, the workflow stops at
"Check the environment's secrets" and says which one.

> **Older repo-level `API_BASE_URL` / `FIREBASE_APP_ID` secrets.** An environment secret with the same
> name wins over a repo-level one. Until the `prod` environment has its own two secrets, prod builds fall
> back to the repo-level ones. Once both environments are filled, delete the two repo-level secrets
> so nothing is picked up by accident.

> **Optional protection for prod:** in the `prod` environment, tick **Required reviewers** and add
> yourself. Every prod build then waits until you press **Approve** in the Actions run.

## For testers

1. Accept the email invite from Firebase App Distribution (open it on the phone).
2. Install the **App Tester** app when prompted, and allow installs from that source.
3. App Tester lists **Agrum UAT** and **Agrum** separately. Install the ones you test.
   Each new build shows up with a notification. Tap **Download** to update. (App Tester doesn't update
   by itself.)
4. A newly installed app starts empty: log in again, and turn the fingerprint on again in that app.
   Registered faces download from that app's own server.

The app keeps its data across updates because each build has a higher build number (the workflow run
number) and is signed with the same key.
