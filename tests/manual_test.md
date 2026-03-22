# Manual Test Plan - hdict

Testing is everything. This document lists manual tests that ensure the visual look and feel, platform-specific behaviors, and complex app actions are working correctly.

## 1. Visual Look and Feel

### 1.1 Themes and Dark Mode
- [ ] Toggle Dark Mode in Settings. Verify all screens (Home, Dictionary Management, Flash Cards, About) respect the theme.
- [ ] Change Headword Color in Settings. Verify the search results and meaning popups use the new color.
- [ ] Change Background Color in Settings. Verify it applies to the meaning display area.
- [ ] Change Font Family and Font Size. Verify readability and layout consistency.

### 1.2 Meaning Rendering
- [ ] Verify that StarDict, MDict, and Slob definitions render correctly with proper formatting (bold, italics, lists).
- [ ] Tap on a word within a definition. Verify that a popup appears with the tapped word's definition.
- [ ] Verify that images (if any) in MDict are displayed correctly.

## 2. Dictionary Management

### 2.1 Importing
- [ ] Import a StarDict dictionary (.zip or .7z). Verify progress bar and final word counts.
- [ ] Import an MDict dictionary (.mdx).
- [ ] Import a Slob dictionary (.slob).
- [ ] Import a `.tar.xz` dictionary archive. Verify extraction works correctly.
- [ ] **Checksum Check**: Import an already existing dictionary via "Import File". Verify the system identifies it as "Already Exists" and does not create a duplicate.
- [ ] **Folder Deduplication**: "Add Folder" containing dictionaries already imported via "Import File". Verify they are skipped correctly.
- [ ] Verify that incomplete dictionaries (missing .idx or .dict) show detailed error messages in the "Incomplete" section.

### 2.2 Reordering and Enabling
- [ ] Reorder dictionaries by dragging. Verify that search results follow the new order.
- [ ] **Multi-Group Membership**: Assign a dictionary to Group A and Group B. Enable Group A and Disable Group B. Verify dictionary remains searchable.
- [ ] **Automatic Folder Grouping**: Use "Add Folder" on a directory named "MyDicts". Verify a group "MyDicts" is created and dictionaries are assigned to it.
- [ ] Disable a dictionary. Verify it no longer appears in search results.
- [ ] Delete a dictionary that is a member of multiple groups. Verify it is removed from the database and all group lists.

## 3. Platform Specific Actions

### 3.1 Android (Storage Access Framework)
- [ ] Use "Link External Folder" on Android. Select a folder with dictionaries and verify they are indexed without being copied to app storage.
- [ ] Verify that "Delete" on a linked dictionary only removes the index, not the source file.

### 3.2 iOS/macOS (Security Scoped Bookmarks)
- [ ] Use "Link External Folder". Verify that dictionaries in the linked folder remain accessible even after app restart (uses Bookmarks).

## 4. Flash Cards

### 4.1 Quiz Flow
- [ ] Start a quiz session. Verify that the "Check Meaning" button reveals a snippet correctly.
- [ ] Mark a card as Correct (green check) or Incorrect (red X).
- [ ] Peek multiple times and verify the "Sneak Peeks" count on the Result screen.
- [ ] Complete the quiz and view the Result Screen. Verify colors and labels based on score.
- [ ] Use "Review Meanings" to see the full definitions of words used in the session.

### 4.2 Score History
- [ ] Verify that completed quiz scores are saved in the "Score History" screen.

## 5. Edge Cases
- [ ] Search for a non-existent word. Verify "No results found" message.
- [ ] Close the app during a large dictionary import. Verify that re-opening the app handles the partial index gracefully or allows re-indexing.
- [ ] Rotate the device (if mobile). Verify layout responsiveness on Home and Dictionary Management screens.
