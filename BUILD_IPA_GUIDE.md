# Getting AFK Remote onto your iPhone with NO Mac (free)

You'll use **GitHub Actions** (free cloud Macs) to build an unsigned `.ipa`, then
**SideStore** to install it with your **free** Apple ID. No $99, no Mac you own.

The build script is already in this project at:
`.github/workflows/build-ipa.yml` — you don't have to write anything.

---

## Part 1 - Put the code on GitHub

1. Make a free account at https://github.com
2. Click the **+** (top right) -> **New repository**.
   - Name it anything, e.g. `afk-remote`.
   - Set it to **Private** (your choice) and click **Create repository**.
3. On the new repo page click **uploading an existing file**.
4. Unzip `AFK_Remote_source.zip` on your PC, then drag **everything inside it**
   into the upload box. IMPORTANT: keep the folder structure — the
   `.github/workflows/build-ipa.yml` file must stay in that exact path.
   (If the drag-and-drop hides the `.github` folder because it starts with a dot,
   see "If the .github folder won't upload" at the bottom.)
5. Click **Commit changes**.

## Part 2 - Build the .ipa

1. On your repo, click the **Actions** tab.
2. If it asks, click the green button to enable workflows.
3. On the left pick **Build unsigned IPA**, then on the right click
   **Run workflow** -> **Run workflow**.
4. Wait ~5-10 minutes. A yellow dot means running; a green check means done.
   (A red X means it errored — open it, copy the red text, and send it to me.)
5. Click the finished run. Scroll to the bottom to **Artifacts** and download
   **AFK-Remote-unsigned-ipa**. It's a `.zip` — unzip it to get
   **AfkRemoteIos.ipa**.

## Part 3 - Install with SideStore (free Apple ID)

1. Set up SideStore if you haven't: https://sidestore.io (follow their guide;
   it uses your normal free Apple ID — do NOT pay for the Developer Program).
2. Get `AfkRemoteIos.ipa` onto your phone — **LocalSend** from your PC works great.
3. Open **SideStore** -> **My Apps** -> **+** -> pick `AfkRemoteIos.ipa` -> install.
4. Because it's a free Apple ID, the app works for **7 days**, then you re-sign it
   inside SideStore (one tap) to refresh it. That's an Apple rule for free IDs,
   not something I can remove.

---

## If the .github folder won't upload

GitHub's web uploader sometimes hides dot-folders. Easiest fix:
1. Upload everything else first and commit.
2. On the repo, click **Add file** -> **Create new file**.
3. In the name box type exactly: `.github/workflows/build-ipa.yml`
   (typing the `/` makes the folders).
4. Open `.github/workflows/build-ipa.yml` from the unzipped source on your PC,
   copy all its text, paste it in, and **Commit**.

---

## First time you open the app

Tap **Get Started** -> paste your Discord **bot token** and **channel ID** ->
**Test Connection** -> **Save**. Your token is stored only on your phone.
