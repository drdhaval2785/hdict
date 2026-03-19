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
- **Lightning Fast Lookup**: Powered by optimized queries using SQLite FTS5, batch processing, and database vacuuming to ensure near-instant results and minimal storage usage.

### 📖 Universal Word Lookup & Native Tap-to-Search
- **Tap-on-Meaning**: Every word in a definition is interactive using native hit-testing (without character limits). Tap any word to instantly look it up.
- **Desktop Ready**: Hover hand cursors for clickable definition texts on macOS, Linux, and Windows.
- **Language Agnostic**: Built with Unicode support to work seamlessly with English, Vietnamese, and other languages.
- **Nested Lookups**: Lookup results open in a full-width bottom popup, allowing you to explore meanings without losing your place.

### 📚 Massive Dictionary Support & Web Import
- **Select Dictionaries by Language**: Browse and download from around 1900 FreeDict dictionaries organized by origin and target languages directly within the app.
- **Extensive Format Support**: Read from **StarDict**, **MDict** (`.mdx`, `.mdd`), **Slob** (`.slob`), and **DICTD** formats.
- **Archive Extracting**: Native ingestion of dictionaries compressed in `.zip`, `.tar.gz`, `.tar.xz`, `.bz2`, and `.7z` formats. Support for importing entire folders of dictionaries at once.
- **Manage Dictionaries**: Delete, update, securely clean orphaned data and prioritize dictionaries via standard display ordering.

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

### Importing Dictionaries
`hdict` supports multiple dictionary formats including StarDict, MDict, Slob, and DICTD.

1. Open the **Manage Dictionaries** menu in the sidebar.
2. Choose **Select by Language** to instantly browse and download 1900+ dictionaries.
3. Alternatively, tap the **Import File**, **Import Folder**, or **Download from Web** button.
4. Select your `.slob`, `.mdx`, `.zip`, `.7z` etc. dictionary files or folders to parse entirely offline into the local database.

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
