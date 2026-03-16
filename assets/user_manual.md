# hdict User Manual

Welcome to **hdict**, your powerful, customizable dictionary reader! This guide will help you get the most out of the app.

---

## 🔍 1. Searching Like a Pro

To search for a word, simply type it into the top search bar. The app searches your dictionaries instantly.

*   **Wildcards**: Use these when you are unsure of the spelling:
    *   `*` (Asterisk): Matches any number of characters. Example: `app*` will find "apple", "apply", and "application".
    *   `?` (Question Mark): Matches exactly one character. Example: `a?ple` will find "apple".
*   **Search History**: All your searches are saved. Tap the 📜 icon in the menu to revisit them.

---

## 📚 2. Importing & Downloading Dictionaries

**hdict** is a "shell" app—it doesn't come with many dictionaries, but it can read almost any format you find online.

*   **Import File**: Use this for a single dictionary file or a compressed archive.
*   **Import Folder**: Point the app to a folder on your device. It will scan every sub-folder and automatically detect valid dictionaries.
*   **Download from Web**: If you have a direct link (e.g., `http://example.com/french.zip`), paste it here to download and install directly.
*   **Select by Language**: The easiest way! Browse over 1,900 high-quality dictionaries by language pairs and tap to download.

### Supported Compression Formats
The app can automatically open:
*   `.zip`
*   `.7z`
*   `.tar.gz` / `.tgz`
*   `.tar.bz2` / `.tbz2`
*   `.tar.xz` / `.txz`

### Mandatory Files per Format
If you are importing manually, ensure you have these files:
*   **StarDict**: Requires `.ifo` (info), `.idx` (index), and `.dict` (data).
*   **MDict**: Requires `.mdx` (data). Optional `.mdd` for images and sounds.
*   **Slob**: A single `.slob` file is enough.
*   **DICTD**: Requires `.index` and `.dict.dz`.

---

## 🔎 3. Deep Search (Inside Definitions)

By default, the app looks for "Headwords" (the main titles of entries). However, you can enable **"Index words in definitions"** during import.

*   **What it does**: It reads every single word inside every definition and maps it.
*   **Example**: If you search for "astronomy", a normal search finds the entry for "Astronomy". A **Deep Search** will also find "Telescope" or "Galaxy" because they mention "astronomy" in their descriptions.
*   **Note**: This makes the import process take longer and uses more storage space, but it provides much more powerful search results.

---

## 🎓 4. Flash Cards & Learning

Turn your dictionaries into a study tool!

*   **Starting a Session**: Go to "Flash Cards" in the menu. Choose how many random words you want to be tested on (from 5 to 50).
*   **Dictionaries**: Pick which dictionaries the app should pull words from.
*   **Sneak Peek**: If you can't remember a word, tap **"Peek"** for a hint before revealing the full answer.
*   **Score History**: Track your progress over time. Every session result is saved with details of which words you got right or wrong.

---

## ⚙️ 5. Customizing Your Experience

Head over to **Settings** to make the app your own:

### Search Settings
*   **Fuzzy Search**: When enabled, if you type "aple", the app will still suggest "apple".
*   **Search Modes**: Set whether your search should match the start of the word (**Prefix**), the end (**Suffix**), or the **Exact** word.

### Appearance
*   **Theme & Dark Mode**: Pick from several vibrant colors and toggle Dark Mode to reduce eye strain.
*   **Typography**: Change the font family and adjust the font size so definitions are perfectly readable for you.

### Dictionary Interaction
*   **Tap-on-Meaning**: See a word inside a definition that you don't know? Just **tap it**! A popup will appear showing its meaning without leaving your current page.

---

## 🛠️ 6. Managing Your Library

In **Manage Dictionaries**, you have full control:

*   **Reorder Priority**: Drag dictionaries up or down. If multiple dictionaries have the same word, the one at the top will be shown first.
*   **Re-indexing**: If a dictionary seems to have missing words, use the "Re-index" tool to rebuild its word list.
*   **Space Cleanup**: If you delete a dictionary, use the **"Orphan Cleanup"** tool (in the side menu) to ensure no leftover files are wasting space.
