/**
 * Sync Orchestrator Edge Function
 *
 * This function implements the intelligent bidirectional sync system for the
 * hybrid SwiftData + Supabase architecture. It handles:
 * - Dual-UUID mapping between iOS SwiftData and Supabase
 * - Conflict detection and resolution
 * - Delta sync for efficient incremental updates
 * - Real-time multi-device coordination
 * - Event sourcing patterns for reliable sync
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import {
  withEdgeFunctionWrapper,
  parseAndValidateJSON,
  createSupabaseServiceClient,
  logger,
  LogCategory
} from '../_shared/index.ts';

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
  entity_type: 'heroes' | 'stories' | 'custom_events' | 'story_scenes' | 'story_illustrations';
  client_id: string;
  server_id?: string; // For updates/deletes
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
  server_id: string;
  client_id?: string;
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

// =============================================================================
// SYNC ORCHESTRATION LOGIC
// =============================================================================

class SyncOrchestrator {
  constructor(
    private supabase: any,
    private userId: string,
    private requestId: string
  ) {}

  /**
   * Main sync orchestration method
   */
  async orchestrateSync(request: SyncRequest): Promise<SyncResponse> {
    const startTime = Date.now();

    logger.logSync('sync_started', this.requestId, {
      device_id: request.device_id,
      entity_types: request.entity_types,
      local_changes: request.local_changes.length,
      last_cursor: request.last_sync_cursor
    });

    // Update device presence
    await this.updateDevicePresence(request);

    // Process local changes (push)
    const pushResults = await this.processLocalChanges(request.local_changes);

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
        errors: pushResults.errors
      },
      next_sync_recommended_at: this.calculateNextSyncTime(),
      real_time_enabled: request.capabilities?.supports_real_time || false
    };

    const duration = Date.now() - startTime;
    logger.logSync('sync_completed', this.requestId, {
      device_id: request.device_id,
      duration_ms: duration,
      changes_processed: request.local_changes.length,
      changes_received: serverChanges.length,
      conflicts_detected: conflicts.length
    });

    return response;
  }

  /**
   * Update device presence and capabilities
   */
  private async updateDevicePresence(request: SyncRequest): Promise<void> {
    const { error } = await this.supabase.rpc('update_device_presence', {
      p_user_id: this.userId,
      p_device_id: request.device_id,
      p_device_name: request.device_name,
      p_device_type: request.device_type,
      p_app_version: request.app_version,
      p_capabilities: request.capabilities
    });

    if (error) {
      logger.warn('Failed to update device presence', LogCategory.SYNC, this.requestId, error);
    }
  }

  /**
   * Process local changes from the client (push)
   */
  private async processLocalChanges(changes: LocalChange[]): Promise<{
    successful: number;
    conflicts: ConflictInfo[];
    errors: number;
  }> {
    let successful = 0;
    let errors = 0;
    const conflicts: ConflictInfo[] = [];

    for (const change of changes) {
      try {
        await this.processingSingleChange(change, conflicts);
        successful++;
      } catch (error) {
        logger.error('Failed to process local change', LogCategory.SYNC, this.requestId, error);
        errors++;
      }
    }

    return { successful, conflicts, errors };
  }

  /**
   * Process a single local change
   */
  private async processingSingleChange(change: LocalChange, conflicts: ConflictInfo[]): Promise<void> {
    switch (change.operation) {
      case 'create':
        await this.handleCreate(change, conflicts);
        break;
      case 'update':
        await this.handleUpdate(change, conflicts);
        break;
      case 'delete':
        await this.handleDelete(change, conflicts);
        break;
    }
  }

  /**
   * Handle create operations
   */
  private async handleCreate(change: LocalChange, conflicts: ConflictInfo[]): Promise<void> {
    // Check if entity already exists with this client_id
    const { data: existing } = await this.supabase
      .from('sync_metadata')
      .select('server_id, sync_status')
      .eq('user_id', this.userId)
      .eq('entity_type', change.entity_type)
      .eq('client_id', change.client_id)
      .single();

    if (existing) {
      // Entity already exists, this might be a conflict
      conflicts.push({
        entity_type: change.entity_type,
        entity_id: change.client_id,
        conflict_type: 'concurrent_edit',
        client_version: change.data,
        server_version: existing,
        resolution_hint: 'merge_required',
        auto_resolvable: false
      });
      return;
    }

    // Create new entity
    const { data: newEntity, error } = await this.supabase
      .from(change.entity_type)
      .insert({
        ...change.data,
        user_id: this.userId,
        client_id: change.client_id,
        sync_status: 'synced',
        sync_version: 1,
        last_synced_at: new Date().toISOString()
      })
      .select()
      .single();

    if (error) {
      throw new Error(`Failed to create ${change.entity_type}: ${error.message}`);
    }

    // Create sync metadata
    await this.supabase
      .from('sync_metadata')
      .insert({
        user_id: this.userId,
        entity_type: change.entity_type,
        server_id: newEntity.id,
        client_id: change.client_id,
        device_id: change.data.device_id || 'unknown',
        sync_status: 'synced',
        sync_version: 1,
        last_synced_at: new Date().toISOString()
      });
  }

  /**
   * Handle update operations
   */
  private async handleUpdate(change: LocalChange, conflicts: ConflictInfo[]): Promise<void> {
    if (!change.server_id) {
      throw new Error('Update operation requires server_id');
    }

    // Use optimistic locking with version check
    const { data, error } = await this.supabase.rpc('update_with_version_check', {
      p_table_name: change.entity_type,
      p_id: change.server_id,
      p_user_id: this.userId,
      p_expected_version: change.version,
      p_updates: change.data
    });

    if (error) {
      throw new Error(`Failed to update ${change.entity_type}: ${error.message}`);
    }

    const result = data[0];
    if (!result.success) {
      // Conflict detected
      conflicts.push({
        entity_type: change.entity_type,
        entity_id: change.server_id,
        conflict_type: 'version_mismatch',
        client_version: change.data,
        server_version: result.conflict_data,
        resolution_hint: 'merge_required',
        auto_resolvable: false
      });
    }
  }

  /**
   * Handle delete operations
   */
  private async handleDelete(change: LocalChange, conflicts: ConflictInfo[]): Promise<void> {
    if (!change.server_id) {
      throw new Error('Delete operation requires server_id');
    }

    // Check if entity still exists and get current version
    const { data: current, error: fetchError } = await this.supabase
      .from(change.entity_type)
      .select('sync_version')
      .eq('id', change.server_id)
      .eq('user_id', this.userId)
      .single();

    if (fetchError || !current) {
      // Entity already deleted or not found
      return;
    }

    if (current.sync_version !== change.version) {
      // Version mismatch - entity was modified
      conflicts.push({
        entity_type: change.entity_type,
        entity_id: change.server_id,
        conflict_type: 'delete_conflict',
        client_version: { operation: 'delete', version: change.version },
        server_version: current,
        resolution_hint: 'manual',
        auto_resolvable: false
      });
      return;
    }

    // Safe to delete
    const { error } = await this.supabase
      .from(change.entity_type)
      .delete()
      .eq('id', change.server_id)
      .eq('user_id', this.userId);

    if (error) {
      throw new Error(`Failed to delete ${change.entity_type}: ${error.message}`);
    }

    // Clean up sync metadata
    await this.supabase
      .from('sync_metadata')
      .delete()
      .eq('server_id', change.server_id)
      .eq('user_id', this.userId);
  }

  /**
   * Fetch server changes since last sync (pull)
   */
  private async fetchServerChanges(
    deviceId: string,
    lastSyncCursor: number,
    entityTypes?: string[]
  ): Promise<ServerChange[]> {
    const { data: deltas, error } = await this.supabase
      .from('sync_deltas')
      .select('*')
      .eq('user_id', this.userId)
      .neq('device_id', deviceId) // Exclude changes from this device
      .gt('sequence_number', lastSyncCursor)
      .in('entity_type', entityTypes || ['heroes', 'stories', 'custom_events', 'story_scenes', 'story_illustrations'])
      .order('sequence_number', { ascending: true })
      .limit(100); // Batch size limit

    if (error) {
      throw new Error(`Failed to fetch server changes: ${error.message}`);
    }

    return deltas.map(delta => this.deltaToServerChange(delta));
  }

  /**
   * Convert delta record to ServerChange format
   */
  private deltaToServerChange(delta: any): ServerChange {
    const isDelete = delta.operation === 'delete';
    const data = isDelete ? delta.delta_data : delta.delta_data.new || delta.delta_data;

    return {
      entity_type: delta.entity_type,
      server_id: delta.entity_id,
      client_id: data.client_id,
      operation: delta.operation,
      data: data,
      version: data.sync_version || 1,
      timestamp: delta.created_at,
      device_source: delta.device_id
    };
  }

  /**
   * Detect and analyze conflicts
   */
  private async detectConflicts(existingConflicts: ConflictInfo[]): Promise<ConflictInfo[]> {
    // For now, return existing conflicts detected during processing
    // In the future, this could include more sophisticated conflict detection
    return existingConflicts;
  }

  /**
   * Get the latest sync cursor
   */
  private async getLatestSyncCursor(): Promise<number> {
    const { data, error } = await this.supabase
      .from('sync_deltas')
      .select('sequence_number')
      .eq('user_id', this.userId)
      .order('sequence_number', { ascending: false })
      .limit(1);

    if (error || !data || data.length === 0) {
      return 0;
    }

    return data[0].sequence_number;
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
// VALIDATION SCHEMAS
// =============================================================================

const SyncRequestSchema = {
  type: 'object',
  required: ['device_id', 'device_type', 'local_changes'],
  properties: {
    device_id: { type: 'string', minLength: 1 },
    device_name: { type: 'string' },
    device_type: { type: 'string', enum: ['ios', 'android', 'web'] },
    app_version: { type: 'string' },
    last_sync_cursor: { type: 'number', minimum: 0 },
    entity_types: {
      type: 'array',
      items: {
        type: 'string',
        enum: ['heroes', 'stories', 'custom_events', 'story_scenes', 'story_illustrations']
      }
    },
    local_changes: {
      type: 'array',
      items: {
        type: 'object',
        required: ['entity_type', 'client_id', 'operation', 'data', 'version', 'timestamp'],
        properties: {
          entity_type: {
            type: 'string',
            enum: ['heroes', 'stories', 'custom_events', 'story_scenes', 'story_illustrations']
          },
          client_id: { type: 'string', format: 'uuid' },
          server_id: { type: 'string', format: 'uuid' },
          operation: { type: 'string', enum: ['create', 'update', 'delete'] },
          data: { type: 'object' },
          version: { type: 'number', minimum: 1 },
          timestamp: { type: 'string', format: 'date-time' },
          checksum: { type: 'string' }
        }
      }
    },
    capabilities: {
      type: 'object',
      properties: {
        supports_real_time: { type: 'boolean' },
        supports_file_sync: { type: 'boolean' },
        max_batch_size: { type: 'number', minimum: 1, maximum: 1000 }
      }
    }
  }
};

// =============================================================================
// MAIN HANDLER
// =============================================================================

serve(async (req) => {
  return withEdgeFunctionWrapper(req, 'sync_orchestrator', async ({ userId, supabase, requestId }) => {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), {
        status: 405,
        headers: { 'Content-Type': 'application/json' }
      });
    }

    const request = await parseAndValidateJSON<SyncRequest>(req, SyncRequestSchema);

    // Initialize sync orchestrator
    const orchestrator = new SyncOrchestrator(supabase, userId, requestId);

    // Perform sync orchestration
    const response = await orchestrator.orchestrateSync(request);

    // Update API usage tracking
    await supabase
      .from('api_usage')
      .insert({
        user_id: userId,
        function_name: 'sync_orchestrator',
        request_id: requestId,
        model_used: 'sync_engine',
        status: 'success',
        response_time_ms: Date.now() - parseInt(requestId.split('-')[1] || '0'),
        metadata: {
          device_id: request.device_id,
          changes_processed: request.local_changes.length,
          changes_returned: response.server_changes.length,
          conflicts: response.conflicts.length
        }
      });

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    });
  });
});