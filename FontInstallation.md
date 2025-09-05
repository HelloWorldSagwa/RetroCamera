# Installing DSEG 7-Segment Font

To get the authentic 7-segment LCD date stamp effect (like old film cameras from the 80s/90s), follow these steps:

## 1. Font File
The DSEG7Classic-Bold.ttf font file has been downloaded and placed in the RetroCamera folder.

## 2. Add to Xcode Project
1. Open the RetroCamera project in Xcode
2. Right-click on the RetroCamera folder in the project navigator
3. Select "Add Files to RetroCamera..."
4. Select `DSEG7Classic-Bold.ttf`
5. Make sure "Copy items if needed" is checked
6. Make sure "Add to targets: RetroCamera" is checked
7. Click "Add"

## 3. Register Font in Info.plist
1. Select the project in the navigator
2. Select the RetroCamera target
3. Go to the "Info" tab
4. Add a new entry: "Fonts provided by application"
5. Add item: `DSEG7Classic-Bold.ttf`

## Alternative Method (via Build Settings)
1. Select the project
2. Go to Build Phases
3. Expand "Copy Bundle Resources"
4. Click + and add `DSEG7Classic-Bold.ttf`

## 4. Verify Font Installation
The code will automatically use DSEG7Classic-Bold if available, otherwise it falls back to the system monospaced font.

## About DSEG Font
- DSEG is a free font that mimics 7-segment and 14-segment displays
- Perfect for recreating the vintage LCD date stamps from old film cameras
- Licensed under SIL Open Font License 1.1
- More info: https://www.keshikan.net/fonts-e.html