# BM Work Tracker – Setup Guide

Daily work tracker for the Bombay Metrics sourcing team.
**One app, two ways to open it:** an Android app (APK) and a website. Both use the same online database, so everything syncs instantly.

Total setup time: about 45–60 minutes, one time only. All services used are free.

---

## What the app does

| Who | Can do |
|---|---|
| **Everyone** | Log work (task, category, time spent, status), see Today, Pending & Follow-ups (overdue / due today / upcoming), Day & Week summary, copy summary for WhatsApp/email, change own password |
| **Manager** | Everything above **plus**: Team tab (each member's hours today, open & overdue items), assign tasks to members with due dates, see summary of any member or the whole team, **Manage members** (add username + password, make manager, deactivate) |

- Nobody can register on their own – only a manager creates logins.
- Open items stay in **Pending** every day until marked Done (automatic carry-forward).
- Tasks assigned by a manager show "Assigned by …" and members cannot delete them.

---

## Step 1 – Create the Firebase project (the online database)

1. Go to **https://console.firebase.google.com** and sign in with a Google account (a team/shared Gmail is best).
2. Click **Create a project** → name: `bm-work-tracker` → turn **off** Google Analytics → **Create project**.

## Step 2 – Turn on login and the database

1. Left menu **Build → Authentication → Get started** → **Sign-in method** tab → **Email/Password** → Enable (first switch only) → **Save**.
2. Left menu **Build → Firestore Database → Create database**
   - Location: **asia-south1 (Mumbai)** → Next
   - Choose **Start in production mode** → **Create**.
3. Open the **Rules** tab, delete everything there, paste the full contents of the file **`firestore.rules`** → **Publish**.

## Step 3 – Register the Android app and the Web app

**Android:**
1. Project Overview (home icon) → **Add app** → Android icon.
2. Android package name: `com.bombaymetrics.bm_work_tracker` (type exactly) → nickname `BM Work Tracker` → **Register app**.
3. **Download google-services.json**. Skip the remaining steps (Next → Next → Continue to console).
4. Open `google-services.json` with Notepad. Open `lib/firebase_config.dart` and fill the **androidOptions** block:

| In firebase_config.dart | Copy from google-services.json |
|---|---|
| `apiKey` | `"current_key"` |
| `appId` | `"mobilesdk_app_id"` |
| `messagingSenderId` | `"project_number"` |
| `projectId` | `"project_id"` |
| `storageBucket` | `"storage_bucket"` |

**Web:**
1. Project Overview → **Add app** → Web icon `</>` → nickname `BM Work Tracker Web` → (leave Hosting unticked) → **Register app**.
2. You will see a `firebaseConfig = { apiKey: "...", authDomain: "...", ... }` block. Copy each value into the **webOptions** block of `lib/firebase_config.dart` (same names).

Keep the quotes `' '` around each value. Save the file.

## Step 4 – Create your manager login

1. Firebase → **Authentication → Users → Add user**
2. Email: `vignesh@bmworktracker.app`  Password: (your choice, min 6 characters) → **Add user**.

You will sign in with username **`vignesh`** and that password. (No real mailbox is needed – the app adds `@bmworktracker.app` itself.)

## Step 5 – Put the code on GitHub (it builds the APK and website for you)

1. Create a free account at **https://github.com** (if you don't have one).
2. Click **+ → New repository** → name `bm-work-tracker` → **Public** → **Create repository**.
   *(Public is needed for the free website. The Firebase keys are not passwords – data is protected by the login + rules from Step 2.)*
3. On the new repository page click **uploading an existing file**. Drag **everything inside** the unzipped `bm_work_tracker` folder (including `lib`, `test`, `tool`, `.github`, `pubspec.yaml`, `firestore.rules`) → **Commit changes**.
4. Check that the file `.github/workflows/build.yml` is visible in the repository.
   If the `.github` folder did not upload: **Add file → Create new file**, type the name `.github/workflows/build.yml`, paste the contents of that file, **Commit**.
5. Repository **Settings → Pages** → under "Build and deployment", Source: **GitHub Actions**.
6. *(Recommended)* Repository **Settings → Secrets and variables → Actions → New repository secret**
   Name: `KEYSTORE_BASE64`  Secret: paste the full text of `KEYSTORE_BASE64.txt` (separate file I gave you) → **Add secret**.
   This lets new versions install over the old app. Keep that file private.
7. Go to the **Actions** tab → click **Build app** → **Run workflow** (green button). Wait ~8–12 minutes for a green tick.

## Step 6 – Install / open the app

**Android phones**
1. Actions tab → open the latest green run → bottom **Artifacts** → download **BM-Work-Tracker-APK** (a zip). Unzip → `app-release.apk`.
2. Send the APK to phones (WhatsApp/email/Drive). Open it → allow **Install unknown apps** when asked → Install.

**Website (PC / laptop / any phone browser)**
- Address: `https://<your-github-username>.github.io/bm-work-tracker/`
- On a phone you can also use the browser menu → **Add to Home screen** to get an app icon.
- In Firebase → **Authentication → Settings → Authorized domains → Add domain** → `<your-github-username>.github.io`.

## Step 7 – First use

1. Sign in as `vignesh`. Your manager profile is created automatically.
2. Profile icon (top right) → **Manage members** → **Add member** → full name, username (e.g. `ravi.k`), password, role → **Create login**.
3. Share the username + password with the member. They can change the password later from the profile menu.
4. **Team** tab → **Assign task** (or tap a member → Assign task).

---

## Changing things later

| Want to change | Edit this on GitHub (pencil icon) |
|---|---|
| Work categories, daily target hours | `lib/config.dart` |
| Add another manager | Easiest: in the app, Manage members → ⋮ → Make manager |

Every save on GitHub rebuilds the APK and website automatically (Actions tab).

## Good to know

- **Forgotten password:** a manager cannot see or reset passwords. Deactivate the old login and create a new username for that person. (Their old entries remain in the database.)
- **Deactivate** blocks a person immediately on both app and website.
- **Offline:** the Android app saves entries without internet and syncs when back online.
- **Free limits (Firebase Spark plan):** 50,000 reads and 20,000 writes per day – far more than a sourcing team needs.

## Troubleshooting

| You see | Do this |
|---|---|
| "Setup failed – are the Firestore rules published?" or "permission-denied" | Repeat Step 2.3 (paste rules → Publish) |
| "The query requires an index" with a link | Open the link while logged into Firebase → **Create index** → wait 2–3 min |
| "Wrong username or password" for vignesh | Check Step 4 email is exactly `vignesh@bmworktracker.app` |
| App opens to an error about API key / FirebaseOptions | Values in `lib/firebase_config.dart` are missing or wrong (Step 3) |
| Red cross in GitHub Actions | Open the failed run, copy the red error lines and send them to Claude |
| New APK won't install over the old one | Uninstall the old app first (no data is lost – it's all online), or add the secret in Step 5.6 |
