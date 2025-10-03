import { getStorage } from 'firebase-admin/storage';

/**
 * Storage utility functions for Firebase Cloud Functions
 */

// Get storage bucket instance
const storage = getStorage();
const bucket = storage.bucket();

/**
 * Storage paths configuration
 */
export const STORAGE_PATHS = {
  USER_AVATAR: (userId: string, filename: string) =>
    `users/${userId}/avatar/${filename}`,

  STORY_AUDIO: (storyId: string, filename: string) =>
    `stories/${storyId}/audio/${filename}`,

  HERO_AVATAR: (heroId: string, filename: string) =>
    `heroes/${heroId}/avatar/${filename}`,

  SCENE_ILLUSTRATION: (storyId: string, sceneId: string, filename: string) =>
    `stories/${storyId}/scenes/${sceneId}/illustration/${filename}`,

  USER_PRIVATE: (userId: string, path: string) =>
    `users/${userId}/private/${path}`,

  TEMP_UPLOAD: (userId: string, sessionId: string, filename: string) =>
    `temp/${userId}/${sessionId}/${filename}`,

  SYSTEM_ASSET: (path: string) =>
    `system/${path}`,
};

/**
 * Upload a file to Firebase Storage
 */
export async function uploadFile(
  path: string,
  buffer: Buffer,
  contentType: string,
  metadata?: Record<string, string>
): Promise<string> {
  const file = bucket.file(path);

  await file.save(buffer, {
    metadata: {
      contentType,
      cacheControl: 'public, max-age=3600',
      ...metadata,
    },
  });

  // Make file public if it's in a public path
  if (isPublicPath(path)) {
    await file.makePublic();
    return file.publicUrl();
  }

  // Return signed URL for private files
  return getSignedUrl(path);
}

/**
 * Upload a file from a URL
 */
export async function uploadFromUrl(
  sourceUrl: string,
  destinationPath: string,
  contentType: string
): Promise<string> {
  const response = await fetch(sourceUrl);
  const buffer = Buffer.from(await response.arrayBuffer());

  return uploadFile(destinationPath, buffer, contentType);
}

/**
 * Get a signed URL for temporary access
 */
export async function getSignedUrl(
  path: string,
  expiresInMinutes: number = 60
): Promise<string> {
  const file = bucket.file(path);

  const [url] = await file.getSignedUrl({
    action: 'read',
    expires: Date.now() + expiresInMinutes * 60 * 1000,
  });

  return url;
}

/**
 * Delete a file from storage
 */
export async function deleteFile(path: string): Promise<void> {
  const file = bucket.file(path);
  await file.delete({ ignoreNotFound: true });
}

/**
 * Check if a file exists
 */
export async function fileExists(path: string): Promise<boolean> {
  const file = bucket.file(path);
  const [exists] = await file.exists();
  return exists;
}

/**
 * Copy a file to a new location
 */
export async function copyFile(
  sourcePath: string,
  destinationPath: string
): Promise<void> {
  const sourceFile = bucket.file(sourcePath);
  const destinationFile = bucket.file(destinationPath);
  await sourceFile.copy(destinationFile);
}

/**
 * Move a file to a new location
 */
export async function moveFile(
  sourcePath: string,
  destinationPath: string
): Promise<void> {
  await copyFile(sourcePath, destinationPath);
  await deleteFile(sourcePath);
}

/**
 * List files in a directory
 */
export async function listFiles(
  prefix: string,
  delimiter?: string
): Promise<string[]> {
  const [files] = await bucket.getFiles({
    prefix,
    delimiter,
  });

  return files.map(file => file.name);
}

/**
 * Get file metadata
 */
export async function getFileMetadata(path: string): Promise<any> {
  const file = bucket.file(path);
  const [metadata] = await file.getMetadata();
  return metadata;
}

/**
 * Clean up temporary files older than 24 hours
 */
export async function cleanupTempFiles(): Promise<void> {
  const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

  const [files] = await bucket.getFiles({
    prefix: 'temp/',
  });

  const deletePromises = files
    .filter(file => {
      if (!file.metadata.timeCreated) return false;
      const created = new Date(file.metadata.timeCreated);
      return created < oneDayAgo;
    })
    .map(file => file.delete());

  await Promise.all(deletePromises);
}

/**
 * Determine if a path should be publicly accessible
 */
function isPublicPath(path: string): boolean {
  const publicPrefixes = [
    'stories/',
    'heroes/',
    'system/',
  ];

  return publicPrefixes.some(prefix => path.startsWith(prefix));
}

/**
 * Generate a unique filename with timestamp
 */
export function generateUniqueFilename(
  originalFilename: string,
  prefix?: string
): string {
  const timestamp = Date.now();
  const randomString = Math.random().toString(36).substring(2, 8);
  const extension = originalFilename.split('.').pop() || 'bin';
  const name = prefix ? `${prefix}_${timestamp}_${randomString}` : `${timestamp}_${randomString}`;

  return `${name}.${extension}`;
}

/**
 * Validate file size
 */
export function validateFileSize(
  sizeInBytes: number,
  maxSizeInMB: number
): boolean {
  const maxSizeInBytes = maxSizeInMB * 1024 * 1024;
  return sizeInBytes <= maxSizeInBytes;
}

/**
 * Validate file type
 */
export function validateFileType(
  contentType: string,
  allowedTypes: string[]
): boolean {
  return allowedTypes.some(type => {
    if (type.includes('*')) {
      const prefix = type.replace('*', '');
      return contentType.startsWith(prefix);
    }
    return contentType === type;
  });
}

/**
 * Storage limits configuration
 */
export const STORAGE_LIMITS = {
  IMAGE: {
    MAX_SIZE_MB: 10,
    ALLOWED_TYPES: ['image/png', 'image/jpeg', 'image/jpg', 'image/webp'],
  },
  AUDIO: {
    MAX_SIZE_MB: 50,
    ALLOWED_TYPES: ['audio/mpeg', 'audio/mp3', 'audio/mp4', 'audio/m4a'],
  },
  AVATAR: {
    MAX_SIZE_MB: 10,
    ALLOWED_TYPES: ['image/png', 'image/jpeg', 'image/jpg', 'image/webp'],
  },
  TEMP: {
    MAX_SIZE_MB: 100,
    ALLOWED_TYPES: ['*'], // All types allowed for temp
  },
};

/**
 * Process and optimize image before upload
 */
export async function optimizeImage(
  buffer: Buffer,
  maxWidth: number = 1920,
  maxHeight: number = 1920,
  quality: number = 85
): Promise<Buffer> {
  // This would use a library like sharp for image optimization
  // For now, return the original buffer
  // TODO: Implement image optimization with sharp
  return buffer;
}

/**
 * Generate thumbnail for an image
 */
export async function generateThumbnail(
  sourcePath: string,
  thumbnailPath: string,
  width: number = 200,
  height: number = 200
): Promise<string> {
  // TODO: Implement thumbnail generation
  // This would download the source, resize it, and upload the thumbnail
  return thumbnailPath;
}

export default {
  STORAGE_PATHS,
  uploadFile,
  uploadFromUrl,
  getSignedUrl,
  deleteFile,
  fileExists,
  copyFile,
  moveFile,
  listFiles,
  getFileMetadata,
  cleanupTempFiles,
  generateUniqueFilename,
  validateFileSize,
  validateFileType,
  STORAGE_LIMITS,
  optimizeImage,
  generateThumbnail,
};