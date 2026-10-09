# Native Android channel variants

Both `base` and `admob` flavors consume the same Flutter module artifact built
from `../flutter_module`. Only `admob` depends on `:adBridge`; only its source
set imports and registers the native bridge. The common `ChannelApplication`
registers the selected wrapper and host-ready channel on its Engine before the
first Dart entrypoint. Dart waits for `waitForHostReady` in both flavors.

Build the shared module once with
`ruby ../../../scripts/build-shared-module-aar.rb` from `../flutter_module`.
Then from this directory run `./gradlew assembleBaseRelease assembleAdmobRelease`.
The example uses a project dependency for development. The standalone bridge
defines a local-only Maven publication with API dependency on mediation; an
actual artifact publication/consumer check must be approved separately.

Inspect flavor dependencies using `./gradlew :app:dependencies
--configuration baseReleaseRuntimeClasspath` (and `admobReleaseRuntimeClasspath`).
The sample AdMob App ID is not a valid Jolibox source or scene for real ad tests.
