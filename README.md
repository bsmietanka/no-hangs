# No Hangs

A Flutter-based hangboard training app with Bluetooth connectivity for Tindeq Progressor devices.

> **⚠️ Notice:** This project is completely vibe-coded. Expect creative solutions, intuitive design choices, and code that follows the flow rather than formal architecture patterns.

## Overview

No Hangs is a mobile training application for climbers that connects to Tindeq Progressor (or compatible) force measurement devices via Bluetooth Low Energy (BLE). Track your hangboard sessions, monitor progress over time, and analyze your training data with comprehensive charts and statistics.

## Features

### Core Functionality
- **BLE Device Integration**: Seamless connection to Tindeq Progressor devices
- **Real-time Measurement**: Live weight tracking with configurable graph windows (10s - 60s)
- **Automatic Rep Detection**: Configurable threshold-based rep counting
- **Session Tracking**: Complete session history with SQLite storage
- **Battery Monitoring**: Real-time device battery status with low-power warnings

### Training Features
- **Customizable Exercises**: Create unlimited exercises with custom names and two-sided support
- **Personal Best Tracking**: Automatic PB recording per exercise (with separate L/R tracking)
- **Target Setting**: Set targets as percentage of PB or absolute weight values
- **Rep Statistics**: Track peak, average, and median weights per rep
- **Time Tracking**: Session duration and time since last rep
- **Side-Specific Training**: Support for left/right hand tracking on asymmetric exercises

### Data & Analytics
- **Training History**: Comprehensive historical data visualization
- **Flexible Grouping**: View data by session, day, week, or month
- **Multiple Metrics**: Compare volume, max weight, and median weight over time
- **Multi-Exercise Comparison**: Overlay multiple exercises on charts
- **Progress Tracking**: Visual trends and performance analysis

### Settings & Customization
- **Rep Detection Threshold**: Adjust sensitivity (0.5 - 5.0 kg)
- **Graph Window Size**: Configure display range (10s - 60s)
- **Exercise Management**: Add, edit, and remove exercises
- **Data Management**: Export/import exercises, delete session data

## Technical Stack

- **Framework**: Flutter
- **Language**: Dart
- **BLE Communication**: flutter_blue_plus
- **Database**: SQLite (sqflite)
- **Charts**: fl_chart
- **Platform**: Android & iOS

### Architecture

The app follows a service-based architecture separating business logic from UI:

**Services:**
- `TindeqProtocol`: BLE communication protocol handler
- `RepDetectionService`: Threshold-based rep detection algorithm
- `SessionService`: Session state and persistence management
- `DatabaseService`: SQLite database operations

**Models:**
- `Exercise`: Exercise configuration and metadata
- `Rep`: Individual rep data with time series

**Widgets:**
- `BLEConnectWidget`: Device connection and BLE control
- `MeasurementWidget`: Live weight display and rep tracking
- `HistoryPage`: Historical data visualization

## Device Communication

The app implements the Tindeq Progressor BLE protocol:
- **CMD_TARE (100)**: Zero the scale
- **CMD_START_WEIGHT (101)**: Begin weight streaming
- **CMD_GET_BATTERY_VOLTAGE (111)**: Request battery level
- Weight data stream at ~80 Hz
- Battery refresh every 5 minutes

## Getting Started

### Prerequisites
- Flutter SDK (latest stable)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Tindeq Progressor or compatible BLE force measurement device

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd no_hangs
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Building for Release

**Android APK:**
```bash
flutter build apk --release
```

**Android App Bundle (for Play Store):**
```bash
flutter build appbundle --release
```

## Project Structure

```
lib/
├── main.dart                      # App entry point
├── models/                        # Data models
│   ├── exercise.dart             # Exercise definitions
│   └── rep.dart                  # Repetition data model
├── pages/                         # Screen widgets
│   ├── history_page.dart         # Historical data visualization
│   └── settings_page.dart        # App configuration
├── services/                      # Business logic
│   ├── database_service.dart     # SQLite operations
│   ├── exercise_service.dart     # Exercise management
│   ├── tindeq_protocol.dart      # BLE protocol handler
│   └── rep_detection_service.dart # Rep detection logic
└── widgets/                       # Reusable UI components
    ├── ble_connect_widget.dart   # BLE connection UI
    └── measurement_widget.dart   # Live measurement display
```

## Database Schema

- **exercises**: Custom exercise definitions
- **session_reps**: Individual rep records with timestamps and metrics
- Personal bests calculated dynamically from rep data

## Future Development

- Data backup and cloud sync
- Enhanced BLE error recovery and reconnection logic
- Session notes and contextual tracking
- Advanced analytics and training insights

## License

[License information to be added]

## Contributing

[Contributing guidelines to be added]
