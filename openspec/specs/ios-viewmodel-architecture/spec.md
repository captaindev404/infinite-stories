# ios-viewmodel-architecture Specification

## Purpose
TBD - created by archiving change refactor-viewmodel-architecture. Update Purpose after archive.
## Requirements
### Requirement: ViewModels Must Follow Single Responsibility Principle
Each ViewModel SHALL handle exactly one domain of functionality:
- Story generation (pipeline orchestration)
- Audio playback (controls and progress)
- Story library (browsing and management)

All ViewModels SHALL wire up backend API calls for play count and story count instead of using hardcoded placeholder values.

#### Scenario: StoryGenerationViewModel handles only generation
- **GIVEN** a `StoryGenerationViewModel` instance
- **WHEN** inspecting its public interface
- **THEN** it exposes only generation-related methods (generateStory, retryGeneration, cancelGeneration)
- **AND** it does NOT expose audio playback or library management methods

#### Scenario: Play count is reported via API
- **WHEN** a story finishes playback
- **THEN** the ViewModel calls the backend API to increment play count
- **AND** does NOT use a TODO placeholder or hardcoded value

#### Scenario: Story count per hero is fetched from API
- **WHEN** a hero list or hero detail is displayed
- **THEN** the story count is fetched from the backend API
- **AND** does NOT use `storyCount: 0` as a hardcoded placeholder

#### Scenario: AudioPlaybackViewModel handles only playback
- **GIVEN** an `AudioPlaybackViewModel` instance
- **WHEN** inspecting its public interface
- **THEN** it exposes only playback-related methods (play, pause, seek, setSpeed)
- **AND** it does NOT expose generation or library management methods

#### Scenario: StoryLibraryViewModel handles only library management
- **GIVEN** a `StoryLibraryViewModel` instance
- **WHEN** inspecting its public interface
- **THEN** it exposes only library-related methods (loadStories, deleteStory, filterStories)
- **AND** it does NOT expose generation or playback methods

### Requirement: ViewModels Must Use @Observable Macro
All ViewModels SHALL use the iOS 17+ `@Observable` macro instead of `ObservableObject` protocol.

#### Scenario: ViewModel uses @Observable
- **GIVEN** a ViewModel class definition
- **WHEN** checking the class declaration
- **THEN** it uses `@Observable` macro (not `class X: ObservableObject`)
- **AND** properties do NOT use `@Published` wrapper

#### Scenario: Observable properties trigger view updates
- **GIVEN** a View observing a ViewModel property
- **WHEN** the ViewModel property changes
- **THEN** the View re-renders automatically
- **AND** only Views observing that specific property re-render

### Requirement: ViewModels Must Be Injected via Environment
Views SHALL receive shared ViewModels via SwiftUI `@Environment` instead of creating instances with `@StateObject`.

#### Scenario: View receives ViewModel from environment
- **GIVEN** a View that needs a ViewModel
- **WHEN** the View accesses the ViewModel
- **THEN** it uses `@Environment(ViewModelType.self)` property wrapper
- **AND** does NOT create the ViewModel with `@StateObject`

#### Scenario: ViewModel is shared across view hierarchy
- **GIVEN** two Views in the same hierarchy needing the same ViewModel
- **WHEN** both Views access the ViewModel via `@Environment`
- **THEN** both Views reference the same ViewModel instance
- **AND** state changes in one View are reflected in the other

#### Scenario: App root sets up environment
- **GIVEN** the app entry point (`InfiniteStoriesApp`)
- **WHEN** the app launches
- **THEN** ViewModels are created via `ViewModelFactory`
- **AND** injected into the environment using `.environment()` modifier

### Requirement: ViewModelFactory Must Manage Dependencies
A `ViewModelFactory` SHALL create and configure all ViewModels with their required dependencies.

#### Scenario: Factory creates ViewModels with repositories
- **GIVEN** a `ViewModelFactory` instance
- **WHEN** ViewModels are accessed
- **THEN** each ViewModel has its required repositories injected
- **AND** repositories are shared across ViewModels (not duplicated)

#### Scenario: Factory enables testing with mocks
- **GIVEN** a test environment
- **WHEN** creating a `ViewModelFactory` for tests
- **THEN** mock repositories can be injected via initializer parameters
- **AND** ViewModels use the mock repositories

### Requirement: StoryGenerationViewModel Must Orchestrate Generation Pipeline
The `StoryGenerationViewModel` SHALL manage the 3-step story generation pipeline (story → audio → illustrations).

#### Scenario: Generate story with standard event
- **GIVEN** a hero and story event
- **WHEN** `generateStory(for:event:)` is called
- **THEN** the ViewModel progresses through stages: `.generatingStory` → `.generatingAudio` → `.generatingIllustrations` → `.completed`
- **AND** `progress` updates incrementally (0.0 → 0.33 → 0.66 → 1.0)
- **AND** `currentStory` is set upon successful generation

#### Scenario: Generation fails at audio step
- **GIVEN** story content generated successfully
- **WHEN** audio generation fails
- **THEN** `stage` becomes `.failed(step: .audio, error: message)`
- **AND** `currentStory` retains the story without audio
- **AND** `retryAudioGeneration()` can be called to retry

#### Scenario: Cancel in-progress generation
- **GIVEN** generation is in progress
- **WHEN** `cancelGeneration()` is called
- **THEN** the current Task is cancelled
- **AND** `stage` resets to `.idle`
- **AND** any partial results are cleaned up

### Requirement: AudioPlaybackViewModel Must Control Playback
The `AudioPlaybackViewModel` SHALL manage audio playback state and controls.

#### Scenario: Play a story
- **GIVEN** a story with audio
- **WHEN** `play(story:)` is called
- **THEN** `isPlaying` becomes `true`
- **AND** `currentStory` is set to the story
- **AND** `duration` reflects the audio length

#### Scenario: Pause and resume
- **GIVEN** audio is playing
- **WHEN** `pause()` is called
- **THEN** `isPlaying` becomes `false`
- **AND** `isPaused` becomes `true`
- **AND** `currentTime` retains its value
- **WHEN** `resume()` is called
- **THEN** `isPlaying` becomes `true`
- **AND** playback continues from `currentTime`

#### Scenario: Seek to specific time
- **GIVEN** audio is loaded
- **WHEN** `seek(to: 30.0)` is called
- **THEN** `currentTime` becomes `30.0`
- **AND** playback position updates immediately

#### Scenario: Navigate story queue
- **GIVEN** a queue of stories is set
- **WHEN** `next()` is called
- **THEN** the current story advances to the next in queue
- **AND** `play(story:)` is called automatically
- **WHEN** `previous()` is called within first 3 seconds
- **THEN** the current story moves to the previous in queue
- **WHEN** `previous()` is called after 3 seconds
- **THEN** the current story restarts from the beginning

### Requirement: StoryLibraryViewModel Must Manage Library State
The `StoryLibraryViewModel` SHALL handle loading, filtering, and managing the story library.

#### Scenario: Load stories and heroes
- **GIVEN** a fresh StoryLibraryViewModel
- **WHEN** `loadContent()` is called
- **THEN** `isLoading` becomes `true`
- **AND** `stories` and `heroes` are populated from repositories
- **AND** `isLoading` becomes `false` upon completion

#### Scenario: Filter stories by hero
- **GIVEN** stories are loaded
- **WHEN** `filterByHero(hero)` is called
- **THEN** `filteredStories` contains only stories for that hero
- **AND** `selectedHero` is set to the hero

#### Scenario: Delete a story
- **GIVEN** a story in the library
- **WHEN** `deleteStory(story)` is called
- **THEN** the story is removed via repository
- **AND** `stories` list is updated
- **AND** associated media cache is cleared

### Requirement: ViewModel State Must Be Minimal and Focused
Each ViewModel SHALL have no more than 10 published properties to maintain clarity.

#### Scenario: StoryGenerationViewModel has focused state
- **GIVEN** a `StoryGenerationViewModel`
- **WHEN** counting observable properties
- **THEN** there are 5 or fewer primary state properties
- **AND** related properties are logically grouped

#### Scenario: No redundant state across ViewModels
- **GIVEN** multiple ViewModels
- **WHEN** inspecting their properties
- **THEN** the same data is NOT duplicated across ViewModels
- **AND** ViewModels reference shared repositories as source of truth

