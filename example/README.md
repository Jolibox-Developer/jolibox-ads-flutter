# Jolibox Ads Flutter example

This example is a local QA app for the Flutter bridge. It covers Banner,
Interstitial, and Rewarded ads. It does not contain a `joliSource` or a
configured scene.

## Run

1. Follow the native Android or iOS setup in the parent
   [integration guide](../README.md).
2. Copy `qa.local.json.example` to `qa.local.json` and enter the values supplied
   for your staging environment. The local file is ignored by Git.
3. Run the example with the local configuration:

   ```bash
   flutter run --dart-define-from-file=qa.local.json
   ```

Tap **Initialize** only when the application deliberately delegates its first
native SDK initialization to Flutter. In a mixed native/Flutter host that
already initializes natively, do not tap it; use the ad controls only after the
native initialization succeeds.

After initialization, the Banner Widget requests its ad automatically. Use the
separate Load and Show controls to verify the Interstitial and Rewarded object
lifecycles. See the parent guide for production integration and callback
semantics.

For Chinese, see [README_CN.md](README_CN.md).
