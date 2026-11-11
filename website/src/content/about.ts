// The words of the About screen in the app (AboutContent in
// iOS/Anchor/Anchor/Views/Settings/SettingsView.swift). The website's About
// page reads these too. scripts/check-about-content.mjs fails if the two
// files stop matching, so change both together and keep the order the same.

export const ABOUT_WEBSITE_URL = "https://anchor.aspens.page";
export const ABOUT_PRIVACY_URL = "https://anchor.aspens.page/privacy";
export const ABOUT_SOURCE_URL = "https://github.com/Kousei-Uchu/Anchor";
export const ABOUT_SUPPORT_EMAIL = "anchor@aspens.page";

export const ABOUT_PURPOSE = "Anchor is a private place for your safety plan, your people and your journal, for the hard days and the ordinary ones. It is an early build and parts of it will change.";

export const ABOUT_PRINCIPLES: string[] = [
  "No scores and no streak pressure. Anchor does not grade how you are doing.",
  "Local first. What you write stays on your phone, with no account, no ads and no tracking.",
  "Nothing is shared unless you share it. Messages and exports go only where you send them.",
];

export const ABOUT_LICENCES = "Anchor is built with Apple's own frameworks and has no third-party fonts. Finding who is speaking uses the FluidAudio code (Apache License 2.0) from Fluid Inference, and speaker-separation models that Fluid Inference converted to Core ML from pyannote's speaker-diarization-community-1, with parts from WeSpeaker and BUT Speech@FIT, licensed under CC-BY-4.0 (creativecommons.org/licenses/by/4.0). The models are modified conversions. They run on your phone and nothing is sent anywhere.";

export const ABOUT_CONTACT_NOTE = "I can't reply in real time. If you are in danger right now, call your local emergency number or a crisis line.";

export type AboutNote = { title: string; body: string };
export type AboutVersion = { version: string; added: AboutNote[]; changed: AboutNote[]; removed: AboutNote[] };

// Newest version first, as in the app. To add a version, put it at the top.
export const ABOUT_VERSIONS: AboutVersion[] = [
  {
    version: "1.0",
    added: [
      { title: "Sleep journal", body: "An optional sleep journal under Plan, with Apple Health if you want it. Nothing is scored." },
      { title: "Export for someone", body: "Choose who it is for and what goes in, then make a PDF or a web page to share." },
      { title: "Look at what's stored", body: "See everything Anchor holds, behind Face ID or your passcode, in plain language." },
      { title: "Tasks and routines", body: "Tasks with steps, a focus timer, Plan my day, quick lists, routines and checklists." },
      { title: "People and providers", body: "A page for each person in Thread, and more than one provider in Bridge." },
      { title: "Sections of your own", body: "The safety plan and the Boundaries list are sections you rename, reorder and hide." },
      { title: "A new Journal page", body: "The page works like Apple's Journal, with bookmarks and a month and year view." },
      { title: "Feedback loops", body: "Draw a loop or a free map from a template, and share it as a picture or a PDF." },
    ],
    changed: [],
    removed: [],
  },
];
