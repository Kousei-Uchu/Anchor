# Anchor promo (Remotion)

    npm install
    npm run studio     # preview and scrub
    npm run render     # writes out/anchor-promo.mp4 (1080x1920, 30fps, with audio)

## How picture and sound stay in sync
`src/music.json` is the single clock: tempo, chords and every note (bar, beat, pitch).
- `npm run audio` (python3, numpy, scipy) builds `public/ambient.wav` from it.
- `src/Promo.tsx` reads the same file. Scenes change on bar lines, headlines land on a
  note, sub-lines on the next note, and the mascot nods softly on each note.

To retime something, edit `music.json` (or the `at(bar, beat)` cues in Promo.tsx),
run `npm run audio`, then render again. Tempo changes move everything together.

## Loudness
`MASTER` at the top of `scripts/make-audio.py` sets the overall level (lower = quieter), then `npm run audio`.
The shape of the ending (build, soft peak, long wind-down) is the `dynamics` list in `src/music.json`.

## Rhythm
Every caption uses the same grid, `G` in `src/Promo.tsx`: headline on beat 0.5 of its bar, sub-line on beat 1.5,
gone at beat 4.3. The final card adds one new line every two beats and then holds for several seconds.

## Mascot
Gaze, blinks and squash-and-stretch are driven by the moments something appears (`ATTN`), plus a seeded
random generator for blink timing (`rng(11)` in `BLINKS`; change the seed for a different blink pattern).

## Other knobs (src/Promo.tsx)
- `FRAME`: phone body colours (try black: edgeLight '#4a4a4d', edgeDark '#1d1d1f', rim '#000', bezel '#000')
- `FEATURES`: captions and screenshots (public/shots/*.jpg)
- For a silent file: `npx remotion render src/index.ts Promo out/silent.mp4 --muted`
