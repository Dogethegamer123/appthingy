# AFK Remote — Auto-Update Setup (do this ONCE)

After this, releasing a new version = change one number + push. SideStore/LiveContainer
will show **Update** automatically. No more hand-editing the gist, no more uploading IPAs.

---

## Step 1 — Replace your workflow file

In your `appthingy` repo, **delete** `.github/workflows/build-ipa.yml`
and add `.github/workflows/build_and_publish.yml` (the file from this chat).
(Keep that exact folder path.)

## Step 2 — Make a GitHub token (lets the workflow edit your gist)

1. GitHub → your avatar (top-right) → **Settings**
2. Scroll down the left menu → **Developer settings**
3. **Personal access tokens** → **Tokens (classic)**
4. **Generate new token (classic)**
   - Note: `afk gist`
   - Expiration: **No expiration**
   - Tick **only** the box named **`gist`**
5. **Generate token** → **COPY it now** (you only see it once).

## Step 3 — Save two repo secrets

In `appthingy` repo → **Settings** → **Secrets and variables** → **Actions**
→ **New repository secret**, add these two:

| Name | Secret value |
|------|--------------|
| `GIST_TOKEN` | *(paste the token from Step 2)* |
| `GIST_ID` | `5cf9f2ea76cc5ed7ee69638ecd0ccdaa` |

## Step 4 — Make sure `icon.png` is in the repo root

The workflow points the source icon at `icon.png` on your `main` branch.
If it's not already there, add the `icon.png` from this chat to the repo root.

---

## That's it. From now on, to release a new version:

1. Open `.github/workflows/build_and_publish.yml`
2. Change the line near the top:  `APP_VERSION: "1.1.0"`  → e.g. `"1.2.0"`
3. Commit / push.
4. Wait for the green check in the **Actions** tab.
5. In SideStore/LiveContainer: **pull-to-refresh** the source → **Update** appears.

The workflow builds the IPA, stamps that version into it, creates a release
`vX.Y.Z` with the IPA, and rewrites your gist to match — all by itself.

### One note about the source link
Your SideStore source URL does **not** change — it's still:
`https://gist.githubusercontent.com/Dogethegamer123/5cf9f2ea76cc5ed7ee69638ecd0ccdaa/raw/afkremote-source.json`

### If something goes wrong
- Open the failed run in the **Actions** tab and read the red step.
- `Gist update HTTP 404` → `GIST_ID` wrong, or the token doesn't have the `gist` scope.
- `Gist update HTTP 401/403` → `GIST_TOKEN` wrong or expired.
- Release step fails → the repo needs Actions write permission:
  Settings → Actions → General → Workflow permissions → **Read and write**.
