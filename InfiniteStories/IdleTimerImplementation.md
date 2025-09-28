# Idle Timer Management Implementation

## Overview
The InfiniteStories app prevents the phone from sleeping during critical operations:
1. **Audio Playback**: When a bedtime story is playing
2. **Illustration Generation**: During AI-powered illustration creation (long-running operation)

This ensures parents don't have to worry about the phone's screen timing out during story playback or illustration generation.

## Implementation Details

### Core Changes in AudioService.swift

1. **Import UIKit**: Added UIKit import to access `UIApplication.shared.isIdleTimerDisabled`

2. **Idle Timer Control Methods**:
   - `disableIdleTimer()`: Sets `UIApplication.shared.isIdleTimerDisabled = true`
   - `enableIdleTimer()`: Sets `UIApplication.shared.isIdleTimerDisabled = false`
   - Both methods use `DispatchQueue.main.async` to ensure UI updates happen on the main thread

3. **Playback State Management**:
   - When audio starts playing (MP3 or TTS): Idle timer is disabled
   - When audio pauses: Idle timer is re-enabled
   - When audio stops: Idle timer is re-enabled
   - When audio resumes: Idle timer is disabled again
   - When audio finishes naturally: Idle timer is re-enabled

4. **App Lifecycle Handling**:
   - `appWillResignActive`: Checks if audio is playing, re-enables idle timer if not
   - `appDidBecomeActive`: Checks if audio is playing, disables idle timer if yes
   - Audio interruption handling: Manages idle timer during phone calls or other interruptions

5. **Delegate Methods Updated**:
   - `AVAudioPlayerDelegate`: Handles idle timer when audio finishes or encounters errors
   - `AVSpeechSynthesizerDelegate`: Manages idle timer for text-to-speech playback

### IdleTimerManager Service

The app now uses a centralized `IdleTimerManager` singleton service with reference counting to handle multiple simultaneous requests:

1. **Reference Counting**: Multiple components can request idle timer disable without conflict
2. **Thread Safety**: Uses concurrent queue with barriers for thread-safe operations
3. **Context Tracking**: Each request includes a context string for debugging
4. **Automatic Cleanup**: Idle timer is only re-enabled when all requests are released

### Illustration Generation Integration

1. **StoryViewModel Integration**:
   - Disables idle timer when `generateIllustrationsForStory()` starts
   - Re-enables when generation completes or fails
   - Handles cancellation properly with cleanup

2. **Long-Running Operations**:
   - Illustration generation can take 30-60 seconds per image
   - Multiple illustrations generated sequentially
   - Prevents screen sleep during entire generation process

3. **Manual Retry Support**:
   - Idle timer disabled during manual illustration retry
   - Properly managed for both single and batch retries

### Safety Measures

1. **Cleanup in deinit**: The AudioService deinit ensures idle timer is re-enabled when the service is deallocated

2. **View Lifecycle**: AudioPlayerView.onDisappear explicitly re-enables idle timer as a safety measure

3. **Error Handling**: Idle timer is re-enabled on any playback errors or generation failures

4. **Reference Counting**: IdleTimerManager prevents premature re-enabling when multiple operations are active

## User Experience

### When Idle Timer is Disabled (Phone Won't Sleep):
- Story is actively playing (audio or TTS)
- Audio is resumed after being paused
- Illustrations are being generated (30-60 seconds per image)
- Manual illustration retry is in progress
- Batch retry of failed illustrations is running

### When Idle Timer is Enabled (Phone Can Sleep):
- No audio is playing
- Audio is paused
- Audio is stopped
- Audio finishes playing
- User leaves the audio player screen
- App encounters an error during playback
- Illustration generation completes (success or failure)
- Illustration generation is cancelled
- All active operations complete

## Technical Considerations

1. **Power Management**: The implementation follows iOS best practices by only disabling the idle timer during active operations

2. **Background Audio**: The app uses `.playback` audio session category, allowing:
   - Audio to continue when the screen is manually locked
   - Audio to continue when the app goes to background
   - Proper handling of audio interruptions (phone calls, etc.)

3. **Thread Safety**:
   - All idle timer updates are dispatched to the main queue
   - IdleTimerManager uses concurrent queue with barriers for thread-safe reference counting

4. **Illustration Viewing**:
   - Idle timer is NOT disabled during passive illustration viewing/carousel navigation
   - Only disabled during active generation to prevent interruption of API calls
   - This conserves battery during passive content consumption

## Testing Recommendations

1. **Manual Testing**:
   - Start playing a story and wait to confirm the screen doesn't dim/lock
   - Pause the story and verify the screen can dim/lock normally
   - Test interruptions (receive a phone call during playback)
   - Test app backgrounding and foregrounding scenarios
   - Start illustration generation and verify screen stays awake
   - Cancel illustration generation and verify idle timer re-enables

2. **Edge Cases to Test**:
   - Switching between MP3 and TTS playback
   - Using playback speed controls
   - Seeking through audio
   - Multiple pause/resume cycles
   - Simultaneous audio playback and illustration generation
   - Illustration retry during audio playback
   - App termination during illustration generation

## Benefits

1. **User Convenience**: Parents don't need to adjust their phone's auto-lock settings
2. **Battery Optimization**: Idle timer is only disabled when necessary
3. **Consistent Experience**: Works for both MP3 files and text-to-speech
4. **Robust Error Handling**: Fails safely by re-enabling idle timer on any error
5. **Long Operation Support**: Prevents interruption of illustration generation
6. **Smart Power Management**: Distinguishes between active operations and passive viewing

## Performance Implications with Illustrations

1. **Generation Phase**:
   - Idle timer disabled only during active API calls
   - Minimal battery impact as screen can still dim (brightness reduction)
   - Network operations continue uninterrupted

2. **Viewing Phase**:
   - Idle timer follows normal system behavior
   - Screen can sleep during passive carousel viewing
   - Audio playback controls idle timer independently

3. **Memory Management**:
   - IdleTimerManager uses minimal memory with reference counting
   - No retention of illustration data or views
   - Proper cleanup on view dismissal or app termination