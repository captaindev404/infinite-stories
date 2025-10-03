# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Infinite Stories** is an iOS application that generates personalized bedtime stories for children, featuring:
- AI-generated narratives using GPT-5
- Text-to-speech audio synthesis
- Dynamic scene illustrations
- Multi-language support (5 languages)
- Firebase backend infrastructure
- Swift/SwiftUI iOS client

## Important Instructions

### Development Workflow
1. **Always use the PRD tool** for task management when working on complex features
2. **Test thoroughly** - Run tests after implementing features
3. **Use Rust for tooling** - All development tools must be built in Rust
4. **Follow Swift conventions** - Modern Swift, async/await, SwiftUI best practices
5. **Verify Firebase integration** - Test all backend operations

### Working with the PRD Tool

The project includes a Rust-based task management tool at `tools/prd/` for coordinating work:

```bash
# Build the tool
cd tools/prd
cargo build --release

# Basic usage
./target/release/prd create "Implement feature X" --priority high
./target/release/prd list --status pending
./target/release/prd-dashboard  # Launch interactive dashboard
```

**For programmatic access (recommended for agents):**

```rust
use prd_tool::{PRDClient, Priority, TaskStatus};

fn main() -> anyhow::Result<()> {
    let client = PRDClient::new("tools/prd.db")?;

    // Register agent
    let agent_name = "feature-agent";
    client.create_agent(agent_name.to_string())?;

    // Get next task
    if let Some(task) = client.get_next_task(Some(Priority::High))? {
        client.sync_agent(agent_name, &task.id)?;

        // Do work...

        client.complete_task(&task.id, agent_name)?;
    }

    Ok(())
}
```

See `tools/prd/README.md` for complete documentation.

### Task Breakdown for Large Features

When implementing large features:

1. **Use PRD to break down work:**
   ```bash
   # Create parent task
   prd create "Implement feature X" --priority critical

   # Break down interactively
   prd breakdown <task-id> --interactive
   ```

2. **Coordinate between agents** using the shared database
3. **Track progress** with the dashboard running in a separate terminal
4. **Log all significant changes** in task activity logs

## Project Structure

```
infinite-stories/
├── InfiniteStories/          # iOS app (Swift/SwiftUI)
│   ├── Services/             # Firebase integration, AI services
│   ├── Views/                # SwiftUI views
│   ├── Models/               # Data models
│   └── ViewModels/           # Business logic
├── backend/                  # Firebase backend
│   └── functions/            # Cloud Functions (TypeScript/Deno)
├── tools/                    # Development tools (Rust only)
│   └── prd/                  # Task management tool
│       ├── src/              # Rust source
│       ├── examples/         # Agent integration examples
│       └── README.md         # Tool documentation
├── dsl/                      # Domain-specific language specs
└── [docs]/                   # Various documentation files
```

## Technology Stack

### iOS Client
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Backend SDK**: Firebase iOS SDK
- **Async**: Swift concurrency (async/await)
- **Architecture**: MVVM

### Backend (Firebase)
- **Database**: Firestore
- **Storage**: Firebase Storage
- **Functions**: Cloud Functions (TypeScript/Deno)
- **Auth**: Firebase Authentication
- **AI**: OpenAI GPT-5, DALL-E 3, TTS-1-HD

### Development Tools
- **Language**: Rust (required for all tools)
- **Database**: SQLite (for PRD tool)
- **Build**: Cargo

## Development Commands

### iOS Development

```bash
# Open Xcode project
open InfiniteStories/InfiniteStories.xcodeproj

# Build
xcodebuild -project InfiniteStories/InfiniteStories.xcodeproj \
  -scheme InfiniteStories -configuration Debug

# Run tests
xcodebuild test -project InfiniteStories/InfiniteStories.xcodeproj \
  -scheme InfiniteStories -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Firebase Backend

```bash
# Navigate to backend
cd backend

# Deploy functions
firebase deploy --only functions

# View logs
firebase functions:log

# Local emulator
firebase emulators:start
```

### PRD Tool

```bash
# Build
cd tools/prd
cargo build --release

# Run CLI
./target/release/prd --help

# Run dashboard
./target/release/prd-dashboard

# Run examples
cargo run --example simple_agent
cargo run --example multi_agent_workflow

# Run tests
cargo test
```

## Code Standards

### Swift
- Use modern Swift features (async/await, actors, etc.)
- Follow SwiftUI best practices
- Implement proper error handling
- Use dependency injection
- Write unit tests for ViewModels

### TypeScript (Backend)
- Use strict type checking
- Implement comprehensive error handling
- Follow Deno conventions
- Validate all inputs
- Log all operations

### Rust (Tools)
- Use idiomatic Rust
- Leverage type system for safety
- Write comprehensive tests
- Document public APIs
- Use `anyhow` for error handling

## Best Practices

### When Implementing Features

1. **Break down the work:**
   - Use PRD tool to create parent task
   - Decompose into subtasks
   - Assign priorities

2. **Track progress:**
   - Update task status as you work
   - Log blockers immediately
   - Set estimated/actual durations

3. **Test thoroughly:**
   - Unit tests for business logic
   - Integration tests for APIs
   - UI tests for critical flows

4. **Document changes:**
   - Update relevant README files
   - Add inline code comments
   - Log task activity in PRD

### When Working with Multiple Agents

1. **Use PRD for coordination:**
   - Each agent registers with unique name
   - Agents sync before starting work
   - Agents report completion/blockers

2. **Avoid conflicts:**
   - Check task assignment before starting
   - Update status immediately when starting
   - Mark blockers to prevent duplicate work

3. **Share context:**
   - Log important decisions in task notes
   - Reference related tasks
   - Update documentation

## Testing Strategy

### iOS Tests
- **Unit Tests**: ViewModels, Services, Utilities
- **Integration Tests**: Firebase operations
- **UI Tests**: Critical user flows
- **Manual Testing**: Physical devices for final verification

### Backend Tests
- **Unit Tests**: Individual functions
- **Integration Tests**: Full request/response cycles
- **Content Safety Tests**: Verify all filtering works
- **Performance Tests**: Response times, costs

### Tool Tests
- **Unit Tests**: Core functionality
- **Integration Tests**: Database operations
- **Example Tests**: Verify examples compile and run

## Firebase Configuration

### Environment Setup

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login
firebase login

# Set project
firebase use infinite-stories-prod
```

### Required Secrets

```bash
# Set OpenAI API key
firebase functions:secrets:set OPENAI_API_KEY

# Verify secrets
firebase functions:secrets:list
```

## Common Tasks

### Adding a New Feature

```bash
# 1. Create task
prd create "Add feature X" --priority high --description "Detailed description"

# 2. Break down
prd breakdown <task-id> --interactive

# 3. Implement subtasks one by one
# ... code ...

# 4. Update task status
prd update <subtask-id> completed

# 5. Test thoroughly
# ... run tests ...

# 6. Complete parent task
prd update <task-id> completed
```

### Debugging Issues

```bash
# iOS logs
# Use Xcode console or:
xcrun simctl spawn booted log stream --level debug

# Firebase logs
firebase functions:log --only function-name

# PRD activity logs
prd show <task-id> --logs
```

### Deploying Changes

```bash
# 1. Ensure all tests pass
cargo test  # Tools
xcodebuild test ...  # iOS
npm test  # Backend

# 2. Update version numbers
# iOS: InfiniteStories/Info.plist
# Backend: package.json

# 3. Deploy backend
firebase deploy

# 4. Build iOS
# Use Xcode for App Store builds

# 5. Update PRD
prd update <deploy-task-id> completed
```

## Troubleshooting

### PRD Tool Issues

```bash
# Database locked
rm tools/prd.db && prd stats  # Recreates DB

# Build failures
cd tools/prd && cargo clean && cargo build --release

# Permission errors
chmod +x tools/prd/build.sh
```

### iOS Build Issues

```bash
# Clean build
xcodebuild clean -project InfiniteStories/InfiniteStories.xcodeproj

# Clear derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset simulators
xcrun simctl erase all
```

### Firebase Issues

```bash
# Re-authenticate
firebase logout
firebase login

# Check project
firebase projects:list

# Reset emulators
firebase emulators:kill && rm -rf ~/.config/firebase/
```

## Security Considerations

### Content Safety
- All user-generated content must be filtered
- Children should never be shown alone in images
- Maintain positive, age-appropriate atmosphere
- Use both rule-based and AI-powered filtering

### Data Protection
- All user data isolated by Firebase Auth
- Row-level security on all database operations
- Secure storage of generated content
- No PII in logs or analytics

### API Security
- Validate all inputs
- Use Firebase App Check
- Rate limit API calls
- Secure secrets in Firebase

## Resources

- **Main README**: [README.md](README.md)
- **API Documentation**: [API_DOCUMENTATION.md](API_DOCUMENTATION.md)
- **Architecture**: [ARCHITECTURE.md](ARCHITECTURE.md)
- **Developer Guide**: [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)
- **PRD Tool**: [tools/prd/README.md](tools/prd/README.md)
- **Backend Guide**: [backend/CLAUDE.md](backend/CLAUDE.md)
- **iOS Guide**: [InfiniteStories/CLAUDE.md](InfiniteStories/CLAUDE.md)

## Important Notes

- **DO NOT** create Python or JavaScript tools - use Rust only
- **DO NOT** commit sensitive data (.env files, API keys)
- **DO NOT** skip content safety filtering
- **ALWAYS** use PRD tool for complex multi-step tasks
- **ALWAYS** test on physical iOS devices before release
- **ALWAYS** verify Firebase costs before deploying changes

## Getting Help

1. Check relevant CLAUDE.md files in subdirectories
2. Review documentation in docs/ folder
3. Check PRD tool logs for agent coordination issues
4. Review Firebase console for backend issues
5. Use Xcode debugging for iOS issues

---

**Remember**: This is a children's app. Safety and appropriateness are paramount in all decisions.
