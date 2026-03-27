# Spec: App Store Compliance

## Purpose

Define all Apple App Store requirements the application must meet for submission and approval, including privacy manifest, launch screen, metadata, age rating, and support infrastructure.

## Requirements

### Requirement: Privacy Manifest File
The app MUST include a Privacy Manifest file declaring all privacy-sensitive API usage.

#### Scenario: Privacy manifest exists in bundle
- **Given** the app is built for distribution
- **When** the app bundle is inspected
- **Then** a `PrivacyInfo.xcprivacy` file exists in the bundle
- **And** it declares all required API categories and reasons

#### Scenario: UserDefaults API declaration
- **Given** the app uses UserDefaults for storing preferences
- **When** the privacy manifest is validated
- **Then** the `NSPrivacyAccessedAPICategoryUserDefaults` category is declared
- **And** the reason code `CA92.1` (app-specific data) is provided

### Requirement: Launch Screen Configuration
The app MUST have a properly configured launch screen that displays during app startup.

#### Scenario: Launch screen displays app branding
- **Given** the user launches the app
- **When** the app is loading
- **Then** a launch screen with app branding is displayed
- **And** the launch screen has a consistent color scheme with the app

### Requirement: App Store Metadata
The app MUST have complete metadata configured in App Store Connect.

#### Scenario: App name and description are set
- **Given** the app record exists in App Store Connect
- **When** the metadata is reviewed
- **Then** the app has a unique name (max 30 characters)
- **And** a promotional text (max 170 characters)
- **And** a full description (max 4000 characters)
- **And** relevant keywords (max 100 characters total)

#### Scenario: Screenshots for all required devices
- **Given** the app is being submitted
- **When** screenshots are uploaded
- **Then** screenshots exist for 6.9" iPhone display
- **And** screenshots exist for 6.7" iPhone display
- **And** screenshots exist for 12.9" iPad display (if iPad supported)

### Requirement: Age Rating Configuration
The app MUST have a completed age rating questionnaire.

#### Scenario: Age rating reflects content
- **Given** the app generates AI bedtime stories for children
- **When** the age rating questionnaire is completed
- **Then** the rating reflects the target audience (4+)
- **And** content descriptors are accurately selected

### Requirement: Privacy Policy URL
The app MUST provide a valid, accessible privacy policy URL.

#### Scenario: Privacy policy is accessible
- **Given** a user wants to review the privacy policy
- **When** they access the privacy policy URL
- **Then** a web page with privacy policy content is displayed
- **And** the policy describes data collection and usage practices

### Requirement: Support URL
The app MUST provide a valid support URL for user assistance.

#### Scenario: Support page is accessible
- **Given** a user needs help with the app
- **When** they access the support URL
- **Then** a support page or contact method is available

### Requirement: Info.plist Configuration
The Info.plist MUST include all required keys for App Store submission.

#### Scenario: Required keys are present
- **Given** the app is prepared for submission
- **When** Info.plist is validated
- **Then** `CFBundleDisplayName` is set to a user-friendly name
- **And** `CFBundleShortVersionString` follows semantic versioning
- **And** all usage description keys are present for used capabilities

#### Scenario: Background mode justification
- **Given** the app declares background modes
- **When** the reviewer evaluates the app
- **Then** each background mode has clear user-facing functionality
- **And** audio background mode is justified by audio playback features

## Cross-References
- `ios-integration` - iOS client configuration patterns
- `backend-auth` - Authentication during review testing
- `audio-generation` - Justifies audio background mode
