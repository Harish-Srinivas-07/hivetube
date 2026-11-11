# Open items

## Android checks

Run on a real Android phone:

1. Open a video, pause and resume, and drag the seek bar. Confirm seeking happens on release and the time bubble follows the thumb.
2. Double-tap each side repeatedly, long-press for 2× speed, and check that the previous speed returns on release.
3. Drag the video down, release above and below halfway, and fling in both directions. Confirm the same video and audio continue while the mini-player moves.
4. Tap or swipe the mini-player up; swipe it down or sideways and use close. Check Back from fullscreen, expanded, and mini states.
5. Open a different video while minimized, including one from the related list. Open Shorts while a video is minimized.
6. Enter fullscreen with auto-rotate both enabled and disabled. Rotate between landscape orientations; check the notch, system bars, center swipe, brightness, and volume.
7. Change speed and quality while playing and while paused. Confirm position, pause state, and the previous frame during the switch.
8. Restart the app and reopen a partly watched video. Check the saved position; test pause and close before the five-second save interval.
9. Enable autoplay and let a video finish. Check the five-second countdown, cancel it, and verify the setting persists after restart.
10. Test captions on videos with and without tracks, including a track that fails to load. Check placement and CC toggle.
11. Lock the screen or switch apps. Test notification play, pause, seek, next, and previous; disconnect headphones and interrupt playback with another audio app.
12. Drop and restore the network during playback. If possible, reproduce a 403 and check retry feedback, retry limits, and resumed position.

## Known limitations

- Caption availability depends on the player response and the timed-text endpoint. Some tracks may return an empty response; transcript fallback is not implemented.
- The previous-frame fallback depends on media_kit successfully capturing a screenshot. Confirm it works on the target device.
- Quality “Auto” currently selects the highest available format; it does not adapt bitrate during playback.
- Android focus and headphone handling use the activity's platform channel. Verify behavior after the activity is destroyed and the media service remains active.
- Multiple audio-track selection was excluded as requested; the existing default original-track selection remains.
- Device behavior has not been verified. Player unit and widget tests passed locally.
- Android build was not completed: the first attempt hit Kotlin incremental-cache errors; the retry was stopped at your request.
