Automated screenshots and video

One-time setup in Xcode:
1. File, New, Target, iOS, UI Testing Bundle. Name it AnchorUITests, target to be tested: Anchor. Finish.
2. Delete the template files Xcode created inside the AnchorUITests group (Move to Trash).
3. Right-click the AnchorUITests group, Add Files to Anchor, pick iOS/Anchor/AnchorUITests/ScreenshotTests.swift, and tick the AnchorUITests target.
4. Product, Scheme, Edit Scheme, Test: make sure AnchorUITests is listed and ticked.
5. Install ffmpeg if you want the video converted: brew install ffmpeg

Run it from the repo root:
  ./scripts/make-screenshots.sh

What it does: boots a Pro Max iPhone and a 13 inch iPad simulator, sets a clean 9:41 status bar, runs the app with made-up demo data (in memory, nothing saved), takes light and dark screenshots, copies the first six iPhone ones into website/assets/media as shot-1 to shot-6, records a tour video as anchor-demo.mp4, and leaves App Store sized sets in build/screenshots.

To change which screens are shot or how the tour moves, edit ScreenshotTests.swift. To change the demo content, edit DemoMode in AnchorApp.swift.
