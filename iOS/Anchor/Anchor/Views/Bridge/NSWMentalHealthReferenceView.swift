//
//  NSWMentalHealthReferenceView.swift
//  Anchor
//
//  Was one long scroll of dense paragraphs — restructured into a menu of
//  focused sub-pages (feedback: "feels cluttered and confusing"), plus a
//  Confidentiality section that didn't exist before at all. Plain-language
//  summary only, not legal advice, still linking to primary sources rather
//  than trying to be the final word. Content paraphrased from the Mental
//  Health Act 2007 (NSW), the MHCC Mental Health Rights Manual, and general
//  NSW health-privacy principles; sources listed on each page.
//
//  PERSONAL COPY ONLY.
//  This screen is compiled only when the PERSONAL_BUILD compilation condition is set.
//  No shipped configuration sets it (Debug, Release, TestFlight and App Store builds
//  all leave it off), so it is not part of the public app. It is NSW-specific legal
//  reference material kept for the developer's own copy, and it may be removed
//  entirely later. It must never be released in the public build. If you add
//  PERSONAL_BUILD to a local build in Xcode, do not use that build for screenshots,
//  TestFlight or Archive.
//

#if PERSONAL_BUILD
import SwiftUI

struct NSWMentalHealthReferenceView: View {
    var body: some View {
        List {
            Section {
                Text("Plain-language only, not legal advice. Pick a topic.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)

            NavigationLink { HospitalisationReferenceView() } label: {
                Anchor.MenuRow(icon: "building.2.fill", title: "Hospitalisation", tint: Anchor.Theme.accent)
            }
            NavigationLink { ConfidentialityReferenceView() } label: {
                Anchor.MenuRow(icon: "lock.fill", title: "Confidentiality", tint: Anchor.Theme.accent)
            }
            NavigationLink { TalkingToYourPsychReferenceView() } label: {
                Anchor.MenuRow(icon: "bubble.left.and.bubble.right.fill", title: "Talking to your psych", tint: Anchor.Theme.sage)
            }
        }
        .navigationTitle("NSW mental health law")
    }
}

/// Shared scaffolding for each sub-page: a title, plain-language body, and
/// a consistent sources/disclaimer footer, so every page reads the same
/// way instead of one giant undifferentiated block of text.
private struct ReferencePage<Content: View>: View {
    let sources: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content()

                Group {
                    Text("Sources").font(.caption).bold()
                    Text(sources)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("This is a plain-language summary, not legal advice, and laws can change. Check the current Act or ask a lawyer, advocate, or your clinician directly for anything that matters for a real decision.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
}

struct HospitalisationReferenceView: View {
    var body: some View {
        ReferencePage(sources: "Mental Health Act 2007 (NSW), sections 12–16 (legislation.nsw.gov.au) · MHCC Mental Health Rights Manual, Chapter 4 (mhrm.mhcc.org.au)") {
            Group {
                Text("What has to be true first").font(.headline)
                Text("""
                Someone can only be involuntarily admitted if both of these are true:

                1. A doctor assesses them as a "mentally ill person" or "mentally disordered person" as those terms are specifically defined in the Act, not just "struggling" or "in distress" in the everyday sense.
                2. There's no less restrictive option reasonably available, like support from family, a community mental health team, or a voluntary admission.

                Being a "mentally ill person" under the Act specifically means a doctor has reasonable grounds to believe treatment or control is necessary for your own protection from serious harm, or for someone else's protection. It doesn't mean just that you're going through a hard time.
                """)
                .font(.subheadline)
            }

            Group {
                Text("How it usually happens").font(.headline)
                Text("""
                A doctor or accredited mental health worker examines the person and completes a form (often called a "Schedule 1" / "Form 1"). The person then goes to a declared mental health facility, where at least two doctors, one of them a psychiatrist, must independently agree that detention is necessary before it can happen. If the second doctor disagrees, that's meant to end it.
                """)
                .font(.subheadline)
            }

            Group {
                Text("Your rights if it happens").font(.headline)
                Text("""
                You're legally entitled to be told, in plain language you can understand, what's happening and why, and given a written statement of your rights, including the right to have the decision reviewed.
                """)
                .font(.subheadline)
            }
        }
        .navigationTitle("Hospitalisation")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ConfidentialityReferenceView: View {
    var body: some View {
        ReferencePage(sources: "NSW Health Records and Information Privacy Act 2002, general principles · Mental Health Act 2007 (NSW) · APS/AHPRA general guidance on limits of confidentiality") {
            Group {
                Text("The general rule").font(.headline)
                Text("""
                What you tell a psychologist or psychiatrist is confidential and protected under NSW health-privacy law. Clinicians are trained to keep it that way. It's a professional and legal obligation, not just a courtesy.
                """)
                .font(.subheadline)
            }

            Group {
                Text("When it has limits").font(.headline)
                Text("""
                Confidentiality generally has narrow exceptions, commonly: if a clinician believes there's a serious and imminent risk to your life or someone else's, if they're required to report certain things by law (like some situations involving a child's safety), or if a court specifically orders disclosure.

                These exceptions exist for imminent, serious risk. They don't apply just for having suicidal thoughts, describing pain, or being honest about a hard time. A good clinician distinguishes between "this person is struggling and reflective" and "this person may act imminently," and the second one is the actual trigger, not the first.
                """)
                .font(.subheadline)
            }

            Group {
                Text("What you can ask directly").font(.headline)
                Text("""
                You're allowed to ask your psych, plainly, before disclosing something: "What exactly would and wouldn't stay between us?" A clinician should be able to answer that clearly. If they can't, that's useful information too.
                """)
                .font(.subheadline)
                .padding()
                .background(Anchor.Theme.sageSoft, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .navigationTitle("Confidentiality")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TalkingToYourPsychReferenceView: View {
    var body: some View {
        ReferencePage(sources: "Mental Health Act 2007 (NSW) · MHCC Mental Health Rights Manual, Chapter 4 (mhrm.mhcc.org.au)") {
            Group {
                Text("On withholding things out of fear").font(.headline)
                Text("""
                Withholding things out of fear of the hospitalisation process is a common instinct, but it means your psych is working with an incomplete picture, and the actual criteria (see Hospitalisation) are specific and a higher bar than "I told them I'm struggling."
                """)
                .font(.subheadline)
            }

            Group {
                Text("A reasonable thing to say directly").font(.headline)
                Text("""
                If the fear itself is the main thing in the way, that's worth naming to your psych directly, in these words or your own: "I'm scared to tell you something because I'm not sure what happens next." You can ask them plainly what would and wouldn't trigger anything, before deciding what else to share.
                """)
                .font(.subheadline)
                .padding()
                .background(Anchor.Theme.sageSoft, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .navigationTitle("Talking to your psych")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#endif // PERSONAL_BUILD
