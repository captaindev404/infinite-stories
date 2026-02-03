## MODIFIED Requirements

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
