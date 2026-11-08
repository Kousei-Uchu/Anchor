Anchor

A private safety plan, contacts and journal app for iPhone and iPad. Early build, parts will change. Anchor sends no data anywhere.

Layout

iOS/               Xcode project (open iOS/Anchor/Anchor.xcodeproj in Xcode 26 or later)
website/           Vite and React site for anchor.aspens.page
remotion-project/  Source for the promo video
scripts/           make-screenshots.sh (App Store screenshots and demo video), check-about-content.mjs (the About copy in the app and on the website must match), anchorbackup.py (opens an encrypted backup without the app), anchorkey.py (the key and recovery key formats, with a self-test)
docs/              Release guide and App Store copy
BUILD_STATUS.md    Running notes on the app's state (some older entries are out of date)

Website

Run it locally with: cd website && npm install && npm run dev
Build it with: npm run build (output in website/dist)
Deploy it on Vercel with Root Directory set to website.

Personal build flag

iOS/.../NSWMentalHealthReferenceView.swift is compiled only when the PERSONAL_BUILD compilation
condition is set. No shipped configuration sets it. It is for the developer's own copy only and
must never be released in the public build.
