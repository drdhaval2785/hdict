# hdict

<p align="left">
  <a href="https://apps.apple.com/in/app/hdict/id6759493062">
    <img src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=250x83&amp;releaseDate=1719878400" alt="Download on the App Store" height="40">
  </a>
  <a href="https://snapcraft.io/hdict">
    <img src="https://snapcraft.io/static/images/badges/en/snap-store-black.svg" alt="Get it from the Snap Store" height="40">
  </a>
</p>

A high-performance, feature-rich dictionary application built with Flutter. Optimized for speed, highly customizable, and designed for a premium user experience across all platforms.

**Dedicated to Hiral.**

---

## ✨ Key Features

### 🔍 Advanced & Fast Search
- **Multi-Dictionary Search**: Display results from multiple dictionaries simultaneously in a tabbed interface.
- **Wildcard & Prefix Search**: Supports wildcard operators like `*` and `?` as well as prefix search for powerful lookups.
- **Definition Search**: Dive deeper by searching for words directly within definitions.
- **Lightning Fast Lookup**: Powered by optimized queries using SQLite FTS5, batch processing, and database vacuuming to ensure near-instant results.
- **Deduplication**: Automatically detects and skips duplicate dictionaries using MD5 checksums during "Import File" or "Add Folder" workflows.

### 📖 Universal Word Lookup & Native Tap-to-Search
- **Tap-on-Meaning**: Every word in a definition is interactive using native hit-testing (without character limits). Tap any word to instantly look it up.
- **Language Agnostic**: Built with Unicode support to work seamlessly with English, Hindi, Vietnamese, or any other languages.
- **Nested Lookups**: Lookup results open in a full-width bottom popup, allowing you to explore meanings without losing your place.

### 📚 Massive Dictionary Support & Web Import
- **Select Dictionaries by Language**: Browse and download from around 1800 FreeDict dictionaries organized by origin and target languages directly within the app.
- **Extensive Format Support**: Read from **StarDict** (`.dict/.dict.dz`, `.idx`, `.ifo` and optionally `.syn`), **MDict** (`.mdx`, `.mdd`), **Slob** (`.slob`), and **DICTD** (`.dict/.dict.dz`, `.index`) formats.
- **Archive Extracting**: Native ingestion of dictionaries compressed in `.zip`, `.tar.gz`, `.tar.xz`, `.bz2`, and `.7z` formats. Support for importing entire folders of dictionaries at once via the unified **Add Folder** action.
- **Smart Grouping**: Dictionaries can now belong to multiple groups. When using "Add Folder", dictionaries are automatically assigned to a group named after the source folder (if added by 'Add Folder') or Language pair (if downloaded from 'Select by Language').
- **Manage Dictionaries**: Delete, update, and prioritize dictionaries via standard display ordering.

### 🗂️ Flash Cards & Learning
- **Truly Random Quizzes**: Pull random words from your selected dictionaries for rapid learning.
- **Adjustable Results**: Changed your mind about a "guess"? Mark words as correct or incorrect during the review phase dynamically.
- **Score History & One-page Summaries**: Track your progress over time with a dedicated session history view and comprehensive single-view result screens.
- **Sneak Peek Feature**: Glance at meanings during the Flash Card learning phase to jog your memory.

### 🎨 Deep Customization
- **Modern Aesthetics**: Rich, premium design with dynamic light/dark mode support, micro-animations, and smooth transitions.
- **Custom Theme**: Separately set colors for the background, headings, and body text using a full RGB picker.
- **Typography & UI**: Choose from curated Google Fonts, adjust font sizes globally, and enjoy reliable boundary padding for seamless interaction on mobile devices.
- **History Retention**: Automatically clean up your search history after a set number of days.

### 📥 Importing Dictionaries
`hdict` offers four ways to build your local library. All methods support automatic deduplication via MD5 checksums.

#### 1. Select by Language (Recommended)
The easiest way to get started with high-quality, open-source dictionaries.
1. Open the **Sidebar** and navigate to **Manage Dictionaries**.
2. Tap **Select by Language**.
3. Browse the list (e.g., *English-Hindi*, *French-English*).
4. Tap the **Download** icon next to your choice.
- **Example**: Selecting `English-German` will download a `.tar.gz` or `.zip` or similar file from upstream resource and automatically index it into the `English-German` group.

#### 2. Add Folder
Perfect for bulk importing large existing collections or entire StarDict/MDict directories.
1. Tap **Add Folder** in the dictionary management menu.
2. Select a directory containing dictionary files (and their subfolders).
3. The app will recursively scan for all supported formats.
- **Example**: Selecting a folder `Downloads/MyDicts/` containing 50 `.mdx` and `.dict.dz` files will import them all in one go and group them under `MyDicts`.

#### 3. Import File
Use this for single dictionary files or compressed archives (`.zip`, `.7z`, `.tar.xz`, etc.).
1. Tap **Import File**.
2. Pick a single dictionary file or a supported archive.
3. Archives will be extracted and indexed automatically.
- **Example**: Importing `Oxford_Advanced.zip` will extract the `.mdx` files inside and add the dictionary to your library.
- **Note**: Importing StarDict dictionary would require selecting `.dict/.dict.dz, .ifo and .idx` files mandatorily and   `.syn` file optionally. 
Importing Dictd dictionary would require selecting `.dict/.dict.dz, .index` files mandatorily. 
Importing MDict dictionary would require selecting `.mdx` file mandatorily. 
Importing Slob dictionary would require selecting `.slob` file  mandatorily. 

#### 4. Download Web
Import a dictionary directly from a direct download link.
1. Tap **Download Web**.
2. Paste the URL of the dictionary file or archive.
3. The app will download, extract (if needed), and index the content.
- **Example**: Paste `https://example.com/medical_dict.stardict.zip` to download and import a medical dictionary directly into the app.

### 📂 Dictionary Groups
`hdict` automatically organizes your library into **Groups** for easier management and cleaner search results.

- **Automatic Grouping**:
    - **Add Folder**: Multi-imports are grouped by the **parent folder name** (e.g., `Downloads/En-Hi/` becomes the "En-Hi" group).
    - **Select by Language**: Automatically grouped by the **language pair** (e.g., "English-Hindi").
- **Smart Filtering**: Use the **Search Filter** (funnel icon) to toggle entire groups ON or OFF globally.
- **Deduplication**: If you import the same dictionary into different groups (e.g., once individually and once as part of a folder), `hdict` uses MD5 checksums to ensure only one master copy exists, saving storage space.

---

## 🚀 Developers' Corner

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Stable channel recommended)
- Android Studio / VS Code with Flutter extension
- Xcode (for macOS and iOS targets)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/drdhaval2785/hdict.git
   cd hdict
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   # Run on your default connected device
   flutter run
   ```

---

### 🛠️ Build Commands

Build for your platform of choice:

| Platform | Command | Notes |
| :--- | :--- | :--- |
| **macOS** | `flutter build macos` | Requires macOS host + Xcode |
| **Linux** | `flutter build linux` | Output in `build/linux/x64/release/bundle/` |
| **Android** | `flutter build apk` | Output in `build/app/outputs/flutter-apk/` |
| **Windows** | `flutter build windows` | Requires Windows host + Visual Studio |
| **Web** | `flutter build web` | Output in `build/web/` |
| **iOS** | `flutter build ios` | Requires macOS host + Xcode |

---

## 👨‍💻 Contributing
Found a bug or have a feature request? Feel free to open an issue or submit a pull request!

## 📜 License
This project is licensed under the GNU General Public License v3.0 (GPL v3.0) - see the LICENSE file for details.
