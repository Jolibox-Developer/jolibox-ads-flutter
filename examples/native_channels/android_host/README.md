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
generates the `0.8.1` Maven publication with API dependency on mediation.

To verify the released Maven artifact instead of the source project, pass
`-PadBridgeMavenRepository=https://raw.githubusercontent.com/Jolibox-Developer/jolibox-ads-flutter/0.8.1/maven/`
to Gradle. The same option accepts a local Maven repository path for release
verification. Only `admob` resolves the published adapter; `base` excludes it.

Inspect flavor dependencies using `./gradlew :app:dependencies
--configuration baseReleaseRuntimeClasspath` (and `admobReleaseRuntimeClasspath`).
The sample AdMob App ID is not a valid Jolibox source or scene for real ad tests.
