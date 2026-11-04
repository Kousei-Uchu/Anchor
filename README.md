Anchor

A private safety plan, contacts and journal app for iPhone and iPad. Early build, parts will change. Anchor sends no data anywhere.

Layout

iOS/        Xcode project (open iOS/Anchor/Anchor.xcodeproj in Xcode 26 or later)
website/    Static site for anchor.aspens.page (no build step)
docs/       Release guide and App Store copy
BUILD_STATUS.md   Running notes on the app's state

Website

The site is plain HTML, CSS and JS. Preview it locally with: cd website && python3 -m http.server 8000
Deploy it on Vercel with Root Directory set to website.
