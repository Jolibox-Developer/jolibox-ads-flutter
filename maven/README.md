# Android bridge Maven repository

The `0.8.1` Git tag provides the Maven repository at:

`https://raw.githubusercontent.com/Jolibox-Developer/jolibox-ads-flutter/0.8.1/maven/`

Coordinate: `com.jolibox.admediation:jolibox-ads-flutter-bridge-admob:0.8.1`.
The AAR contains only the bridge. Its POM and Gradle module metadata declare
Jolibox mediation `0.8.1`; the host also needs that SDK's Maven repository and
Google/Maven Central repositories. The host supplies its existing Flutter
Engine. Add the bridge only to the ads-enabled native configuration.

To generate release artifacts, use Java 17 and run
`./gradlew testDebugUnitTest publishReleasePublicationToMavenRepository` in
`native/android`. Set `ANDROID_HOME` to the installed Android SDK. Gradle writes
the artifacts and checksums to `native/android/build/local-maven`; copy the
reviewed version directory into this Maven tree before tagging a release.
Published version directories must not be overwritten with different binaries.
