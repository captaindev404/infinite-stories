# Supabase to Firebase Migration Tool

A comprehensive Rust-based migration tool for transferring data from Supabase to Firebase, including database records and storage files.

## Features

- **Complete Data Migration**: Heroes, Stories, Custom Events, and Storage Files
- **Progress Tracking**: SQLite-based progress tracking with checkpoint/resume capability
- **Error Handling**: Comprehensive error logging with retry mechanisms
- **Parallel Processing**: Configurable worker threads for optimal performance
- **Validation**: Data consistency validation between source and target
- **Rollback Support**: Checkpoint-based rollback capabilities
- **Dry Run Mode**: Test migrations without modifying data
- **Detailed Reporting**: Export migration reports in JSON, CSV, or HTML format

## Prerequisites

- Rust 1.70+ installed
- Access to both Supabase and Firebase projects
- Service account credentials for Firebase (optional but recommended)
- Network access to both platforms

## Installation

1. Clone and navigate to the migration tool:
```bash
cd tools/migration
```

2. Build the tool:
```bash
cargo build --release
```

3. Copy and configure environment variables:
```bash
cp .env.example .env
# Edit .env with your credentials
```

## Configuration

### Environment Variables

Create a `.env` file with the following configuration:

```env
# Supabase Configuration
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_KEY=your-service-key

# Firebase Configuration
FIREBASE_PROJECT_ID=your-firebase-project
FIREBASE_API_KEY=your-api-key
FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
FIREBASE_STORAGE_BUCKET=your-project.appspot.com
FIREBASE_SERVICE_ACCOUNT_PATH=./service-account.json  # Optional

# Migration Settings
CHECKPOINT_INTERVAL=100        # Create checkpoint every N records
RETRY_MAX_ATTEMPTS=3          # Number of retry attempts
RETRY_DELAY_MS=1000           # Delay between retries in milliseconds
RATE_LIMIT_RPS=10             # Requests per second limit

# Storage Settings
TEMP_DIRECTORY=/tmp/migration  # Temporary directory for file transfers
VERIFY_CHECKSUMS=true         # Verify file integrity
PARALLEL_DOWNLOADS=4           # Number of parallel file downloads
```

## Usage

### Test Connections

Verify connections to both platforms:

```bash
./target/release/supabase-to-firebase-migration test-connection
```

### Run Full Migration

Execute a complete migration:

```bash
./target/release/supabase-to-firebase-migration migrate \
  --batch-size 100 \
  --workers 4
```

### Dry Run Mode

Test the migration without making changes:

```bash
./target/release/supabase-to-firebase-migration migrate --dry-run
```

### Resume from Checkpoint

Resume a previously interrupted migration:

```bash
./target/release/supabase-to-firebase-migration migrate --resume
```

### Validate Migration

Verify data consistency:

```bash
./target/release/supabase-to-firebase-migration validate --sample-size 100
```

### Check Status

View current migration status:

```bash
./target/release/supabase-to-firebase-migration status
```

### Generate Report

Export a detailed migration report:

```bash
# JSON format
./target/release/supabase-to-firebase-migration report --format json --output report.json

# CSV format
./target/release/supabase-to-firebase-migration report --format csv --output report.csv

# HTML format
./target/release/supabase-to-firebase-migration report --format html --output report.html
```

### Rollback

Rollback to a specific checkpoint:

```bash
./target/release/supabase-to-firebase-migration rollback checkpoint_id
```

## Migration Process

### 1. Pre-Migration

1. **Backup your data** in both Supabase and Firebase
2. Test connections using the `test-connection` command
3. Run a dry-run to identify potential issues
4. Review the migration plan and estimate time

### 2. Migration Phases

The tool migrates data in this order:

1. **Heroes**: User character data with avatars
2. **Stories**: Story content with metadata
3. **Custom Events**: User-created story events
4. **Storage Files**: Avatars, audio files, and illustrations

### 3. Progress Monitoring

- Progress bars show real-time migration status
- SQLite database tracks all migration records
- Checkpoints created every N records (configurable)
- Detailed logging for debugging

### 4. Error Handling

- Automatic retry with exponential backoff
- Failed records logged for manual review
- Option to skip failed records and continue
- Detailed error reporting

## Data Mapping

### Heroes
- `id` → Preserved as document ID
- `user_id` → Mapped to Firebase Auth UID
- All fields preserved with same structure
- Avatar URLs updated to Firebase Storage

### Stories
- `id` → Preserved as document ID
- `hero_id` → Reference to migrated hero
- `audio_url` → Updated to Firebase Storage URL
- Illustrations → Nested array with Firebase URLs

### Storage Files
- Supabase buckets mapped to Firebase Storage paths:
  - `hero-avatars` → `/avatars/`
  - `story-audio` → `/audio/`
  - `story-illustrations` → `/illustrations/`

## Performance Optimization

### Recommended Settings

For large migrations (>10,000 records):

```bash
./target/release/supabase-to-firebase-migration migrate \
  --batch-size 500 \
  --workers 8
```

### Resource Requirements

- **Memory**: ~500MB for typical migrations
- **Disk Space**: 2x the size of storage files for temporary storage
- **Network**: Stable connection with >10Mbps recommended
- **Time Estimate**: ~1000 records/minute (varies by data size)

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Verify service keys are correct
   - Check Firebase service account permissions
   - Ensure Supabase service key has appropriate access

2. **Network Timeouts**
   - Reduce batch size
   - Decrease worker count
   - Check network stability

3. **Storage Upload Failures**
   - Verify Firebase Storage bucket exists
   - Check storage rules allow writes
   - Ensure sufficient Firebase quota

4. **Memory Issues**
   - Reduce batch size
   - Lower parallel downloads
   - Increase system swap space

### Debug Mode

Enable verbose logging:

```bash
./target/release/supabase-to-firebase-migration --verbose migrate
```

## Safety Features

- **Idempotent Operations**: Safe to re-run migrations
- **Transaction Support**: Atomic operations where possible
- **Data Validation**: Checksums for file integrity
- **Audit Trail**: Complete migration history in SQLite
- **No Data Loss**: Source data never modified

## Post-Migration

1. **Validate Data**:
   ```bash
   ./target/release/supabase-to-firebase-migration validate --sample-size 0
   ```

2. **Generate Report**:
   ```bash
   ./target/release/supabase-to-firebase-migration report --format html --output final-report.html
   ```

3. **Update Application Configuration**:
   - Switch iOS app to use Firebase services
   - Update API endpoints
   - Test all functionality

4. **Monitor for Issues**:
   - Check Firebase console for errors
   - Monitor application logs
   - Verify user access to migrated data

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Supabase   │────▶│  Migration   │────▶│  Firebase   │
│   Source    │     │    Tool      │     │   Target    │
└─────────────┘     └──────────────┘     └─────────────┘
                           │
                           ▼
                    ┌──────────────┐
                    │   Progress   │
                    │   Tracking   │
                    │   (SQLite)   │
                    └──────────────┘
```

## Support

For issues or questions:
1. Check the troubleshooting section
2. Review logs in verbose mode
3. Check migration report for specific errors
4. File an issue with error details and logs

## License

This tool is part of the Infinite Stories project.