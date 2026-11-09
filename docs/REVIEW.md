# Review walkthrough

A way to go through every change one at a time, on made-up content, and write down what you would like different. Test builds only.

## Run it

    scripts/review-on-device.sh          your connected iPhone
    scripts/review-on-device.sh --sim    an iPhone simulator
    DEVICE="Name" scripts/review-on-device.sh    a particular phone

The phone needs to be plugged in, unlocked, trusted, with Developer Mode on. The script builds the Debug app, installs it and launches it with `-AnchorDemo -AnchorReview`. The app runs on the in-memory demo store, so your own data is not opened, and nothing it does is kept. Open the app normally afterwards and your own data is back.

The first round, 66 stops, is finished and removed from the list. It is kept in git history (`d0fa55a`). This round is the changes added since, and notes are kept separately from the first round.

## Using it

- The bar above the tab bar says which change you are on (for example 3 of 27, Patch 45e). The arrows go back and forward. The list button shows every stop.
- Tap the title to see what changed and what to try, and to type a note. Notes are kept on the phone between launches.
- Where a screen can be opened directly, the arrows open it in a sheet with the bar underneath. Otherwise the text says where to go.
- In the list, Share notes sends every stop, numbered, with your note under it.

## Where it lives

`Support/ReviewWalkthrough.swift`, inside `#if DEBUG`. The stops are the `ReviewStops.all` table: add a row to add a stop. It runs only when both `-AnchorDemo` and `-AnchorReview` are on the launch line.
