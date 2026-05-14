import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { NextRequest } from 'next/server';
import { prisma } from '@/lib/prisma/client';

// Mock requireAuth before importing the route
vi.mock('@/lib/auth/session', () => ({
  requireAuth: async () => ({
    id: 'test-user-id-activity',
    email: 'test-activity@example.com',
  }),
}));

// Import route after mocking
import { GET } from '../route';

describe('GET /api/v1/analytics/activity', () => {
  let testUser: any;
  let testHero: any;
  let testStory: any;

  beforeEach(async () => {
    // Clean up any existing test data first (in correct order for FK constraints)
    await prisma.listeningSession.deleteMany({
      where: { userId: 'test-user-id-activity' },
    });
    await prisma.story.deleteMany({
      where: { userId: 'test-user-id-activity' },
    });
    await prisma.hero.deleteMany({
      where: { userId: 'test-user-id-activity' },
    });
    await prisma.user.deleteMany({
      where: { email: 'test-activity@example.com' },
    });

    // Create test user
    testUser = await prisma.user.create({
      data: {
        id: 'test-user-id-activity',
        email: 'test-activity@example.com',
        name: 'Test User',
      },
    });

    // Create test hero (required for story FK)
    testHero = await prisma.hero.create({
      data: {
        userId: testUser.id,
        name: 'Test Hero',
        age: 8,
        traits: ['brave', 'kind'],
      },
    });

    // Create test story
    testStory = await prisma.story.create({
      data: {
        userId: testUser.id,
        heroId: testHero.id,
        title: 'Test Story',
        content: 'This is a test story.',
        audioDuration: 300, // 5 minutes
      },
    });
  });

  afterEach(async () => {
    // Clean up test data (in correct order for FK constraints)
    await prisma.listeningSession.deleteMany({
      where: { userId: testUser.id },
    });
    await prisma.story.deleteMany({
      where: { userId: testUser.id },
    });
    await prisma.hero.deleteMany({
      where: { userId: testUser.id },
    });
    await prisma.user.deleteMany({
      where: { id: testUser.id },
    });
  });

  describe('Range Parameter', () => {
    it('should return week range by default (7 days)', async () => {
      const request = new NextRequest('http://localhost:3000/api/v1/analytics/activity');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.data.range).toBe('week');
      expect(data.data.activity).toHaveLength(7);
    });

    it('should return month range when specified (30 days)', async () => {
      const request = new NextRequest(
        'http://localhost:3000/api/v1/analytics/activity?range=month'
      );

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.data.range).toBe('month');
      expect(data.data.activity).toHaveLength(30);
    });

    it('should return year range when specified (365 days)', async () => {
      const request = new NextRequest(
        'http://localhost:3000/api/v1/analytics/activity?range=year'
      );

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.data.range).toBe('year');
      expect(data.data.activity).toHaveLength(365);
    });

    it('should return 400 for invalid range parameter', async () => {
      const request = new NextRequest(
        'http://localhost:3000/api/v1/analytics/activity?range=invalid'
      );

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(400);
      expect(data.error).toBe('ValidationError');
      expect(data.message).toContain('Invalid range parameter');
    });
  });

  describe('Timezone Parameter', () => {
    it('should use UTC timezone by default', async () => {
      const request = new NextRequest('http://localhost:3000/api/v1/analytics/activity');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.data.timezone).toBe('UTC');
    });

    it('should accept valid IANA timezone', async () => {
      const request = new NextRequest(
        'http://localhost:3000/api/v1/analytics/activity?timezone=America/New_York'
      );

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.data.timezone).toBe('America/New_York');
    });

    it('should return 400 for invalid timezone with spaces', async () => {
      const request = new NextRequest(
        'http://localhost:3000/api/v1/analytics/activity?timezone=New York'
      );

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(400);
      expect(data.error).toBe('ValidationError');
      expect(data.message).toContain('Invalid timezone parameter');
    });

    it('should return 400 for excessively long timezone', async () => {
      const longTimezone = 'A'.repeat(51);
      const request = new NextRequest(
        `http://localhost:3000/api/v1/analytics/activity?timezone=${longTimezone}`
      );

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(400);
      expect(data.error).toBe('ValidationError');
    });
  });

  describe('Missing Days Handling', () => {
    it('should fill missing days with 0 minutes', async () => {
      // Create session only for today
      const today = new Date();
      await prisma.listeningSession.create({
        data: {
          userId: testUser.id,
          storyId: testStory.id,
          startedAt: today,
          duration: 300, // 5 minutes
          completed: true,
        },
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/activity');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.data.activity).toHaveLength(7);

      // Only today should have minutes, rest should be 0
      const todayActivity = data.data.activity.find(
        (a: any) => a.date === today.toISOString().split('T')[0]
      );
      expect(todayActivity?.minutes).toBeGreaterThan(0);

      // Count days with 0 minutes
      const zeroDays = data.data.activity.filter((a: any) => a.minutes === 0);
      expect(zeroDays.length).toBe(6);
    });

    it('should return all zeros when no sessions exist', async () => {
      const request = new NextRequest('http://localhost:3000/api/v1/analytics/activity');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.data.activity).toHaveLength(7);

      // All days should have 0 minutes
      const allZero = data.data.activity.every((a: any) => a.minutes === 0);
      expect(allZero).toBe(true);
    });
  });

  describe('Daily Aggregation', () => {
    it('should aggregate multiple sessions on the same day', async () => {
      const today = new Date();
      today.setHours(10, 0, 0, 0);

      // Create 3 sessions on the same day
      await prisma.listeningSession.createMany({
        data: [
          {
            userId: testUser.id,
            storyId: testStory.id,
            startedAt: new Date(today.getTime()),
            duration: 180, // 3 minutes
            completed: true,
          },
          {
            userId: testUser.id,
            storyId: testStory.id,
            startedAt: new Date(today.getTime() + 2 * 60 * 60 * 1000), // 2 hours later
            duration: 240, // 4 minutes
            completed: true,
          },
          {
            userId: testUser.id,
            storyId: testStory.id,
            startedAt: new Date(today.getTime() + 5 * 60 * 60 * 1000), // 5 hours later
            duration: 300, // 5 minutes
            completed: false,
          },
        ],
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/activity');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);

      // Find today's activity
      const todayActivity = data.data.activity.find(
        (a: any) => a.date === today.toISOString().split('T')[0]
      );

      // Should aggregate: 180 + 240 + 300 = 720 seconds = 12 minutes
      expect(todayActivity?.minutes).toBe(12);
    });

    it('should convert seconds to minutes correctly', async () => {
      const today = new Date();

      // 150 seconds = 2.5 minutes -> should round to 3 minutes
      await prisma.listeningSession.create({
        data: {
          userId: testUser.id,
          storyId: testStory.id,
          startedAt: today,
          duration: 150,
          completed: true,
        },
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/activity');

      const response = await GET(request);
      const data = await response.json();

      const todayActivity = data.data.activity.find(
        (a: any) => a.date === today.toISOString().split('T')[0]
      );

      expect(todayActivity?.minutes).toBe(3); // Math.round(150 / 60) = 3
    });

    it('should only include sessions with duration', async () => {
      const today = new Date();

      // Create sessions with and without duration
      await prisma.listeningSession.createMany({
        data: [
          {
            userId: testUser.id,
            storyId: testStory.id,
            startedAt: today,
            duration: 300,
            completed: true,
          },
          {
            userId: testUser.id,
            storyId: testStory.id,
            startedAt: today,
            duration: null, // No duration - should be excluded
            completed: false,
          },
        ],
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/activity');

      const response = await GET(request);
      const data = await response.json();

      const todayActivity = data.data.activity.find(
        (a: any) => a.date === today.toISOString().split('T')[0]
      );

      // Should only count the session with duration: 300 seconds = 5 minutes
      expect(todayActivity?.minutes).toBe(5);
    });
  });

  describe('Date Ordering', () => {
    it('should return dates in ascending order (oldest to newest)', async () => {
      const request = new NextRequest('http://localhost:3000/api/v1/analytics/activity');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);

      const dates = data.data.activity.map((a: any) => a.date);

      // Check dates are in ascending order
      for (let i = 1; i < dates.length; i++) {
        expect(dates[i] >= dates[i - 1]).toBe(true);
      }
    });

    it('should include startDate and endDate in response', async () => {
      const request = new NextRequest('http://localhost:3000/api/v1/analytics/activity');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.data.startDate).toBeDefined();
      expect(data.data.endDate).toBeDefined();

      // startDate should be before endDate
      expect(data.data.startDate <= data.data.endDate).toBe(true);
    });
  });

  describe('Data Format', () => {
    it('should return correct data structure', async () => {
      const request = new NextRequest('http://localhost:3000/api/v1/analytics/activity');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);
      expect(data.data).toHaveProperty('range');
      expect(data.data).toHaveProperty('timezone');
      expect(data.data).toHaveProperty('startDate');
      expect(data.data).toHaveProperty('endDate');
      expect(data.data).toHaveProperty('activity');
      expect(Array.isArray(data.data.activity)).toBe(true);
    });

    it('should return dates in YYYY-MM-DD format', async () => {
      const request = new NextRequest('http://localhost:3000/api/v1/analytics/activity');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);

      // Check all dates match YYYY-MM-DD format
      const dateRegex = /^\d{4}-\d{2}-\d{2}$/;
      data.data.activity.forEach((item: any) => {
        expect(item.date).toMatch(dateRegex);
        expect(typeof item.minutes).toBe('number');
        expect(item.minutes).toBeGreaterThanOrEqual(0);
      });
    });
  });

  describe('Multi-Day Activity', () => {
    it('should track activity across multiple days correctly', async () => {
      const today = new Date();
      const yesterday = new Date(today);
      yesterday.setDate(yesterday.getDate() - 1);
      const twoDaysAgo = new Date(today);
      twoDaysAgo.setDate(twoDaysAgo.getDate() - 2);

      // Create sessions across 3 days
      await prisma.listeningSession.createMany({
        data: [
          {
            userId: testUser.id,
            storyId: testStory.id,
            startedAt: today,
            duration: 600, // 10 minutes
            completed: true,
          },
          {
            userId: testUser.id,
            storyId: testStory.id,
            startedAt: yesterday,
            duration: 900, // 15 minutes
            completed: true,
          },
          {
            userId: testUser.id,
            storyId: testStory.id,
            startedAt: twoDaysAgo,
            duration: 300, // 5 minutes
            completed: true,
          },
        ],
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/activity');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);

      // Check each day has correct minutes
      const todayDate = today.toISOString().split('T')[0];
      const yesterdayDate = yesterday.toISOString().split('T')[0];
      const twoDaysAgoDate = twoDaysAgo.toISOString().split('T')[0];

      const todayActivity = data.data.activity.find((a: any) => a.date === todayDate);
      const yesterdayActivity = data.data.activity.find((a: any) => a.date === yesterdayDate);
      const twoDaysAgoActivity = data.data.activity.find((a: any) => a.date === twoDaysAgoDate);

      expect(todayActivity?.minutes).toBe(10);
      expect(yesterdayActivity?.minutes).toBe(15);
      expect(twoDaysAgoActivity?.minutes).toBe(5);
    });
  });

  describe('Authorization', () => {
    it('should only return activity for authenticated user', async () => {
      // Create another user with sessions
      const otherUser = await prisma.user.create({
        data: {
          id: 'other-user-id',
          email: 'other@example.com',
          name: 'Other User',
        },
      });

      // Create hero for other user
      const otherHero = await prisma.hero.create({
        data: {
          userId: otherUser.id,
          name: 'Other Hero',
          age: 10,
          traits: ['curious'],
        },
      });

      const otherStory = await prisma.story.create({
        data: {
          userId: otherUser.id,
          heroId: otherHero.id,
          title: 'Other Story',
          content: 'Other content',
        },
      });

      // Create sessions for both users
      const today = new Date();
      await prisma.listeningSession.createMany({
        data: [
          {
            userId: testUser.id,
            storyId: testStory.id,
            startedAt: today,
            duration: 300,
            completed: true,
          },
          {
            userId: otherUser.id,
            storyId: otherStory.id,
            startedAt: today,
            duration: 600,
            completed: true,
          },
        ],
      });

      const request = new NextRequest('http://localhost:3000/api/v1/analytics/activity');

      const response = await GET(request);
      const data = await response.json();

      expect(response.status).toBe(200);

      // Should only see test user's activity (5 minutes, not other user's 10 minutes)
      const todayActivity = data.data.activity.find(
        (a: any) => a.date === today.toISOString().split('T')[0]
      );
      expect(todayActivity?.minutes).toBe(5);

      // Clean up (in correct order for FK constraints)
      await prisma.listeningSession.deleteMany({ where: { userId: otherUser.id } });
      await prisma.story.deleteMany({ where: { userId: otherUser.id } });
      await prisma.hero.deleteMany({ where: { userId: otherUser.id } });
      await prisma.user.delete({ where: { id: otherUser.id } });
    });
  });
});
