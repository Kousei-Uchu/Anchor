// The words of the About screen in the app (AboutContent in
// iOS/Anchor/Anchor/Views/Settings/SettingsView.swift). The website's About
// page reads these too. scripts/check-about-content.mjs fails if the two
// files stop matching, so change both together and keep the order the same.

export const ABOUT_WEBSITE_URL = "https://anchor.aspens.page";
export const ABOUT_PRIVACY_URL = "https://anchor.aspens.page/privacy";
export const ABOUT_SOURCE_URL = "https://github.com/Kousei-Uchu/Anchor";
export const ABOUT_SUPPORT_EMAIL = "anchor@aspens.page";
export const ABOUT_CREATOR_SITE_URL = "https://aspens.page";

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

export const ABOUT_CREATOR_NAME = "Aspen, they/them (Kousei-Uchu)";

export const ABOUT_CREATOR_INTRO: string[] = [
  "I'm a Sydney based dev with a passionate hatred for commercialisation and the commodification of privacy. I love open source software, and I do what I can to provide support tools for mental health and for marginalised communities.",
  "I was sick of paying for several subscriptions across multiple apps and sending my mental health data to who knows where. So I made a support toolkit that feels warm, secure and yours, modelled on the tools I would actually use, and built in the most user controlled and private way I could.",
];

export const ABOUT_CREATOR_LINE = "Anchor is a toolkit designed for you, not for my wallet.";

export const ABOUT_CREATOR_VALUES = "Private, Free, and Yours. Entirely, Honestly, and Eternally.";

export const ABOUT_CREATOR_STORY: AboutNote[] = [
  { title: "Who it is for", body: "Anchor is for privacy-minded people who want a toolkit to help them along their mental health journey without becoming the product themselves. It is also for care providers who want to recommend a tool they can trust, if they choose to. And it is for the average person too, because you don't need a diagnosis to look after yourself." },
  { title: "Where it came from", body: "I built it for myself, around tools I already use or want to use. After I showed it to my family and my care providers, they encouraged me to keep working on it and to put it out into the world." },
  { title: "Why there are no accounts", body: "I refused to build accounts. As soon as you have to enter an email, your data is being collected and you can no longer trust that it is private." },
  { title: "A toolkit, not a therapist", body: "You can buy an IKEA flatpack, but it gets hard to put together well without consulting the manual. Anchor is a collection of tools that are useful on their own, and it does not replace a professional. If you are really having a hard time, or it is an emergency, please get some outside help." },
  { title: "About the AI", body: "A hand was given by an LLM while I built this, and it did not replace the human in the room. It is not vibe-coded slop. It is a passion project built alongside real-world commitments and, ironically, mental health struggles, where some help was needed. As of release I am the solo dev. I am being open about using AI in making this app, and I ask that you please don't shrink my effort, passion and care down to vibe-coded slop-scripts pumped out by a plagiarism machine on a Sunday afternoon over a cup of coffee." },
  { title: "Thank you", body: "Thank you to my psychologist, who advised on the details of this app. I am not naming them, out of respect for their privacy and their own interest." },
];

export const ABOUT_CREATOR_CONTACT = "Feedback, bug reports and ideas are welcome, by email at anchor@aspens.page or on GitHub. Questions about the licence go to licensing@aspens.page.";

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
