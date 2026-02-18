# hdict

A high-performance, feature-rich dictionary application built with Flutter. Optimized for speed, highly customizable, and designed for a premium user experience across all platforms.

**Dedicated to Hiral.**

---

## ✨ Key Features

### 🔍 Advanced Search
- **Multi-Dictionary Search**: Display results from multiple dictionaries simultaneously in a tabbed interface.
- **Fast Lookups**: Optimized database queries for near-instant results.
- **Definition Previews**: See a snippet of the definition directly in the search suggestions.
- **Fuzzy Search**: Typo-tolerant matching to find words even with spelling errors.
- **Tab Management**: Easily close individual dictionary results to clean up your workspace.

### 📖 Universal Word Lookup
- **Tap-on-Meaning**: Every word in a definition is interactive. Tap any word to instantly look it up.
- **Language Agnostic**: Built with Unicode support to work seamlessly with English, Vietnamese, and other languages.
- **Nested Lookups**: Lookup results open in a full-width bottom popup, allowing you to explore meanings without losing your place.

### 🗂️ Flash Cards & Learning
- **Truly Random Quizzes**: Pull 10 random words from your selected dictionaries using unbiased randomization.
- **Adjustable Results**: Changed your mind about a "guess"? Mark words as correct or incorrect during the review phase.
- **Score History**: Track your progress over time with a dedicated session history view.

### 🎨 Deep Customization
- **Modern Aesthetics**: Rich, premium design with micro-animations and smooth transitions.
- **Custom Theme**: Separately set colors for the background, headings, and body text using a full RGB picker.
- **Typography**: Choose from curated Google Fonts (Inter, Roboto, Open Sans, etc.) and adjust font sizes globally.
- **History Retention**: Automatically clean up your search history after a set number of days.

---

## 🚀 Quickstart

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Stable channel recommended)
- Android Studio / VS Code with Flutter extension

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/hdict.git
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

### Importing Dictionaries
`hdict` supports StarDict dictionary files (provided as `.zip` or `.tar.gz`). 
1. Open the **Manage Dictionaries** menu in the sidebar.
2. Tap the **+** (Add) button.
3. Select your dictionary archive file to import it into the local database.

---

## 🛠️ Build Commands

Build for your platform of choice:

| Platform | Command | Notes |
| :--- | :--- | :--- |
| **Linux** | `flutter build linux` | Output in `build/linux/x64/release/bundle/` |
| **Android** | `flutter build apk` | Output in `build/app/outputs/flutter-apk/` |
| **Windows** | `flutter build windows` | Requires Windows host + Visual Studio |
| **Web** | `flutter build web` | Output in `build/web/` |
| **iOS** | `flutter build ios` | Requires macOS host + Xcode |

---

## 👨‍💻 Contributing
Found a bug or have a feature request? Feel free to open an issue or submit a pull request!

## 📜 License
This project is licensed under the MIT License - see the LICENSE file for details.
