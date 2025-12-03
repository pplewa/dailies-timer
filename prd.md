# iOS Timer App - Product Requirements Document & Implementation Plan

## Product Requirements

### Core Features

1. **Timer Management**

   - Add/remove/reset timers
   - Name timers
   - Custom duration input (for reference only, not a limit)
   - Count-up timers (start at 00:00, count up endlessly)
   - Only one timer can run at a time
   - Pause/resume functionality
   - No stop button - only reset button

2. **User Interface**

   - List view: displays all timers
   - Full-screen timer view: active timer takes entire screen
   - Simple, clean design
   - Controls: Play/Pause toggle button and Reset button

3. **Lock Screen Widget**

   - Interactive widget showing current timer
   - Can pause/resume timer from widget
   - Displays timer name and elapsed time

4. **Background Behavior**

   - Timer PAUSES (not stops) when app is backgrounded/minimized
   - Timer resumes when app returns to foreground (if was running before)
   - Timer runs when app is active or on lock screen (via widget)
   - Elapsed time is preserved when paused

5. **Google Sheets Integration**

   - API key authentication (shared sheet)
   - Full sync: timer names, durations, current elapsed time, pause state
   - Persistence across app launches