# Export for someone

Bridge has a share button that opens Export for someone. The person writes who it is for and an optional note, chooses what goes in (by kind, by date range and by individual item) and sees a count and a preview before anything is made. It is built on the phone and handed to the system share sheet. Nothing is uploaded.

## Formats
- **PDF.** Plain pages: the name, the note, then each kind in turn.
- **Web page (.html).** One file with the document inside it and a small viewer: search, By section and Timeline, a line chart for each of the four check-in values, a print stylesheet (Print or save as PDF) and a Download CSV button. It reads fine as a document and needs no internet.
- **Word (.docx).** Added with Patch 38.

## How the web page is kept safe
- **No network.** A content security policy in the page sets `default-src 'none'` and allows the one script by its SHA-256 hash, so nothing else can run and nothing can be fetched or posted.
- **Written text is never run.** Everything is drawn with `textContent`, and `<` is escaped inside the data block, so text such as `<script>` shows as text.
- **CSV cells** that start with `=`, `+`, `-`, `@` or a tab get a leading apostrophe so a spreadsheet will not run them as formulas.
- **Password (optional, 8 or more characters).** The document is encrypted with AES-256-GCM. The key comes from PBKDF2 with SHA-256, a random 16-byte salt and 600,000 rounds, from the password in Unicode NFC. The file holds the salt, the nonce and the ciphertext with its tag after it, and the browser decrypts with WebCrypto. Anchor does not keep the password, so there is no way to get it back. A wrong password fails the integrity check and shows an error.

## Known limits
- Browsers only offer WebCrypto on a secure page. A local file counts as one in Safari, Chrome and Firefox, but a mail or file preview that does not run scripts will show only the "needs JavaScript" line. Say so when sending, and send the PDF too.
- Some mail apps block .html attachments.
- A lost password cannot be recovered.
- It is a viewer for reading. It cannot be edited and does not import back into Anchor.

## To check on real devices
- [ ] Open the file from Mail, Files and AirDrop on an iPhone, and on a Mac in Safari and Chrome.
- [ ] Locked page: right password opens it, wrong one does not, and a long password with accents works.
- [ ] Search, Timeline, charts, Print to PDF and Download CSV (Safari on iPhone saves it through Files).
- [ ] Dark mode, large text, and a 1,000-entry journal.
