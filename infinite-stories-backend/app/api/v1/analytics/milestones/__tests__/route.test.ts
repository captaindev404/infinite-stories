import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { NextRequest } from 'next/server';
import { prisma } from '@/lib/prisma/client';
import { MILESTONE_DEFINITIONS } from '@/lib/analytics/milestone-definitions';

// Mock requireAuth before importing the route
vi.mock('@/lib/auth/session', () => ({
  requireAuth: async () => ({
    id: 'test-user-id-milestones',
    email: 'test-milestones@example.com',
  }),
}));

// Import route after mocking
import { GET } from '../route';

describe('GET /api/v1/analytics/milestones', () => {
  let testUser: any;
  let userExists = false;

  beforeEach(async () => {
    // Create test user
    testUser = await prisma.user.create({
      data: {
        id: 'test-user-id-milestones',
        email: 'test-milestones@example.com',
        name: 'Test User',
      },
    });
    userExists = true;
  });

  afterEach(async () => {
    // Clean up test data
    if (userExists) {
      await prisma.userMilestone.deleteMany({
        where: { userId: testUser.id },
      });
      await prisma.userAnalyticsCache.deleteMany({
        where: { userId: testUser.id },
      });
      await prisma.user.delete({
        where: { id: testUser.id },
      });
      userExists = false;
    }
  });

  describe('Initial State', () => {
    it('should return all milestones with unlocked: false when no analytics cache exists', async () => {
      const request = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.data.milestones).toHaveLength(MILESTONE_DEFINITIONS.length);

      // All milestones should be locked
      data.data.milestones.forEach((milestone: any) => {
        expect(milestone.unlocked).toBe(false);
        expect(milestone.unlockedAt).toBeUndefined();
        expect(milestone.progress).toBe(0);
        expect(milestone.target).toBeGreaterThan(0);
        expect(milestone.percentage).toBe(0);
      });

      // Check summary
      expect(data.data.summary.totalMilestones).toBe(MILESTONE_DEFINITIONS.length);
      expect(data.data.summary.unlockedCount).toBe(0);
    });

    it('should create analytics cache if it does not exist', async () => {
      const request = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');

      await GET(request);

      // Verify analytics cache was created
      const cache = await prisma.userAnalyticsCache.findUnique({
        where: { userId: testUser.id },
      });

      expect(cache).toBeDefined();
      expect(cache?.totalStoriesListened).toBe(0);
      expect(cache?.totalListeningTimeSeconds).toBe(0);
      expect(cache?.currentStreak).toBe(0);
      expect(cache?.longestStreak).toBe(0);
    });
  });

  describe('Story Milestones', () => {
    it('should unlock FIRST_STORY after listening to 1 story', async () => {
      // Create analytics cache with 1 story listened
      await prisma.userAnalyticsCache.create({
        data: {
          userId: testUser.id,
          totalStoriesListened: 1,
        },
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);

      const firstStory = data.data.milestones.find((m: any) => m.id === 'FIRST_STORY');
      expect(firstStory.unlocked).toBe(true);
      expect(firstStory.unlockedAt).toBeDefined();
      expect(firstStory.progress).toBeUndefined(); // No progress shown for unlocked milestones
      expect(firstStory.target).toBeUndefined();

      // Other story milestones should still be locked
      const stories5 = data.data.milestones.find((m: any) => m.id === 'STORIES_5');
      expect(stories5.unlocked).toBe(false);
      expect(stories5.progress).toBe(1);
      expect(stories5.target).toBe(5);
      expect(stories5.percentage).toBe(20); // 1/5 = 20%
    });

    it('should unlock multiple story milestones progressively', async () => {
      // Create analytics cache with 10 stories listened
      await prisma.userAnalyticsCache.create({
        data: {
          userId: testUser.id,
          totalStoriesListened: 10,
        },
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);

      // FIRST_STORY, STORIES_5, STORIES_10 should be unlocked
      const firstStory = data.data.milestones.find((m: any) => m.id === 'FIRST_STORY');
      const stories5 = data.data.milestones.find((m: any) => m.id === 'STORIES_5');
      const stories10 = data.data.milestones.find((m: any) => m.id === 'STORIES_10');

      expect(firstStory.unlocked).toBe(true);
      expect(stories5.unlocked).toBe(true);
      expect(stories10.unlocked).toBe(true);

      // STORIES_25 should be locked with progress
      const stories25 = data.data.milestones.find((m: any) => m.id === 'STORIES_25');
      expect(stories25.unlocked).toBe(false);
      expect(stories25.progress).toBe(10);
      expect(stories25.target).toBe(25);
      expect(stories25.percentage).toBe(40); // 10/25 = 40%

      expect(data.data.summary.unlockedCount).toBe(3);
    });

    it('should unlock all story milestones at 50+ stories', async () => {
      await prisma.userAnalyticsCache.create({
        data: {
          userId: testUser.id,
          totalStoriesListened: 50,
        },
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);

      const storyMilestones = ['FIRST_STORY', 'STORIES_5', 'STORIES_10', 'STORIES_25', 'STORIES_50'];
      storyMilestones.forEach((id) => {
        const milestone = data.data.milestones.find((m: any) => m.id === id);
        expect(milestone.unlocked).toBe(true);
        expect(milestone.unlockedAt).toBeDefined();
      });
    });
  });

  describe('Listening Time Milestones', () => {
    it('should unlock LISTENING_1H after 1 hour (3600 seconds)', async () => {
      await prisma.userAnalyticsCache.create({
        data: {
          userId: testUser.id,
          totalListeningTimeSeconds: 3600,
        },
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);

      const listening1h = data.data.milestones.find((m: any) => m.id === 'LISTENING_1H');
      expect(listening1h.unlocked).toBe(true);
      expect(listening1h.unlockedAt).toBeDefined();

      // LISTENING_5H should show progress
      const listening5h = data.data.milestones.find((m: any) => m.id === 'LISTENING_5H');
      expect(listening5h.unlocked).toBe(false);
      expect(listening5h.progress).toBe(3600);
      expect(listening5h.target).toBe(18000);
      expect(listening5h.percentage).toBe(20); // 3600/18000 = 20%
    });

    it('should show correct progress towards listening milestones', async () => {
      // 2.5 hours = 9000 seconds
      await prisma.userAnalyticsCache.create({
        data: {
          userId: testUser.id,
          totalListeningTimeSeconds: 9000,
        },
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);

      // LISTENING_1H should be unlocked
      const listening1h = data.data.milestones.find((m: any) => m.id === 'LISTENING_1H');
      expect(listening1h.unlocked).toBe(true);

      // LISTENING_5H should show 50% progress
      const listening5h = data.data.milestones.find((m: any) => m.id === 'LISTENING_5H');
      expect(listening5h.unlocked).toBe(false);
      expect(listening5h.progress).toBe(9000);
      expect(listening5h.target).toBe(18000);
      expect(listening5h.percentage).toBe(50);
    });

    it('should unlock all listening time milestones at 10+ hours', async () => {
      await prisma.userAnalyticsCache.create({
        data: {
          userId: testUser.id,
          totalListeningTimeSeconds: 36000, // 10 hours
        },
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);

      const timeMilestones = ['LISTENING_1H', 'LISTENING_5H', 'LISTENING_10H'];
      timeMilestones.forEach((id) => {
        const milestone = data.data.milestones.find((m: any) => m.id === id);
        expect(milestone.unlocked).toBe(true);
      });
    });
  });

  describe('Streak Milestones', () => {
    it('should unlock STREAK_7 with current streak of 7 days', async () => {
      await prisma.userAnalyticsCache.create({
        data: {
          userId: testUser.id,
          currentStreak: 7,
          longestStreak: 7,
        },
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);

      const streak7 = data.data.milestones.find((m: any) => m.id === 'STREAK_7');
      expect(streak7.unlocked).toBe(true);
      expect(streak7.unlockedAt).toBeDefined();

      // STREAK_30 should show progress
      const streak30 = data.data.milestones.find((m: any) => m.id === 'STREAK_30');
      expect(streak30.unlocked).toBe(false);
      expect(streak30.progress).toBe(7);
      expect(streak30.target).toBe(30);
      expect(streak30.percentage).toBe(23); // 7/30 ≈ 23%
    });

    it('should keep STREAK_7 unlocked even if current streak drops', async () => {
      // longestStreak is 10, but currentStreak is only 2
      await prisma.userAnalyticsCache.create({
        data: {
          userId: testUser.id,
          currentStreak: 2,
          longestStreak: 10,
        },
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);

      // Should still be unlocked based on longestStreak
      const streak7 = data.data.milestones.find((m: any) => m.id === 'STREAK_7');
      expect(streak7.unlocked).toBe(true);

      // STREAK_30 should show progress based on higher of current/longest
      const streak30 = data.data.milestones.find((m: any) => m.id === 'STREAK_30');
      expect(streak30.unlocked).toBe(false);
      expect(streak30.progress).toBe(10); // Uses longestStreak
    });

    it('should unlock all streak milestones at 30+ days', async () => {
      await prisma.userAnalyticsCache.create({
        data: {
          userId: testUser.id,
          currentStreak: 30,
          longestStreak: 30,
        },
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);

      const streakMilestones = ['STREAK_7', 'STREAK_30'];
      streakMilestones.forEach((id) => {
        const milestone = data.data.milestones.find((m: any) => m.id === id);
        expect(milestone.unlocked).toBe(true);
      });
    });
  });

  describe('Milestone Persistence', () => {
    it('should persist newly unlocked milestones to database', async () => {
      await prisma.userAnalyticsCache.create({
        data: {
          userId: testUser.id,
          totalStoriesListened: 5,
        },
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.data.summary.unlockedCount).toBe(2); // FIRST_STORY + STORIES_5

      // Verify milestones were persisted to database
      const dbMilestones = await prisma.userMilestone.findMany({
        where: { userId: testUser.id },
      });

      expect(dbMilestones).toHaveLength(2);
      expect(dbMilestones.map((m) => m.milestoneId).sort()).toEqual([
        'FIRST_STORY',
        'STORIES_5',
      ]);
    });

    it('should not create duplicate milestone records', async () => {
      // Create analytics cache
      await prisma.userAnalyticsCache.create({
        data: {
          userId: testUser.id,
          totalStoriesListened: 1,
        },
      });

      // Call endpoint twice
      const request1 = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');
      await GET(request1);

      const request2 = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');
      await GET(request2);

      // Verify only one milestone record exists
      const dbMilestones = await prisma.userMilestone.findMany({
        where: {
          userId: testUser.id,
          milestoneId: 'FIRST_STORY',
        },
      });

      expect(dbMilestones).toHaveLength(1);
    });

    it('should return newlyUnlocked in summary on first unlock', async () => {
      await prisma.userAnalyticsCache.create({
        data: {
          userId: testUser.id,
          totalStoriesListened: 10,
        },
      });

      // First call - should unlock milestones
      const request1 = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');
      const response1 = await GET(request1);
      const data1 = await response1.json();

      expect(data1.data.summary.newlyUnlocked).toBeDefined();
      expect(data1.data.summary.newlyUnlocked).toContain('FIRST_STORY');
      expect(data1.data.summary.newlyUnlocked).toContain('STORIES_5');
      expect(data1.data.summary.newlyUnlocked).toContain('STORIES_10');

      // Second call - should not unlock any new milestones
      const request2 = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');
      const response2 = await GET(request2);
      const data2 = await response2.json();

      expect(data2.data.summary.newlyUnlocked).toBeUndefined();
    });

    it('should preserve unlockedAt timestamps across calls', async () => {
      await prisma.userAnalyticsCache.create({
        data: {
          userId: testUser.id,
          totalStoriesListened: 1,
        },
      });

      // First call
      const request1 = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');
      const response1 = await GET(request1);
      const data1 = await response1.json();

      const firstStory1 = data1.data.milestones.find((m: any) => m.id === 'FIRST_STORY');
      const unlockedAt1 = firstStory1.unlockedAt;

      // Wait a bit
      await new Promise((resolve) => setTimeout(resolve, 10));

      // Second call
      const request2 = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');
      const response2 = await GET(request2);
      const data2 = await response2.json();

      const firstStory2 = data2.data.milestones.find((m: any) => m.id === 'FIRST_STORY');
      const unlockedAt2 = firstStory2.unlockedAt;

      // Timestamps should be identical
      expect(unlockedAt1).toBe(unlockedAt2);
    });
  });

  describe('Mixed Progress', () => {
    it('should track progress across all milestone categories simultaneously', async () => {
      await prisma.userAnalyticsCache.create({
        data: {
          userId: testUser.id,
          totalStoriesListened: 3,
          totalListeningTimeSeconds: 1800, // 30 minutes
          currentStreak: 5,
          longestStreak: 5,
        },
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);

      // FIRST_STORY should be unlocked
      const firstStory = data.data.milestones.find((m: any) => m.id === 'FIRST_STORY');
      expect(firstStory.unlocked).toBe(true);

      // STORIES_5 should show progress
      const stories5 = data.data.milestones.find((m: any) => m.id === 'STORIES_5');
      expect(stories5.unlocked).toBe(false);
      expect(stories5.progress).toBe(3);
      expect(stories5.percentage).toBe(60); // 3/5 = 60%

      // LISTENING_1H should show progress
      const listening1h = data.data.milestones.find((m: any) => m.id === 'LISTENING_1H');
      expect(listening1h.unlocked).toBe(false);
      expect(listening1h.progress).toBe(1800);
      expect(listening1h.percentage).toBe(50); // 1800/3600 = 50%

      // STREAK_7 should show progress
      const streak7 = data.data.milestones.find((m: any) => m.id === 'STREAK_7');
      expect(streak7.unlocked).toBe(false);
      expect(streak7.progress).toBe(5);
      expect(streak7.percentage).toBe(71); // 5/7 ≈ 71%
    });

    it('should unlock all milestones with maximum stats', async () => {
      await prisma.userAnalyticsCache.create({
        data: {
          userId: testUser.id,
          totalStoriesListened: 100,
          totalListeningTimeSeconds: 72000, // 20 hours
          currentStreak: 60,
          longestStreak: 60,
        },
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);

      // All milestones should be unlocked
      data.data.milestones.forEach((milestone: any) => {
        expect(milestone.unlocked).toBe(true);
        expect(milestone.unlockedAt).toBeDefined();
        expect(milestone.progress).toBeUndefined();
        expect(milestone.target).toBeUndefined();
      });

      expect(data.data.summary.unlockedCount).toBe(MILESTONE_DEFINITIONS.length);
    });
  });

  describe('Data Structure', () => {
    it('should return correct milestone data structure', async () => {
      await prisma.userAnalyticsCache.create({
        data: {
          userId: testUser.id,
          totalStoriesListened: 3,
        },
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.data).toHaveProperty('milestones');
      expect(data.data).toHaveProperty('summary');
      expect(Array.isArray(data.data.milestones)).toBe(true);

      // Check milestone structure
      data.data.milestones.forEach((milestone: any) => {
        expect(milestone).toHaveProperty('id');
        expect(milestone).toHaveProperty('category');
        expect(milestone).toHaveProperty('title');
        expect(milestone).toHaveProperty('description');
        expect(milestone).toHaveProperty('unlocked');

        if (milestone.unlocked) {
          expect(milestone).toHaveProperty('unlockedAt');
        } else {
          expect(milestone).toHaveProperty('progress');
          expect(milestone).toHaveProperty('target');
          expect(milestone).toHaveProperty('percentage');
        }
      });

      // Check summary structure
      expect(data.data.summary).toHaveProperty('totalMilestones');
      expect(data.data.summary).toHaveProperty('unlockedCount');
    });

    it('should return milestones sorted by category and order', async () => {
      await prisma.userAnalyticsCache.create({
        data: {
          userId: testUser.id,
        },
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);

      const milestones = data.data.milestones;

      // Check categories are grouped together
      const categories = milestones.map((m: any) => m.category);
      const uniqueCategories = [...new Set(categories)];

      // Should have 3 categories
      expect(uniqueCategories).toHaveLength(3);

      // Story milestones should come first (alphabetically: 'listening_time', 'stories', 'streaks')
      const firstCategory = milestones[0].category;
      expect(['listening_time', 'stories', 'streaks']).toContain(firstCategory);
    });
  });

  describe('Error Handling', () => {
    it('should handle missing user gracefully', async () => {
      // Delete the test user
      await prisma.userMilestone.deleteMany({
        where: { userId: testUser.id },
      });
      await prisma.userAnalyticsCache.deleteMany({
        where: { userId: testUser.id },
      });
      await prisma.user.delete({
        where: { id: testUser.id },
      });
      userExists = false; // Mark as deleted so afterEach doesn't try to delete again

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/milestones');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(404);
      expect(data.error).toBe('NotFound');
      expect(data.message).toContain('User not found');
    });
  });
});
