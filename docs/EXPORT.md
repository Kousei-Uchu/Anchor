# Export for someone

Bridge has a share button that opens Export for someone. The person writes who it is for and an optional note, chooses what goes in (by kind, by date range and by individual item) and sees a count and a preview before anything is made. It is built on the phone and handed to the system share sheet. Nothing is uploaded.

## Formats
- **PDF.** Plain pages: the name, the note, then each kind in turn. When Sleep is included and two nights have a time asleep, a plain line of time asleep sits above the nights, from 0 h to the next whole hour above the longest night, with no target line.
- **One-page PDF (30r).** The same document laid out on a single US Letter page: the name, the note, then each kind in turn, with no charts. The print starts at 11 points and goes down to 8.5 to fit. Nothing is cut: if it still would not fit, the button is off, the screen says about how many pages it needs, and nothing is made. The full PDF has no limit. Session prep makes its own one-page sheet the same way, from the cards on that screen, with what you wrote on to begin with and the looking back off.
- **Web page (.html).** One file with the document inside it and a small viewer: search, By section and Timeline, a line chart for each of the five check-in values (Energy, Clarity, Room in head, Moving, Social energy) (and one for time asleep, if Sleep is included, with no target line), a print stylesheet (Print or save as PDF) and Download CSV and Download Word file buttons. It reads fine as a document and needs no internet.
- **Word (.docx).** Made inside the web page by its Download Word file button, named like the page. It holds the title, the note, then each kind with its count and each entry as its date, heading, lines and footnote. It is plain text with headings: no charts or photos. It is the whole document, not just what the search box is showing. The page size is A4, or US Letter when the browser's language ends in US, CA, MX or PH. A locked page has to be unlocked first. There is no document library in the page: the page writes the .docx itself as a zip with the files stored uncompressed, so the file is about the size of the text.

## How the web page is kept safe
- **No network.** A content security policy in the page sets `default-src 'none'` and allows the one script by its SHA-256 hash, so nothing else can run and nothing can be fetched or posted.
- **Written text is never run.** Everything is drawn with `textContent`, and `<` is escaped inside the data block, so text such as `<script>` shows as text.
- **Word text** is written into the file as escaped text, so something like `<script>` shows as words, and control characters Word cannot hold are dropped.
- **CSV columns.** Download CSV has section, date, heading, text and note, then in_bed, up and minutes_asleep (filled only for sleep nights). The older CSV under Your data has type, date and text_or_values, then bed_time, wake_time, minutes_asleep and feel, filled only on sleep rows.
- **CSV cells** that start with `=`, `+`, `-`, `@` or a tab get a leading apostrophe so a spreadsheet will not run them as formulas.
- **Password (optional, 8 or more characters).** The document is encrypted with AES-256-GCM. The key comes from PBKDF2 with SHA-256, a random 16-byte salt and 600,000 rounds, from the password in Unicode NFC. The file holds the salt, the nonce and the ciphertext with its tag after it, and the browser decrypts with WebCrypto. Anchor does not keep the password, so there is no way to get it back. A wrong password fails the integrity check and shows an error.

## Known limits
- Browsers only offer WebCrypto on a secure page. A local file counts as one in Safari, Chrome and Firefox, but a mail or file preview that does not run scripts will show only the "needs JavaScript" line. Say so when sending, and send the PDF too.
- Some mail apps block .html attachments.
- A lost password cannot be recovered.
- The Word file is made in the browser, so it needs the same script support as the page itself. If a download button does nothing, open the page in Safari, Chrome or Firefox, or send the PDF.
- It is a viewer for reading. It cannot be edited and does not import back into Anchor.

## To check on real devices
- [ ] Open the file from Mail, Files and AirDrop on an iPhone, and on a Mac in Safari and Chrome.
- [ ] Locked page: right password opens it, wrong one does not, and a long password with accents works.
- [ ] Search, Timeline, charts, Print to PDF and Download CSV (Safari on iPhone saves it through Files).
- [ ] One-page PDF: with a few things switched on it makes a page you can read at its size; with a long journal range switched on it is off and says how long it would be. Open the PDF and check no line is cut off at the bottom or the sides, then do the same from Session prep.
- [ ] Download Word file: open the result in Word, and in Pages or Word on iPhone. Check the title, note, headings, line breaks inside an entry and the page size. Safari on iPhone should offer to save it through Files.
- [ ] A page with a password: unlock it, then Download Word file.
- [ ] Dark mode, large text, and a 1,000-entry journal.
