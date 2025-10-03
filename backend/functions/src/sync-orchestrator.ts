/**
 * Sync Orchestrator Cloud Function
 *
 * This function implements the intelligent bidirectional sync system for the
 * hybrid SwiftData + Firebase architecture. It handles:
 * - Dual-UUID mapping between iOS SwiftData and Firestore
 * - Conflict detection and resolution using last-write-wins with metadata
 * - Delta sync for efficient incremental updates
 * - Real-time multi-device coordination
 * - Event sourcing patterns for reliable sync
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import * as logger from 'firebase-functions/logger';

// Initialize Firestore if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// =============================================================================
// TYPES AND INTERFACES
// =============================================================================

interface SyncRequest {
  device_id: string;
  device_name?: string;
  device_type: 'ios' | 'android' | 'web';
  app_version?: string;
  last_sync_cursor?: number;
  entity_types?: string[]; // Specific entities to sync, or all if empty
  local_changes: LocalChange[];
  capabilities?: {
    supports_real_time: boolean;
    supports_file_sync: boolean;
    max_batch_size: number;
  };
}

interface LocalChange {
  entity_type: 'heroes' | 'stories' | 'customEvents' | 'storyScenes' | 'storyIllustrations';
  client_id: string; // SwiftData UUID
  server_id?: string; // Firestore document ID
  operation: 'create' | 'update' | 'delete';
  data: any;
  version: number;
  timestamp: string; // ISO string
  checksum?: string; // For integrity verification
}

interface SyncResponse {
  sync_cursor: number;
  device_id: string;
  server_changes: ServerChange[];
  conflicts: ConflictInfo[];
  sync_status: {
    total_processed: number;
    successful: number;
    conflicts: number;
    errors: number;
  };
  next_sync_recommended_at: string; // ISO string
  real_time_enabled: boolean;
}

interface ServerChange {
  entity_type: string;
  server_id: string; // Firestore document ID
  client_id?: string; // SwiftData UUID if mapped
  operation: 'create' | 'update' | 'delete';
  data: any;
  version: number;
  timestamp: string;
  device_source: string; // Which device made this change
}

interface ConflictInfo {
  entity_type: string;
  entity_id: string;
  conflict_type: 'version_mismatch' | 'concurrent_edit' | 'delete_conflict';
  client_version: any;
  server_version: any;
  resolution_hint: 'client_wins' | 'server_wins' | 'merge_required' | 'manual';
  auto_resolvable: boolean;
}

interface SyncMetadata {
  user_id: string;
  entity_type: string;
  server_id: string; // Firestore document ID
  client_id: string; // SwiftData UUID
  device_id: string;
  sync_status: 'synced' | 'pending' | 'conflict';
  sync_version: number;
  last_synced_at: string;
  created_at: string;
  updated_at: string;
}

interface SyncDelta {
  user_id: string;
  entity_type: string;
  entity_id: string; // Firestore document ID
  client_id?: string; // SwiftData UUID if available
  operation: 'create' | 'update' | 'delete';
  device_id: string;
  sequence_number: number;
  delta_data: any;
  created_at: string;
}

// =============================================================================
// SYNC ORCHESTRATION LOGIC
// =============================================================================

class SyncOrchestrator {
  constructor(
    private userId: string,
    private requestId: string
  ) {}

  /**
   * Main sync orchestration method
   */
  async orchestrateSync(request: SyncRequest): Promise<SyncResponse> {
    const startTime = Date.now();

    logger.info('sync_started', {
      requestId: this.requestId,
      device_id: request.device_id,
      entity_types: request.entity_types,
      local_changes: request.local_changes.length,
      last_cursor: request.last_sync_cursor,
    });

    // Update device presence
    await this.updateDevicePresence(request);

    // Process local changes (push) with atomic transactions
    const pushResults = await this.processLocalChanges(request.local_changes, request.device_id);

    // Fetch server changes (pull)
    const serverChanges = await this.fetchServerChanges(
      request.device_id,
      request.last_sync_cursor || 0,
      request.entity_types
    );

    // Detect and handle conflicts
    const conflicts = await this.detectConflicts(pushResults.conflicts);

    // Get updated sync cursor
    const newSyncCursor = await this.getLatestSyncCursor();

    // Prepare response
    const response: SyncResponse = {
      sync_cursor: newSyncCursor,
      device_id: request.device_id,
      server_changes: serverChanges,
      conflicts: conflicts,
      sync_status: {
        total_processed: request.local_changes.length,
        successful: pushResults.successful,
        conflicts: pushResults.conflicts.length,
        errors: pushResults.errors,
      },
      next_sync_recommended_at: this.calculateNextSyncTime(),
      real_time_enabled: request.capabilities?.supports_real_time || false,
    };

    const duration = Date.now() - startTime;
    logger.info('sync_completed', {
      requestId: this.requestId,
      device_id: request.device_id,
      duration_ms: duration,
      changes_processed: request.local_changes.length,
      changes_received: serverChanges.length,
      conflicts_detected: conflicts.length,
    });

    return response;
  }

  /**
   * Update device presence and capabilities
   */
  private async updateDevicePresence(request: SyncRequest): Promise<void> {
    try {
      const devicePresenceRef = db.collection('devicePresence').doc(`${this.userId}_${request.device_id}`);

      await devicePresenceRef.set({
        user_id: this.userId,
        device_id: request.device_id,
        device_name: request.device_name || 'Unknown Device',
        device_type: request.device_type,
        app_version: request.app_version || 'unknown',
        capabilities: request.capabilities || {},
        last_seen: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    } catch (error) {
      logger.warn('Failed to update device presence', {
        requestId: this.requestId,
        error: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  }

  /**
   * Process local changes from the client (push)
   */
  private async processLocalChanges(
    changes: LocalChange[],
    deviceId: string
  ): Promise<{
    successful: number;
    conflicts: ConflictInfo[];
    errors: number;
  }> {
    let successful = 0;
    let errors = 0;
    const conflicts: ConflictInfo[] = [];

    for (const change of changes) {
      try {
        await this.processSingleChange(change, conflicts, deviceId);
        successful++;
      } catch (error) {
        logger.error('Failed to process local change', {
          requestId: this.requestId,
          change: change,
          error: error instanceof Error ? error.message : 'Unknown error',
        });
        errors++;
      }
    }

    return { successful, conflicts, errors };
  }

  /**
   * Process a single local change
   */
  private async processSingleChange(
    change: LocalChange,
    conflicts: ConflictInfo[],
    deviceId: string
  ): Promise<void> {
    switch (change.operation) {
      case 'create':
        await this.handleCreate(change, conflicts, deviceId);
        break;
      case 'update':
        await this.handleUpdate(change, conflicts, deviceId);
        break;
      case 'delete':
        await this.handleDelete(change, conflicts, deviceId);
        break;
    }
  }

  /**
   * Handle create operations with atomic transaction
   */
  private async handleCreate(
    change: LocalChange,
    conflicts: ConflictInfo[],
    deviceId: string
  ): Promise<void> {
    // Use transaction for atomic operations
    await db.runTransaction(async (transaction) => {
      // Check if entity already exists with this client_id
      const metadataQuery = await transaction.get(
        db.collection('syncMetadata')
          .where('user_id', '==', this.userId)
          .where('entity_type', '==', change.entity_type)
          .where('client_id', '==', change.client_id)
          .limit(1)
      );

      if (!metadataQuery.empty) {
        // Entity already exists, this is a conflict
        const existingMeta = metadataQuery.docs[0].data();
        conflicts.push({
          entity_type: change.entity_type,
          entity_id: change.client_id,
          conflict_type: 'concurrent_edit',
          client_version: change.data,
          server_version: existingMeta,
          resolution_hint: 'merge_required',
          auto_resolvable: false,
        });
        return;
      }

      // Create new entity in the appropriate collection
      const entityRef = db.collection(change.entity_type).doc();
      const entityData = {
        ...change.data,
        user_id: this.userId,
        client_id: change.client_id,
        sync_status: 'synced',
        sync_version: 1,
        last_synced_at: admin.firestore.FieldValue.serverTimestamp(),
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      };
      transaction.set(entityRef, entityData);

      // Create sync metadata for dual UUID mapping
      const metadataRef = db.collection('syncMetadata').doc();
      const metadataData: Partial<SyncMetadata> = {
        user_id: this.userId,
        entity_type: change.entity_type,
        server_id: entityRef.id,
        client_id: change.client_id,
        device_id: deviceId,
        sync_status: 'synced',
        sync_version: 1,
        last_synced_at: new Date().toISOString(),
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      };
      transaction.set(metadataRef, metadataData);

      // Create sync delta for other devices
      const deltaRef = db.collection('syncDeltas').doc();
      const deltaData: Omit<SyncDelta, 'client_id'> & { client_id?: string } = {
        user_id: this.userId,
        entity_type: change.entity_type,
        entity_id: entityRef.id,
        client_id: change.client_id,
        operation: 'create',
        device_id: deviceId,
        sequence_number: Date.now(), // Using timestamp as sequence for simplicity
        delta_data: entityData,
        created_at: new Date().toISOString(),
      };
      transaction.set(deltaRef, deltaData);
    });
  }

  /**
   * Handle update operations with version check
   */
  private async handleUpdate(
    change: LocalChange,
    conflicts: ConflictInfo[],
    deviceId: string
  ): Promise<void> {
    if (!change.server_id) {
      throw new Error('Update operation requires server_id');
    }

    const serverId = change.server_id; // TypeScript guard

    await db.runTransaction(async (transaction) => {
      // Get current entity state
      const entityRef = db.collection(change.entity_type).doc(serverId);
      const entityDoc = await transaction.get(entityRef);

      if (!entityDoc.exists) {
        throw new Error(`Entity ${change.entity_type}/${serverId} not found`);
      }

      const currentData = entityDoc.data()!;
      const currentVersion = currentData.sync_version || 1;

      // Check for version mismatch (optimistic locking)
      if (currentVersion !== change.version) {
        conflicts.push({
          entity_type: change.entity_type,
          entity_id: serverId,
          conflict_type: 'version_mismatch',
          client_version: { ...change.data, version: change.version },
          server_version: { ...currentData, version: currentVersion },
          resolution_hint: 'merge_required',
          auto_resolvable: false,
        });
        return;
      }

      // Apply update with incremented version
      const updatedData = {
        ...change.data,
        sync_version: currentVersion + 1,
        last_synced_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      };
      transaction.update(entityRef, updatedData);

      // Update sync metadata
      const metadataQuery = await transaction.get(
        db.collection('syncMetadata')
          .where('server_id', '==', serverId)
          .where('user_id', '==', this.userId)
          .limit(1)
      );

      if (!metadataQuery.empty) {
        const metadataRef = metadataQuery.docs[0].ref;
        transaction.update(metadataRef, {
          sync_version: currentVersion + 1,
          sync_status: 'synced',
          last_synced_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        });
      }

      // Create sync delta
      const deltaRef = db.collection('syncDeltas').doc();
      const deltaData: Omit<SyncDelta, 'client_id'> & { client_id?: string } = {
        user_id: this.userId,
        entity_type: change.entity_type,
        entity_id: serverId,
        client_id: change.client_id,
        operation: 'update',
        device_id: deviceId,
        sequence_number: Date.now(),
        delta_data: updatedData,
        created_at: new Date().toISOString(),
      };
      transaction.set(deltaRef, deltaData);
    });
  }

  /**
   * Handle delete operations
   */
  private async handleDelete(
    change: LocalChange,
    conflicts: ConflictInfo[],
    deviceId: string
  ): Promise<void> {
    if (!change.server_id) {
      throw new Error('Delete operation requires server_id');
    }

    const serverId = change.server_id; // TypeScript guard

    await db.runTransaction(async (transaction) => {
      // Check if entity still exists and get current version
      const entityRef = db.collection(change.entity_type).doc(serverId);
      const entityDoc = await transaction.get(entityRef);

      if (!entityDoc.exists) {
        // Entity already deleted or not found
        return;
      }

      const currentData = entityDoc.data()!;
      const currentVersion = currentData.sync_version || 1;

      // Check for version mismatch
      if (currentVersion !== change.version) {
        conflicts.push({
          entity_type: change.entity_type,
          entity_id: serverId,
          conflict_type: 'delete_conflict',
          client_version: { operation: 'delete', version: change.version },
          server_version: { ...currentData, version: currentVersion },
          resolution_hint: 'manual',
          auto_resolvable: false,
        });
        return;
      }

      // Safe to delete
      transaction.delete(entityRef);

      // Clean up sync metadata
      const metadataQuery = await transaction.get(
        db.collection('syncMetadata')
          .where('server_id', '==', serverId)
          .where('user_id', '==', this.userId)
          .limit(1)
      );

      if (!metadataQuery.empty) {
        transaction.delete(metadataQuery.docs[0].ref);
      }

      // Create sync delta for deletion
      const deltaRef = db.collection('syncDeltas').doc();
      const deltaData: Omit<SyncDelta, 'client_id'> & { client_id?: string } = {
        user_id: this.userId,
        entity_type: change.entity_type,
        entity_id: serverId,
        client_id: change.client_id,
        operation: 'delete',
        device_id: deviceId,
        sequence_number: Date.now(),
        delta_data: { deleted: true, version: currentVersion },
        created_at: new Date().toISOString(),
      };
      transaction.set(deltaRef, deltaData);
    });
  }

  /**
   * Fetch server changes since last sync (pull)
   */
  private async fetchServerChanges(
    deviceId: string,
    lastSyncCursor: number,
    entityTypes?: string[]
  ): Promise<ServerChange[]> {
    const targetEntityTypes = entityTypes || ['heroes', 'stories', 'customEvents', 'storyScenes', 'storyIllustrations'];

    // Fetch deltas from other devices
    let query = db.collection('syncDeltas')
      .where('user_id', '==', this.userId)
      .where('sequence_number', '>', lastSyncCursor)
      .orderBy('sequence_number', 'asc')
      .limit(100); // Batch size limit

    const snapshot = await query.get();
    const deltas: ServerChange[] = [];

    snapshot.forEach((doc) => {
      const delta = doc.data() as SyncDelta;

      // Filter by entity types and exclude changes from this device
      if (targetEntityTypes.includes(delta.entity_type) && delta.device_id !== deviceId) {
        deltas.push(this.deltaToServerChange(delta));
      }
    });

    return deltas;
  }

  /**
   * Convert delta record to ServerChange format
   */
  private deltaToServerChange(delta: SyncDelta): ServerChange {
    const isDelete = delta.operation === 'delete';
    const data = isDelete ? delta.delta_data : delta.delta_data;

    return {
      entity_type: delta.entity_type,
      server_id: delta.entity_id,
      client_id: delta.client_id || '',
      operation: delta.operation,
      data: data,
      version: data.sync_version || 1,
      timestamp: delta.created_at,
      device_source: delta.device_id,
    };
  }

  /**
   * Detect and analyze conflicts
   */
  private async detectConflicts(existingConflicts: ConflictInfo[]): Promise<ConflictInfo[]> {
    // For now, return existing conflicts detected during processing
    // In the future, this could include more sophisticated conflict detection
    // such as checking for concurrent edits across different fields
    return existingConflicts;
  }

  /**
   * Get the latest sync cursor
   */
  private async getLatestSyncCursor(): Promise<number> {
    const query = await db.collection('syncDeltas')
      .where('user_id', '==', this.userId)
      .orderBy('sequence_number', 'desc')
      .limit(1)
      .get();

    if (query.empty) {
      return 0;
    }

    const latestDelta = query.docs[0].data() as SyncDelta;
    return latestDelta.sequence_number;
  }

  /**
   * Calculate next recommended sync time
   */
  private calculateNextSyncTime(): string {
    // Recommend sync in 5 minutes for active users
    const nextSync = new Date();
    nextSync.setMinutes(nextSync.getMinutes() + 5);
    return nextSync.toISOString();
  }
}

// =============================================================================
// VALIDATION HELPER
// =============================================================================

function validateSyncRequest(data: any): SyncRequest {
  if (!data.device_id || typeof data.device_id !== 'string') {
    throw new Error('device_id is required and must be a string');
  }

  if (!data.device_type || !['ios', 'android', 'web'].includes(data.device_type)) {
    throw new Error('device_type must be one of: ios, android, web');
  }

  if (!Array.isArray(data.local_changes)) {
    throw new Error('local_changes must be an array');
  }

  // Validate each local change
  for (const change of data.local_changes) {
    if (!change.entity_type || !['heroes', 'stories', 'customEvents', 'storyScenes', 'storyIllustrations'].includes(change.entity_type)) {
      throw new Error(`Invalid entity_type: ${change.entity_type}`);
    }

    if (!change.client_id || typeof change.client_id !== 'string') {
      throw new Error('client_id is required for each change');
    }

    if (!change.operation || !['create', 'update', 'delete'].includes(change.operation)) {
      throw new Error(`Invalid operation: ${change.operation}`);
    }

    if (!change.data || typeof change.data !== 'object') {
      throw new Error('data is required for each change');
    }

    if (typeof change.version !== 'number' || change.version < 1) {
      throw new Error('version must be a positive number');
    }

    if (!change.timestamp || typeof change.timestamp !== 'string') {
      throw new Error('timestamp is required for each change');
    }
  }

  return data as SyncRequest;
}

// =============================================================================
// MAIN CLOUD FUNCTION
// =============================================================================

/**
 * Sync Orchestrator Cloud Function
 *
 * Handles bidirectional sync between SwiftData on iOS and Firestore.
 * Manages dual UUID mapping, conflict resolution, and multi-device coordination.
 */
export const syncOrchestrator = onCall(
  {
    memory: '512MiB',
    timeoutSeconds: 60,
    maxInstances: 100,
  },
  async (request) => {
    const requestId = `sync-${Date.now()}`;
    const data = request.data;
    const context = request.auth;

    // Verify authentication
    if (!context) {
      logger.error('Unauthenticated request', { requestId });
      throw new HttpsError('unauthenticated', 'Authentication required');
    }

    const userId = context.uid;

    try {
      // Validate request
      const syncRequest = validateSyncRequest(data);

      // Log the sync request
      logger.info('Sync request received', {
        requestId,
        userId,
        device_id: syncRequest.device_id,
        changes_count: syncRequest.local_changes.length,
      });

      // Initialize sync orchestrator
      const orchestrator = new SyncOrchestrator(userId, requestId);

      // Perform sync orchestration
      const response = await orchestrator.orchestrateSync(syncRequest);

      // Emit real-time sync event for other devices if supported
      if (syncRequest.capabilities?.supports_real_time) {
        try {
          // Emit a custom event that other devices can listen to
          await db.collection('syncEvents').add({
            user_id: userId,
            device_id: syncRequest.device_id,
            event_type: 'sync_completed',
            sync_cursor: response.sync_cursor,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (error) {
          logger.warn('Failed to emit sync event', { requestId, error });
        }
      }

      // Track API usage
      try {
        await db.collection('apiUsage').add({
          user_id: userId,
          function_name: 'syncOrchestrator',
          request_id: requestId,
          status: 'success',
          response_time_ms: Date.now() - parseInt(requestId.split('-')[1] || '0'),
          metadata: {
            device_id: syncRequest.device_id,
            changes_processed: syncRequest.local_changes.length,
            changes_returned: response.server_changes.length,
            conflicts: response.conflicts.length,
          },
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (error) {
        logger.warn('Failed to track API usage', { requestId, error });
      }

      return response;
    } catch (error) {
      logger.error('Sync orchestration failed', {
        requestId,
        userId,
        error: error instanceof Error ? error.message : 'Unknown error',
      });

      // Track error in API usage
      try {
        await db.collection('apiUsage').add({
          user_id: userId,
          function_name: 'syncOrchestrator',
          request_id: requestId,
          status: 'error',
          error: error instanceof Error ? error.message : 'Unknown error',
          created_at: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (trackError) {
        logger.warn('Failed to track API error', { requestId, trackError });
      }

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError(
        'internal',
        error instanceof Error ? error.message : 'Sync orchestration failed'
      );
    }
  }
);