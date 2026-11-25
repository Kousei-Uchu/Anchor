# The safety plan

The safety plan is a list of sections you own. Each section is a card with a title, a subtitle (optional), your own words, an
icon and a colour. Sections can be renamed, reordered, hidden (they keep their words) and deleted. One section can be marked as
the source of reminder quotes.

## Subheadings and nesting (Patch SP1)

- A section can sit under another one (`parentID`, a link to the other section and nothing else). It then shows inside that
  section's card as a subheading, with its own icon, subtitle and words. A subheading can have subheadings of its own, down to a
  sub-subheading (three levels in all).
- Add one by pressing and holding a card and choosing **Add a subheading**, or open any section and choose where it **Sits under**.
  A section cannot sit under itself or under anything that sits under it.
- Each heading and subheading has an optional **subtitle**, a line under its title (`subtitle`, locked like the title).
- Hiding a section hides what sits under it. Deleting a section deletes what sits under it, and the delete question says so.
- A section whose parent has been deleted shows as a card of its own.
- There are more icons to choose from (the set is fixed, so the icon name is still not content).

## Items, notes and entry formats (Patch SP2)

- A section can hold a list of **items**. Each has a title, an optional **note**, and an answer for each field of the section's entry format. Items show on the card as a bulleted list under the section's words, with each answer on its own line ("Phone: 0400 000 000") and the note under that.
- The **entry format** is the set of fields every item in that section has, which you name yourself (a name, a phone number, when to use it, and so on). **Start from a ready-made format** fills it in for a person, a place, something to do, or a medicine; all of it can be changed. Each field has its own id, so renaming a field keeps the answers already written under it, and deleting a field leaves the old answers stored but unseen.
- Open a section to edit its items. Swipe to delete, **Edit** to put them in order. An empty entry format means plain items.
- Items and fields are kept inside the section as coded lists (the way a goal keeps its notes), locked like the section's words, and carried in exports (older exports still import).
- Nothing is counted or scored: no number of items shown as progress.

## Kinds and links (Patch SP3)

- A section is one of five **kinds** (`kindRaw`, locked): **Words** (just your own writing, the default), **A list**, **People**, **Grounding tools** or **Goals**. The kind decides what the editor offers: a list gets the entry format and an Add an item button; People, Grounding tools and Goals get an add menu of the ones you already have in Anchor (leaving out any already in the section). Changing the kind never deletes anything, and a Words section that already has items keeps showing them.
- An item can carry a **link** (`SafetyPlanItem.link`, a short piece of text). Inside Anchor: a **person** (shows the name and number, tap to call), a **grounding tool** (tap to run it, or to open its link), or a **goal** (shows the title and why, tap to open the goals screen). Outside Anchor: a **website** (https or http only) or a **phone number**, typed on the item. A person, tool or goal is looked up each time the card is shown, so it is always the current name and number. If it has been deleted the item says so and nothing else breaks.
- Tapping a linked item follows the link. Tapping an unlinked item, or the heading and words, opens the editor.
- Nothing about a link leaves the phone except the call or web page the person chooses to open.

## Sharing the safety plan on its own (Patch SP4)

- The share button at the top of the safety plan opens **Share your safety plan**. It holds only the safety plan: nothing else from Anchor, and nothing from the rest of your data.
- You choose what goes in: **phone numbers and web addresses** (on by default) and **notes on items** (on by default). Sections you have hidden are never included, and neither is anything under a hidden section.
- It shows the plan as it will read, then offers **Share as text** (through the share sheet) and **Share as a PDF** (A4, as many pages as it needs, written to a temporary file and handed to the share sheet).
- A linked person, grounding tool or goal is written with its current name. A person's number is a contact detail; the reason you wrote for a goal is too.
- Nothing is made until a share button is pressed, and nothing is sent anywhere by Anchor: the share sheet is the phone's own.

This finishes the safety plan upgrades from the notes list (#3).
