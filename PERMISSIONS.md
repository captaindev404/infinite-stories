# iOS Permissions Guide for InfiniteStories

## Current Status: LIMITED PERMISSIONS REQUIRED ⚠️

The InfiniteStories app currently requires minimal permissions:

### Required Permissions (Currently in Info.plist):
- **NSMicrophoneUsageDescription**: Currently listed but not actively used
  - Description: "InfiniteStories needs microphone access for audio recording features."
  - Status: Should be removed if not implementing voice features

### Features That DON'T Require Permissions:
- **SwiftData**: App's private database for heroes, stories, and illustrations
- **AVAudioPlayer**: MP3 audio playback (OpenAI-generated)
- **FileManager**: App's Documents directory for audio and illustration storage
- **URLSession**: Network requests to OpenAI API (automatically granted)
- **Keychain**: Secure storage for API keys (no permission needed)
- **DALL-E Illustrations**: Generated images stored in app's Documents/StoryIllustrations folder
- **Hero Avatars**: AI-generated avatars stored in app's private storage

## Future Permissions (if you add these features)

### 1. Microphone Access
**When needed**: If you add voice input features
```xml
<!-- Add to Info.plist -->
<key>NSMicrophoneUsageDescription</key>
<string>InfiniteStories needs microphone access to record custom voices for stories.</string>
```

### 2. Speech Recognition
**When needed**: If you add speech-to-text features
```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>InfiniteStories uses speech recognition to help create stories from voice input.</string>
```

### 3. Photo Library
**When needed**: If you add custom hero images
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>InfiniteStories needs access to your photos to set custom hero images.</string>
```

### 4. Camera
**When needed**: If you add photo capture for heroes
```xml
<key>NSCameraUsageDescription</key>
<string>InfiniteStories needs camera access to take photos of your child's drawings for heroes.</string>
```

## Implementation Notes

### Current Audio Setup
The app uses `AVAudioSession` with `.playback` category for MP3 playback, which doesn't require user permission:

```swift
try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
```

Audio is generated via OpenAI's tts-1-hd model and stored as MP3 files.

### Network Requests
URLSession requests to AI APIs work automatically without user permission. iOS handles network connectivity transparently.

### File Storage
All app data is stored in the app's sandbox:
- **SwiftData**: Automatic app database for heroes and stories
- **Audio files**: MP3 files in app's Documents directory
- **Settings**: UserDefaults for preferences
- **API Keys**: Secure storage in iOS Keychain

## Testing Permissions

To test your app's permission handling:

1. **iOS Simulator**: Permissions are automatically granted
2. **Real Device**: Same behavior - no permissions needed
3. **App Store**: No additional permission requirements

## App Store Considerations

### Required Info.plist Entries
None required for current functionality.

### Optional Recommendations
Add these for better App Store presentation:

```xml
<key>NSSupportsLiveActivities</key>
<false/>
<key>UIRequiresPersistentWiFi</key>
<false/>
<key>LSApplicationCategoryType</key>
<string>public.app-category.education</string>
```

## Visual Storytelling & Illustration Features

### Current Implementation
The app includes AI-generated illustrations using DALL-E 3:

1. **Story Illustrations**:
   - Generated via OpenAI's DALL-E 3 API
   - Stored in `Documents/StoryIllustrations/` directory
   - No photo library access needed (internal storage only)
   - Image files managed by `StoryIllustration` model

2. **Hero Avatars**:
   - AI-generated character images (1024x1024)
   - Stored in app's Documents directory
   - Referenced by URL in Hero model

### Storage Management
- **Location**: All images stored in app's sandboxed Documents directory
- **Format**: PNG/JPEG files saved locally
- **Access**: No external permissions required
- **Cleanup**: Handled automatically when stories/heroes are deleted

### Network Implications
- **API Usage**: Increased network requests for DALL-E generation
- **Data Transfer**: ~1-2MB per illustration download
- **Caching**: Images cached locally after first download
- **No cellular data restrictions**: Standard iOS cellular settings apply

### Privacy Considerations
- **No Photo Library Access**: Images stay within app sandbox
- **No Camera Access**: No photo capture features
- **No iCloud Sync**: Images stored locally only
- **User Control**: Parents can delete stories/heroes to remove images

### What Permissions Are NOT Needed
✅ **Photo Library**: No saving to or reading from Photos app
✅ **Camera**: No photo capture functionality
✅ **iCloud**: No cloud storage or sync
✅ **Files App**: No document sharing or export

### Potential Future Permissions
If you add these features, you'll need permissions:

1. **Export Illustrations to Photos**:
   ```xml
   <key>NSPhotoLibraryAddUsageDescription</key>
   <string>Save your child's story illustrations to your photo library.</string>
   ```

2. **Share Illustrations**:
   - No permission needed for UIActivityViewController
   - Built-in iOS share sheet handles permissions

## Action Required

⚠️ **Remove Unused Microphone Permission**:
The Info.plist currently includes NSMicrophoneUsageDescription but the app doesn't use microphone features. This should be removed to avoid App Store review issues:

```xml
<!-- Remove this from Info.plist -->
<key>NSMicrophoneUsageDescription</key>
<string>InfiniteStories needs microphone access for audio recording features.</string>
```

## Summary

✅ **Your app works without permission dialogs** (after removing unused microphone permission)

The visual storytelling features (illustrations and avatars) are fully implemented without requiring any additional iOS permissions. All generated images are stored in the app's private sandbox, ensuring privacy and security while maintaining a friction-free user experience.