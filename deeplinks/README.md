# Deep link verification files

Files the website (step 2) must serve **as is** so that `https://<domain>/@<username>`,
`https://<domain>/j/<token>` (and the older `/u/<username>`, `/e/<event id>`) open the SeeU app
when it is installed:

| File | Served at | Content-Type | Used by |
| --- | --- | --- | --- |
| `.well-known/assetlinks.json` | `https://<domain>/.well-known/assetlinks.json` | `application/json` | Android App Links (`autoVerify` intent filter in `AndroidManifest.xml`) |
| `.well-known/apple-app-site-association` | `https://<domain>/.well-known/apple-app-site-association` (no extension) | `application/json` | iOS Universal Links (Associated Domains) |

Rules: https only, HTTP 200, **no redirect** (not even `domain` → `www.domain`), no
authentication, no file extension added to the Apple file.

## Before going live

1. **Android fingerprints** (`sha256_cert_fingerprints`):
   - release: Play Console → *Test and release → App integrity → App signing key certificate → SHA-256*
     (and the upload key's SHA-256 if you also install builds signed with it);
   - local testing: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`
     on each developer machine (one line per fingerprint; remove the placeholders).
2. **Android host**: `seeu.linkHost` in `android/gradle.properties` = the website's domain.
3. **iOS**: `appIDs` = `<Team ID>.com.seeuapp.mobile`. `52HGFA36M9` is the current (free) Personal Team:
   replace it with the paid team's ID. Then in Xcode → Runner → Signing & Capabilities → **+ Associated Domains**:
   `applinks:<domain>` (needs the paid Apple Developer account; a Personal Team can't sign this capability).
4. **App**: `WEBSITE_URL` in `config/env.json` = `https://<domain>` (no trailing slash).
   Optionally `"SHOW_APP_LINKS": false` to hide the `seeu://` test links.

Check: Android `adb shell pm get-app-links com.seeuapp.mobile` (state `verified`);
iOS: long-press a link in Notes → "Open in SeeU".
