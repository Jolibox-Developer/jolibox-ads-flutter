# Shared Flutter module

This module depends only on the root Dart package. The Android `base` and
`admob` flavors, and the iOS `HostBase` and `HostAds` targets, consume this
same module. Native hosts add the optional ad bridge without changing this
module's pubspec or Dart entrypoint.

The entrypoint waits for the example host's `waitForHostReady` channel before
probing for ads. Both host configurations must acknowledge readiness after
their native registration has completed. This handshake belongs to the sample
hosts, not the Jolibox public Dart API.

Run `flutter pub get`, `flutter analyze`, and `flutter test` here. For the
Android host's local debug/release AARs, run
`ruby ../../../scripts/build-shared-module-aar.rb` from this directory. The
script adjusts only the generated, Git-ignored `.android` build shell to the
validated AGP 8.6.1 / Gradle 8.7 / Kotlin 2.0.21 / Java 17 baseline. It does
not publish to a remote repository. It uses cached Gradle dependencies by
default; set `GRADLE_OFFLINE=0` if they must be downloaded on a new machine.

On iOS, the native two-target host runs this module through Flutter's
CocoaPods integration. It builds both targets from the same Flutter source,
pubspec, and lockfile.

The `JOLIBOX_SOURCE` and `JOLIBOX_SCENE` dart defines are only for authorized
local ad testing. Neither is needed for base-only or bridge-registration
checks. Use the same module build for both native configurations.
