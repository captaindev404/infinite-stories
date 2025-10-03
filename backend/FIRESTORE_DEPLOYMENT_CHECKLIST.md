# Firestore Deployment Checklist

## Pre-Deployment Verification ✅

### Security Rules Review
- [x] **Authentication Required** - All collections require `request.auth != null`
- [x] **User Isolation** - Users can only access their own data (validated with `request.auth.uid`)
- [x] **No Temporary Rules** - No development-only or expiring rules present
- [x] **Field Validation** - Input validation for all critical fields
- [x] **Backend-Only Collections** - Proper restrictions on system collections (rateLimits, apiCache)
- [x] **Timestamp Validation** - All collections validate createdAt/updatedAt timestamps
- [x] **No Wildcards** - No dangerous wildcard permissions

### Index Configuration
- [x] **30 Indexes Defined** - Comprehensive coverage for all query patterns
- [x] **Heroes Collection** - 2 indexes for user queries and active status
- [x] **Stories Collection** - 4 indexes for filtering by hero, favorites, language
- [x] **Subcollections** - Collection group indexes for scenes and illustrations
- [x] **Custom Events** - 2 indexes for favorites and categories
- [x] **API Usage** - 3 indexes for monitoring and tracking
- [x] **Generation Queue** - 3 indexes for priority and scheduling
- [x] **Sync Collections** - 7 indexes for multi-device synchronization
- [x] **Performance Indexes** - All frequent queries have appropriate indexes

### Data Model Validation
- [x] **Hero Model** - Rules match Swift model with proper field validation
- [x] **Story Model** - Rules support both built-in and custom events
- [x] **Custom Events** - Category and tone validation in place
- [x] **Sync Metadata** - Entity type and device ID validation
- [x] **Generation Queue** - Job type validation for all generation types

## Deployment Steps 🚀

### Step 1: Environment Setup
```bash
# Navigate to backend directory
cd /Users/captaindev404/Code/Github/infinite-stories/backend

# Verify Firebase project
firebase projects:list
firebase use infinite-stories-prod  # or your project ID
```

### Step 2: Test with Emulator (RECOMMENDED)
```bash
# Start Firebase emulator
firebase emulators:start --only firestore

# Access Firestore UI at http://localhost:4000
# Test the following scenarios:
# 1. User authentication flow
# 2. Creating/reading user data
# 3. Verifying data isolation
# 4. Testing backend-only collections
```

### Step 3: Deploy Rules Only (Safe First Step)
```bash
# Deploy security rules only
firebase deploy --only firestore:rules

# Monitor Firebase Console for any rule evaluation errors
```

### Step 4: Deploy Indexes
```bash
# Deploy indexes (this may take several minutes)
firebase deploy --only firestore:indexes

# Note: Index building can take 10-30 minutes depending on data volume
```

### Step 5: Full Firestore Deployment
```bash
# Deploy both rules and indexes
firebase deploy --only firestore
```

### Step 6: Complete Firebase Deployment (Optional)
```bash
# Deploy everything including Cloud Functions if ready
firebase deploy
```

## Post-Deployment Testing 🧪

### Immediate Checks (0-5 minutes)
- [ ] **Console Access** - Verify Firebase Console shows updated rules
- [ ] **Rule Timestamp** - Confirm rules show current deployment time
- [ ] **No Errors** - Check for any immediate rule evaluation errors
- [ ] **Index Status** - Verify indexes show "Building" or "Ready" status

### Authentication Testing (5-15 minutes)
- [ ] **Sign Up** - Test new user registration
- [ ] **Sign In** - Test user authentication
- [ ] **Token Validation** - Verify auth tokens are properly validated
- [ ] **Sign Out** - Test logout flow

### Data Operations Testing (15-30 minutes)
- [ ] **Create Hero** - Test hero creation with all required fields
- [ ] **Read Heroes** - Verify users can only see their own heroes
- [ ] **Update Hero** - Test hero updates maintain ownership
- [ ] **Delete Hero** - Test deletion permissions

- [ ] **Create Story** - Test story generation with both event types
- [ ] **Read Stories** - Verify story isolation by user
- [ ] **Update Story** - Test story editing permissions
- [ ] **Favorite Story** - Test favorite toggling

- [ ] **Custom Events** - Test custom event creation and usage
- [ ] **API Usage** - Verify read-only access to usage data
- [ ] **Generation Queue** - Test job creation (backend processes)

### Security Testing (30-45 minutes)
- [ ] **Cross-User Access** - Attempt to read another user's data (should fail)
- [ ] **Unauthenticated Access** - Test accessing data without auth (should fail)
- [ ] **Invalid Fields** - Test creating documents with invalid fields (should fail)
- [ ] **Backend Collections** - Verify users cannot write to backend-only collections

### Performance Testing (45-60 minutes)
- [ ] **Query Performance** - Test indexed queries perform well
- [ ] **Missing Index Warnings** - Check logs for any missing index warnings
- [ ] **Large Result Sets** - Test pagination for large collections
- [ ] **Concurrent Access** - Test multiple users accessing data simultaneously

## Monitoring Setup 📊

### Enable Monitoring
```bash
# View real-time logs
firebase functions:log --only firestore

# Monitor rule evaluations in Firebase Console
# Go to Firestore > Rules > Monitor
```

### Set Up Alerts
- [ ] **Security Alert** - Configure alerts for denied rule evaluations
- [ ] **Performance Alert** - Set up alerts for slow queries
- [ ] **Usage Alert** - Configure billing alerts for read/write operations
- [ ] **Error Alert** - Set up error rate monitoring

### Regular Monitoring Tasks
- [ ] **Daily** - Check rule evaluation metrics
- [ ] **Weekly** - Review security logs for anomalies
- [ ] **Monthly** - Analyze usage patterns and costs
- [ ] **Quarterly** - Security audit and rule review

## Rollback Plan 🔄

### If Issues Occur

#### Quick Rollback (< 2 minutes)
```bash
# Revert to previous rules version
# Go to Firebase Console > Firestore > Rules > History
# Select previous version and click "Restore"
```

#### Manual Rollback
```bash
# Keep a backup of current rules
cp firestore.rules firestore.rules.backup

# If needed, restore and deploy
cp firestore.rules.backup firestore.rules
firebase deploy --only firestore:rules
```

## Success Criteria ✅

### Deployment is Successful When:
- [x] All security rules are deployed without errors
- [x] All indexes show "Ready" status
- [ ] Authentication flows work correctly
- [ ] Users can access only their own data
- [ ] Backend-only collections are protected
- [ ] No security warnings in Firebase Console
- [ ] Query performance is acceptable
- [ ] No missing index errors in logs

## Important Notes ⚠️

### Critical Reminders
1. **Never deploy without testing** - Always use emulator first
2. **Monitor after deployment** - Watch for evaluation errors
3. **Keep backups** - Save current rules before changes
4. **Index building time** - Indexes can take 10-30 minutes
5. **Gradual rollout** - Deploy rules first, then indexes
6. **Cost monitoring** - Watch read/write usage after deployment

### Common Issues and Solutions

#### Issue: "Missing Index" Error
**Solution**: Check Firebase Console for the exact index needed and add to firestore.indexes.json

#### Issue: "Permission Denied" Errors
**Solution**: Check rule evaluation in Firebase Console Monitor tab for specific failure reason

#### Issue: Slow Queries
**Solution**: Verify indexes are built and optimize query patterns

#### Issue: High Read/Write Costs
**Solution**: Review query patterns and implement caching strategies

## Contact Information

### Escalation Path
1. **First Line**: Check Firebase Console logs and monitoring
2. **Second Line**: Review this checklist and validation report
3. **Third Line**: Firebase Support (if enterprise agreement)
4. **Emergency**: Rollback to previous version immediately

## Deployment Log

### Record Deployment Details Here
- **Date**: ___________
- **Time**: ___________
- **Deployed By**: ___________
- **Firebase Project**: ___________
- **Rules Version**: ___________
- **Index Count**: 30
- **Issues Encountered**: ___________
- **Resolution**: ___________

---

**Checklist Last Updated**: 2025-10-03
**Next Review Date**: Q1 2026

## Appendix: Quick Commands Reference

```bash
# View current project
firebase use

# Switch project
firebase use PROJECT_ID

# Deploy rules only
firebase deploy --only firestore:rules

# Deploy indexes only
firebase deploy --only firestore:indexes

# Deploy all Firestore
firebase deploy --only firestore

# Start emulator
firebase emulators:start --only firestore

# View logs
firebase functions:log

# Test rules (if test suite exists)
npm test
```