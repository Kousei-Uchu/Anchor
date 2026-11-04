Drop real recordings from the app here. Missing files are hidden automatically.

Files the site looks for:
  anchor-demo.mp4        looping video, shown in a phone frame on the home page
  shot-1.png to shot-6.png   screenshots, shown in a row under the video

Record from the iOS Simulator (run the app first, pick an iPhone Pro model):
  xcrun simctl io booted recordVideo --codec=h264 anchor-demo.mov
  (press Control-C to stop)
Screenshot:
  xcrun simctl io booted screenshot shot-1.png

Make the video web friendly (needs ffmpeg, install with: brew install ffmpeg):
  ffmpeg -i anchor-demo.mov -vf scale=-2:1280 -an -movflags +faststart -pix_fmt yuv420p anchor-demo.mp4

Use made-up content only. Do not record real contacts or journal entries.
