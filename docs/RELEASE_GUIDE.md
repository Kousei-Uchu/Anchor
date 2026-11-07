# Anchor release guide (TestFlight first, then App Store)

What I changed in the project is listed at the bottom. This guide is everything you still need to do yourself, in order.

You need: a Mac with **Xcode 26 or later** (Apple requires current-SDK builds for upload), your paid Apple Developer account signed in under Xcode, Settings, Accounts.

---

## Part 1: Open and sanity check the project

1. Unzip `Anchor-project.zip`. Open `iOS/Anchor/Anchor.xcodeproj`.
2. Click the project (blue icon), then the **Anchor** target, then **Signing & Capabilities**. Set **Team** to your paid team. Tick **Automatically manage signing**. Do the same for the **AnchorWidgetExtension** target.
3. On the Anchor target, check these capabilities are listed. If one is missing, press **+ Capability** and add it:
   - **App Groups** with `group.page.aspens.anchor` ticked
   - **Journaling Suggestions**
4. On the widget target, check **App Groups** has the same `group.page.aspens.anchor` ticked.
5. If Xcode shows a red error about a provisioning profile and an entitlement, that is the Journaling Suggestions entitlement. Add the capability by hand (step 3) and it will resolve.
6. MusicKit: go to developer.apple.com, Account, Certificates, Identifiers and Profiles, Identifiers, click `page.aspens.anchor`, tick **MusicKit** under App Services (it may be under the "App Services" tab), and Save. Only needed if you keep the "recent music" suggestion.
7. Open the Anchor target, **General**. Under **App Icons and Launch Screen**, the App Icon source should be `AppIcon`. You should see the anchor icon in the project navigator as `AppIcon.icon`. Double-click it to open it in Icon Composer if you want to tweak colours.
8. Check **Supported Destinations** on the Anchor target lists iPhone, iPad, and Mac (Designed for iPad).
9. Build and run on a real iPhone, then on an iPad simulator (and a real iPad if you have one). Quick test list:
   - Face ID lock opens and relocks
   - Lock screen widget shows a contact and tapping it reaches the call confirmation (widgets only show data after you open Plan once)
   - Add a trigger window, confirm a notification arrives
   - Journal, then the sparkles "journaling suggestions" button, calendar, photos, music
   - Crisis card on Now, tap the region line at the bottom, change region
   - Rotate the iPad, check nothing looks broken
10. Check that `SUPPORT_EMAIL` in `website/src/content/meta.ts` is the address you want to be public. It appears on the privacy and support pages, and Apple may use it to contact you.

## Part 2: Host the website, privacy and support pages

1. The site in `website/` is a Vite and React app that builds to static pages, including `/privacy`, `/support` and `/demo`. Check it builds: `cd website && npm install && npm run build`.
2. Deploy from the `website/` folder with `npx vercel --prod`, or connect the GitHub repo in Vercel and set Root Directory to `website`. Vercel detects Vite: the build command is `npm run build` and the output directory is `dist`.
3. In Vercel, add `anchor.aspens.page` as a domain on that project. In Cloudflare DNS, add the CNAME Vercel tells you to (set it to **DNS only** while Vercel verifies).
4. Open https://anchor.aspens.page/privacy and /support in a browser to confirm they load. Apple requires both URLs to work before submission.

## Part 3: Create the app in App Store Connect

1. Go to appstoreconnect.apple.com, then **Business** or **Agreements**, and make sure the Apple Developer Program agreement is accepted.
2. **Apps**, **+**, **New App**.
   - Platforms: iOS
   - Name: Anchor (if taken, try "Anchor: Safety & Support")
   - Primary language: English (Australia)
   - Bundle ID: `page.aspens.anchor` (appears after Xcode has registered it; if not in the list, open Xcode once with signing set up)
   - SKU: anything unique, e.g. `anchor-ios-1`
3. Do not create a separate record for the widget. It ships inside the app.

## Part 4: Upload a build

1. In Xcode, set the run destination to **Any iOS Device (arm64)**.
2. Check **General**, Version `1.0` and Build `1`. **Every upload needs a build number higher than the last one.** Bump Build for each retry, on both targets.
3. **Product**, **Archive**. Wait for the Organizer window.
4. Select the archive, **Distribute App**, **App Store Connect**, **Distribute** (keep the defaults: upload, automatically manage signing).
5. Wait for the email, or watch **TestFlight** in App Store Connect. Processing takes 5 to 30 minutes.
6. If you get an email with "ITMS-" warnings, forward me the text. The privacy manifest and encryption key are already in, so the usual first-time ones should be gone.

## Part 5: TestFlight (just you)

1. App Store Connect, your app, **TestFlight**. When the build shows up, it should not ask about encryption.
2. **Internal Testing**, **+** to create a group, add yourself (you must be a user on your team). Internal builds need **no Apple review**.
3. Install **TestFlight** on your phone, accept the invite, install Anchor.
4. For friends or family: **External Testing** needs a short Beta App Review, a privacy policy URL, and "What to test" text (see `APP_STORE_COPY.md`).

## Part 6: App Store submission

1. In the app's **App Store** tab, version 1.0:
   - Paste the copy from `APP_STORE_COPY.md` (name, subtitle, promo text, description, keywords, support URL, marketing URL optional).
   - **Screenshots**: iPhone 6.9 inch (1320 x 2868) and iPad 13 inch (2064 x 2752) are required. Easiest: run on the biggest simulator (iPhone 17 Pro Max style, iPad Pro 13 inch), press Cmd+S to save, and upload 3 to 6 of Now, Plan, Journal, Bridge, Thread. Do not show real personal data.
   - **Privacy Policy URL**: `https://anchor.aspens.page/privacy`
   - **Support URL**: `https://anchor.aspens.page/support`
2. **App Privacy**: choose **No, we do not collect data from this app**. This is accurate because everything stays on device (check this stays true if you ever add analytics or sync).
3. **Age Rating**: answer the questionnaire honestly. Mental health content means you will answer yes to the medical or wellness information questions. Expect a rating around 13+.
4. **Category**: Health & Fitness (primary). Avoid "Medical", which draws stricter review.
5. **Price**: Free. **Availability**: all countries is fine now that crisis numbers are region aware. Leave Mac (Designed for iPad) availability on if you want it.
6. **App Review Information**: your contact details, and paste the review notes from `APP_STORE_COPY.md`. No demo account is needed (there are no accounts).
7. Pick the uploaded build under **Build**, then **Add for Review**, then **Submit**. Review is usually 1 to 3 days.

## Likely review questions

- "Is this a medical app?" Answer in notes: no, it is a personal planning and journaling tool, it makes no diagnosis or treatment claims, and links to crisis lines.
- Permission strings are all present and only requested on use. If they ask about the Face ID prompt, it is the app's own lock, optional in Plan, Settings.
- If they mention the red "could not open saved data" banner: that is a safety fallback if the on-device database cannot open.

## After release: one rule that matters

Once real users have data, **every SwiftData model change must be migration-safe** (adding optional fields is fine, renaming or deleting fields is not without a migration plan). Tell me before you change a model after launch.

---

## What I changed in the project

- App group in code is now `group.page.aspens.anchor` (was the old `com.sorren` one, which would have left the widget empty). URL scheme name tidied.
- Added Icon Composer icon `Anchor/AppIcon.icon` (terracotta background, sage halo, cream anchor) and removed the old empty icon set.
- Added `PrivacyInfo.xcprivacy` for the app and the widget, wired into both targets.
- Added the export-compliance key (`ITSAppUsesNonExemptEncryption = NO`).
- iPad: all four orientations allowed on iPad, and "Mac (Designed for iPad)" turned on.
- Crisis numbers are region aware (AU, US, CA, UK, IE, NZ, plus a generic fallback with a helpline directory), default to the phone's region, and can be overridden from the card.
- Journaling Suggestions: added the entitlement and an "Apple's journaling suggestions" picker at the top of the journal suggestions sheet.
- Fixed a launch-crash risk: the app used to `fatalError` if the database could not open. It now falls back to a temporary store with a visible red banner, and never deletes your real data.
- Changed data protection from `complete` to `completeUntilFirstUserAuthentication`. Still encrypted at rest, but the app can now open its database when iOS launches it in the background while the phone is locked (for example a notification action). With `complete` that case would have failed.
- Privacy and support pages in `web/`.
