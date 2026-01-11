# QR Music Player

A sleek, minimal Flutter app that lets you play Spotify tracks by scanning QR codes. Built for parties, discovery, or just a tangible music experience.

## Features

- **Scan & Play**: Instantly play tracks by scanning Spotify URIs or URLs.
- **Remote Control**: Play, pause, and resume directly from the app.
- **Secure Config**: Environment-based configuration for credentials.

## Getting Started

### Prerequisites

- **Flutter SDK**
- **Spotify App** (installed and logged in on the device)
- **Linux Build Tools** (if running on Linux):
  ```bash
  # Debian/Ubuntu
  sudo apt-get install ninja-build pkg-config libgtk-3-dev
  
  # Arch/Manjaro
  sudo pacman -S ninja pkgconf base-devel gtk3
  ```

### Configuration

1. **Clone the repo**
2. **Setup Environment Variables**:
   Create a `.env` file in the root directory:
   ```bash
   cp .env.example .env
   ```
   *Note: If `.env.example` doesn't exist, just create `.env` with:*
   ```env
   SPOTIFY_CLIENT_ID=your_client_id
   SPOTIFY_REDIRECT_URL=yourapp://spotify-login
   ```

### Running

```bash
flutter pub get
flutter run
```

---
*Built with Flutter & Spotify SDK*
