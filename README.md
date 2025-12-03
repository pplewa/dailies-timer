# Dailies Timer

A beautiful iOS timer app for tracking your daily activities with count-up timers, lock screen widgets, and Google Sheets sync.

![iOS 17+](https://img.shields.io/badge/iOS-17%2B-blue)
![Swift 5](https://img.shields.io/badge/Swift-5-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-4-green)

## Features

### ⏱️ Timer Management
- **Count-up timers** - Start at 00:00 and count up indefinitely
- **Reference durations** - Optional target times for visual progress tracking
- **Single active timer** - Only one timer runs at a time to maintain focus
- **Pause/Resume** - Easily pause and resume timers without losing progress
- **Reset** - Reset any timer back to 00:00

### 🎨 Beautiful UI
- **Modern dark theme** with gradient backgrounds
- **Animated elements** and smooth transitions
- **Full-screen timer view** for focused tracking
- **Swipe-to-delete** with confirmation
- **Haptic feedback** throughout the app

### 📱 Lock Screen Widget
- **Multiple widget sizes** - Small, Medium, Circular, Rectangular, Inline
- **Live timer display** - See your current timer on the lock screen
- **Interactive controls** - Pause/resume directly from the widget
- **Auto-updating** - Widget refreshes to show current elapsed time

### ☁️ Google Sheets Sync
- **API key authentication** for shared sheets
- **Full data sync** - Timer names, durations, elapsed times
- **Pull to refresh** - Fetch latest data from your spreadsheet
- **Automatic persistence** - Data saved locally and to the cloud

### 🔄 Smart Background Behavior
- **Auto-pause on background** - Timer pauses when app is minimized
- **Auto-resume on foreground** - Continues when you return
- **Preserved elapsed time** - Never lose your progress

## Project Structure

```
DailiesTimer/
├── DailiesTimer/
│   ├── DailiesTimerApp.swift      # App entry point
│   ├── ContentView.swift          # Main navigation & settings
│   ├── Models/
│   │   └── TimerModel.swift       # Timer data model
│   ├── Views/
│   │   ├── TimerListView.swift    # List of all timers
│   │   ├── TimerRowView.swift     # Individual timer row
│   │   ├── FullScreenTimerView.swift # Full-screen timer
│   │   └── AddTimerView.swift     # Create new timer
│   ├── Services/
│   │   ├── TimerManager.swift     # Timer state management
│   │   └── GoogleSheetsService.swift # Google Sheets API
│   ├── Utilities/
│   │   └── Extensions.swift       # Colors, animations, helpers
│   └── Assets.xcassets/           # App icons and colors
├── TimerWidgetExtension/
│   ├── TimerWidget.swift          # Widget implementation
│   ├── TimerWidgetBundle.swift    # Widget bundle
│   └── Assets.xcassets/           # Widget assets
└── Shared/
    └── SharedDefaults.swift       # App Group data sharing
```

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository
2. Open `DailiesTimer.xcodeproj` in Xcode
3. Select your development team in Signing & Capabilities
4. Update the App Group identifier if needed (currently `group.com.dailies.timer`)
5. Build and run on your device or simulator

## Google Sheets Setup

To enable Google Sheets sync:

1. Create a Google Cloud project
2. Enable the Google Sheets API
3. Create an API key
4. Create a Google Sheet and make it publicly editable (or use service account)
5. In the app, go to Settings and enter:
   - **API Key**: Your Google Cloud API key
   - **Spreadsheet ID**: The ID from your sheet URL
   - **Sheet Name**: The tab name (default: "Timers")

The sheet will be populated with columns:
- ID, Name, Reference Duration (s), Elapsed Time (s), Is Running, Last Updated

## Widget Setup

1. Long-press on your Home Screen
2. Tap the + button to add widgets
3. Search for "Dailies" or "Timer"
4. Choose your preferred widget size
5. For Lock Screen: Edit lock screen and add the widget

## Architecture

The app uses:
- **SwiftUI** for all UI components
- **Combine** for reactive state management
- **WidgetKit** for home screen and lock screen widgets
- **App Groups** for sharing data between app and widget
- **URLSession** for Google Sheets API communication

## Color Palette

| Color | Hex | Usage |
|-------|-----|-------|
| Background | `#1a1a2e` | Main background |
| Surface | `#16213e` | Cards, elevated surfaces |
| Primary | `#e94560` | Accent, interactive elements |
| Secondary | `#0f3460` | Secondary elements |
| Accent | `#ff6b6b` | Highlights, gradients |
| Success | `#4ecdc4` | Running state, confirmations |
| Warning | `#ffd93d` | Exceeded time, warnings |

## License

MIT License - feel free to use this project for personal or commercial purposes.

## Acknowledgments

- Inspired by the need for simple, focused timer tracking
- Built with ❤️ using SwiftUI

