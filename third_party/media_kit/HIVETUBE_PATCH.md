# Local media_kit patch

This is the MIT-licensed media_kit 1.2.6 package, retained locally until a
published release contains the upstream hot-restart fixes. The changes clear
old mpv wakeup callbacks before quitting old handles and use the isolate-based
event loop on the debug main isolate. They follow upstream fixes
https://github.com/media-kit/media-kit/pull/1416 and
https://github.com/media-kit/media-kit/issues/1340. The rest of the package is
unchanged. Remove this override when an appropriate release is available.
