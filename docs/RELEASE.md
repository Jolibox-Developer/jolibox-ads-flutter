# Release Guide

> **Chinese documentation:** [Release Guide](RELEASE.zh-CN.md)

## Scope

This repository distributes the public Flutter bridge. The Android Host supplies the approved Jolibox SDK-All dependency and owns native initialization. The Flutter package does not initialize Jolibox, AdMob, or another ad provider, and does not own the native initialization flow.

## Release checklist

### Android

- Verify the plugin API against the approved Android SDK-All version.
- Verify the Android mixed-host flow: native initialization, Flutter page launch, scene-based Banner, interstitial, and rewarded calls.
- Regression-test existing native Android Game and Drama ad flows.
- Verify staging/test configurations use test ad units only.
- Verify production configuration uses approved production ad units only.
- Confirm lifecycle and disposal behavior for every ad type.
- Confirm supported callbacks are forwarded and `onPaidEvent` is not exposed to the Host API.

### iOS — blocked

The iOS bridge code is present, but iOS is **not accepted for delivery**. The iOS SDK artifact repository and private CocoaPods Specs distribution are not ready, and iOS QA is incomplete.

Do not:

- start iOS Host integration;
- configure private Specs for this release;
- run `pod install` for this plugin;
- use the iOS bridge in production;
- describe iOS as a supported delivery target.

iOS can enter release validation only after Jolibox confirms artifact availability, dependency resolution, successful Host build, and complete iOS QA.

## Versioning

- Publish the Flutter plugin from an approved Git tag.
- Keep the plugin tag and Android SDK-All version explicitly documented together.
- The next Android delivery is `v0.2.0` with `jolibox-platform-sdk-all:1.9.0-rc.22399`.
- Do not publish repository credentials, internal configuration endpoints, or ad unit IDs.
- Update `CHANGELOG.md` and `CHANGELOG.zh-CN.md` for every public release.

## Host dependency rule

The Host should use one approved SDK-All dependency graph. Do not add a parallel Jolibox SDK graph or manually initialize AdMob beside SDK-All. Flutter only supplies the UI/API bridge and must not perform native SDK initialization.

## Release acceptance

Android is releasable only when the Android mixed-host verification and existing Game/Drama regression pass. iOS remains blocked until explicit iOS artifact and QA acceptance is recorded.
