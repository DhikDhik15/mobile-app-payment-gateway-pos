# payment_simulator

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Local Development

The backend URL is configured via `.env` (loaded at startup with
`flutter_dotenv`) — no `--dart-define` is required.

1. Create a `.env` in the project root (see `.env.example`):

   ```
   API_BASE_URL=http://<UBUNTU_LAN_IP>:8081
   ```

   The LAN IP depends on your DHCP/network and may change — only edit
   `.env`, never the Dart source.

2. Run:

   ```sh
   flutter pub get
   flutter run
   ```

`.env` is git-ignored; commit `.env.example` as the template. For
production/staging, supply the `.env` value through the appropriate
build/deployment configuration.
# mobile-app-payment-gateway-pos
