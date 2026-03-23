# hdict User Manual

Welcome to **hdict**, your powerful, customizable dictionary reader! This guide will help you get the most out of the app.

---

## 🔍 1. Searching Like a Pro

To search for a word, simply type it into the top search bar. The app searches your dictionaries instantly.

*   **Wildcards**: Use these when you are unsure of the spelling:
    *   `*` (Asterisk): Matches any number of characters. Example: `app*` will find "apple", "apply", and "application".
    *   `?` (Question Mark): Matches exactly one character. Example: `a?ple` will find "apple".

---

## 📚 2. Importing & Downloading Dictionaries

**hdict** is a "shell" app—it doesn't come pre-loaded with any dictionaries, but it can read almost any dictionary format you find online. All methods support automatic **deduplication** via MD5 checksums.

#### 1. Select by Language (Recommended)
The easiest way! Browse over 1,800 high-quality FreeDict dictionaries by language pairs directly in the app.
1. Go to **Manage Dictionaries** > **Select by Language**.
2. Tap the **Download** icon next to a dictionary (e.g., *English-Hindi*).
3. It will be automatically downloaded, extracted, and grouped by its languages.

#### 2. Add Folder
Perfect for bulk importing entire collections from your device.
1. Tap **Add Folder** in the dictionary management menu.
2. Select a directory containing dictionary files.
3. The app recursively scans for all supported formats and groups them under the folder's name.

#### 3. Import File
Use this for single dictionary files or compressed archives.
1. Tap **Import File** and pick a file or archive (`.zip`, `.7z`, `.tar.xz`, etc.).
2. **Mandatory Files per format**:
    *   **StarDict**: Select `.dict/.dict.dz`, `.ifo`, and `.idx` files. Optionally `.syn`.
    *   **MDict**: Select `.mdx` file. Optional `.mdd` for media.
    *   **Slob**: Select a single `.slob` file.
    *   **DICTD**: Select `.dict/.dict.dz` and `.index` files.

#### 4. Download Web
If you have a direct link to a dictionary file or archive:
1. Tap **Download Web**.
2. Paste the URL. The app will download, extract, and index it automatically.

### Supported Compression Formats
The app supports: `.zip`, `.7z`, `.tar.gz`, `.tar.bz2`, `.tar.xz`, and `.bz2`.

---

## 📂 3. Dictionary Groups
To help you manage hundreds of dictionaries, `hdict` uses a smart **Grouping** system:

*   **Automatic Groups**: When you use "Add Folder", dictionaries are automatically grouped by the folder name. Dictionaries downloaded via "Select by Language" are grouped by their language pair.
*   **Toggle Groups**: In the main search view, use the **Filter icon** to quickly enable or disable entire groups of dictionaries.
*   **Storage Efficiency**: The app uses MD5 checksums to prevent duplicate storage. If the same dictionary exists in multiple folders/groups, only one physical copy is stored.

---

## 🔎 4. Deep Search (Inside Definitions)

By default, the app looks for "Headwords" (the main titles of entries). However, you can enable **"Index words in definitions"** during import, or subsequently by pressing 'Reindex' button in 'Manage Dictionaries' folder. It is available by clicking triple dots besides the dictionary name.

*   **What it does**: It reads every single word inside every definition and maps it.
*   **Example**: If you search for "astronomy", a normal search finds the entry for "Astronomy". A **Deep Search** will also find "Telescope" or "Galaxy" because they mention "astronomy" in their descriptions.
*   **Note**: This makes the import process take longer and uses more storage space, but it provides much more powerful search results.

---

## 🎓 5. Flash Cards & Learning

Turn your dictionaries into a study tool!

*   **Starting a Session**: Go to "Flash Cards" in the menu. Choose how many random words you want to be tested on (from 5 to 50).
*   **Dictionaries**: Pick which dictionaries the app should pull words from.
*   **Sneak Peek**: If you can't remember a word, tap **"Peek"** for the meaning.
*   **Score History**: Track your progress over time. Every session result is saved with details of which words you got right or wrong.

---

## ⚙️ 6. Customizing Your Experience

Head over to **Settings** to make the app your own:

### Search Settings
*   **Search Modes**: Set whether your search should match the start of the word (**Prefix**), the end (**Suffix**), the internal (**Substring**) or the **Exact** word.

### Appearance
*   **Theme**: Pick from several vibrant colors.
*   **Typography**: Change the font family and adjust the font size so definitions are perfectly readable for you.

### Dictionary Interaction
*   **Tap-on-Meaning**: See a word inside a definition that you don't know? Just **tap it**! A popup will appear showing its meaning without leaving your current page. If you want to show the tapped words in full screen rather than a pop-up, you can change the preference in 'Settings' menu.

---

## 🛠️ 7. Managing Your Library

In **Manage Dictionaries**, you have full control:

*   **Reorder Priority**: Drag dictionaries up or down. If multiple dictionaries have the same word, the one at the top will be shown first.
*   **Re-indexing**: If a dictionary seems to have missing words, use the "Re-index" tool to rebuild its word list.
