import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { GET } from '../route';
import { NextRequest } from 'next/server';
import { prisma } from '@/lib/prisma/client';

// Mock authentication
vi.mock('@/lib/auth/session', () => ({
  requireAuth: vi.fn(),
}));

// Mock signed URL helper
vi.mock('@/lib/storage/signed-url', () => ({
  signHeroUrls: vi.fn((hero) => Promise.resolve({
    ...hero,
    avatarUrl: hero.avatarUrl ? `signed:${hero.avatarUrl}` : null,
  })),
}));

import { requireAuth } from '@/lib/auth/session';

const mockRequireAuth = requireAuth as any;

describe('GET /api/v1/analytics/heroes', () => {
  const mockUserId = 'test-user-id-heroes';
  const mockHeroId1 = 'hero-1';
  const mockHeroId2 = 'hero-2';
  const mockHeroId3 = 'hero-3';

  beforeEach(async () => {
    // Reset all mocks
    vi.clearAllMocks();

    // Default auth mock - authenticated user
    mockRequireAuth.mockResolvedValue({ id: mockUserId });

    // Clean up any existing test data before each test
    await prisma.listeningSession.deleteMany({ where: { userId: mockUserId } });
    await prisma.story.deleteMany({ where: { userId: mockUserId } });
    await prisma.hero.deleteMany({ where: { userId: mockUserId } });
    await prisma.user.deleteMany({ where: { id: mockUserId } });
  });

  afterEach(async () => {
    // Clean up test data after each test
    await prisma.listeningSession.deleteMany({ where: { userId: mockUserId } });
    await prisma.story.deleteMany({ where: { userId: mockUserId } });
    await prisma.hero.deleteMany({ where: { userId: mockUserId } });
    await prisma.user.deleteMany({ where: { id: mockUserId } });
  });

  it('should return 401 if user is not authenticated', async () => {
    mockRequireAuth.mockResolvedValue(null);

    const req = new NextRequest('http://localhost:3000/api/v1/analytics/heroes');
    const response = await GET(req);
    const data = await response.json();

    expect(response.status).toBe(401);
    expect(data.error).toBe('Unauthorized');
  });

  it('should return empty array when user has no heroes', async () => {
    // Create user
    await prisma.user.create({
      data: {
        id: mockUserId,
        email: 'test-heroes@example.com',
      },
    });

    const req = new NextRequest('http://localhost:3000/api/v1/analytics/heroes');
    const response = await GET(req);
    const data = await response.json();

    expect(response.status).toBe(200);
    expect(data.data.heroes).toEqual([]);
  });

  it('should return hero analytics with story counts', async () => {
    // Create user
    await prisma.user.create({
      data: {
        id: mockUserId,
        email: 'test-heroes@example.com',
      },
    });

    // Create heroes
    await prisma.hero.createMany({
      data: [
        {
          id: mockHeroId1,
          userId: mockUserId,
          name: 'Luna',
          age: 7,
          traits: ['brave', 'curious'],
          avatarUrl: 'https://example.com/luna.png',
        },
        {
          id: mockHeroId2,
          userId: mockUserId,
          name: 'Max',
          age: 8,
          traits: ['adventurous'],
          avatarUrl: 'https://example.com/max.png',
        },
      ],
    });

    // Create stories
    await prisma.story.createMany({
      data: [
        {
          userId: mockUserId,
          heroId: mockHeroId1,
          title: 'Luna Adventure 1',
          content: 'Story content',
        },
        {
          userId: mockUserId,
          heroId: mockHeroId1,
          title: 'Luna Adventure 2',
          content: 'Story content',
        },
        {
          userId: mockUserId,
          heroId: mockHeroId2,
          title: 'Max Adventure 1',
          content: 'Story content',
        },
      ],
    });

    const req = new NextRequest('http://localhost:3000/api/v1/analytics/heroes');
    const response = await GET(req);
    const data = await response.json();

    expect(response.status).toBe(200);
    expect(data.data.heroes).toHaveLength(2);

    // Find Luna's analytics
    const lunaAnalytics = data.data.heroes.find(
      (h: any) => h.heroName === 'Luna'
    );
    expect(lunaAnalytics).toBeDefined();
    expect(lunaAnalytics.heroId).toBe(mockHeroId1);
    expect(lunaAnalytics.storiesCount).toBe(2);
    expect(lunaAnalytics.avatarUrl).toBe('signed:https://example.com/luna.png');

    // Find Max's analytics
    const maxAnalytics = data.data.heroes.find(
      (h: any) => h.heroName === 'Max'
    );
    expect(maxAnalytics).toBeDefined();
    expect(maxAnalytics.heroId).toBe(mockHeroId2);
    expect(maxAnalytics.storiesCount).toBe(1);
    expect(maxAnalytics.avatarUrl).toBe('signed:https://example.com/max.png');
  });

  it('should calculate total listening minutes per hero', async () => {
    // Create user
    await prisma.user.create({
      data: {
        id: mockUserId,
        email: 'test-heroes@example.com',
      },
    });

    // Create hero
    await prisma.hero.create({
      data: {
        id: mockHeroId1,
        userId: mockUserId,
        name: 'Luna',
        age: 7,
        traits: ['brave'],
      },
    });

    // Create story
    const story = await prisma.story.create({
      data: {
        userId: mockUserId,
        heroId: mockHeroId1,
        title: 'Luna Adventure',
        content: 'Story content',
        audioDuration: 300, // 5 minutes
      },
    });

    // Create listening sessions
    await prisma.listeningSession.createMany({
      data: [
        {
          userId: mockUserId,
          storyId: story.id,
          duration: 180, // 3 minutes
          completed: true,
        },
        {
          userId: mockUserId,
          storyId: story.id,
          duration: 240, // 4 minutes
          completed: true,
        },
      ],
    });

    const req = new NextRequest('http://localhost:3000/api/v1/analytics/heroes');
    const response = await GET(req);
    const data = await response.json();

    expect(response.status).toBe(200);
    expect(data.data.heroes).toHaveLength(1);

    const lunaAnalytics = data.data.heroes[0];
    expect(lunaAnalytics.heroName).toBe('Luna');
    expect(lunaAnalytics.totalListeningMinutes).toBe(7); // (180 + 240) / 60 = 7 minutes
  });

  it('should mark the hero with most listening time as isMostActive', async () => {
    // Create user
    await prisma.user.create({
      data: {
        id: mockUserId,
        email: 'test-heroes@example.com',
      },
    });

    // Create heroes
    await prisma.hero.createMany({
      data: [
        {
          id: mockHeroId1,
          userId: mockUserId,
          name: 'Luna',
          age: 7,
          traits: ['brave'],
        },
        {
          id: mockHeroId2,
          userId: mockUserId,
          name: 'Max',
          age: 8,
          traits: ['adventurous'],
        },
        {
          id: mockHeroId3,
          userId: mockUserId,
          name: 'Stella',
          age: 6,
          traits: ['creative'],
        },
      ],
    });

    // Create stories
    const story1 = await prisma.story.create({
      data: {
        userId: mockUserId,
        heroId: mockHeroId1,
        title: 'Luna Adventure',
        content: 'Story content',
      },
    });

    const story2 = await prisma.story.create({
      data: {
        userId: mockUserId,
        heroId: mockHeroId2,
        title: 'Max Adventure',
        content: 'Story content',
      },
    });

    const story3 = await prisma.story.create({
      data: {
        userId: mockUserId,
        heroId: mockHeroId3,
        title: 'Stella Adventure',
        content: 'Story content',
      },
    });

    // Create listening sessions - Max has most listening time
    await prisma.listeningSession.createMany({
      data: [
        // Luna: 3 minutes
        {
          userId: mockUserId,
          storyId: story1.id,
          duration: 180,
          completed: true,
        },
        // Max: 10 minutes (most active)
        {
          userId: mockUserId,
          storyId: story2.id,
          duration: 600,
          completed: true,
        },
        // Stella: 5 minutes
        {
          userId: mockUserId,
          storyId: story3.id,
          duration: 300,
          completed: true,
        },
      ],
    });

    const req = new NextRequest('http://localhost:3000/api/v1/analytics/heroes');
    const response = await GET(req);
    const data = await response.json();

    expect(response.status).toBe(200);
    expect(data.data.heroes).toHaveLength(3);

    // Find each hero
    const lunaAnalytics = data.data.heroes.find(
      (h: any) => h.heroName === 'Luna'
    );
    const maxAnalytics = data.data.heroes.find(
      (h: any) => h.heroName === 'Max'
    );
    const stellaAnalytics = data.data.heroes.find(
      (h: any) => h.heroName === 'Stella'
    );

    // Only Max should be marked as most active
    expect(lunaAnalytics.isMostActive).toBe(false);
    expect(maxAnalytics.isMostActive).toBe(true);
    expect(stellaAnalytics.isMostActive).toBe(false);

    // Verify listening times
    expect(lunaAnalytics.totalListeningMinutes).toBe(3);
    expect(maxAnalytics.totalListeningMinutes).toBe(10);
    expect(stellaAnalytics.totalListeningMinutes).toBe(5);
  });

  it('should handle heroes with no stories or listening sessions', async () => {
    // Create user
    await prisma.user.create({
      data: {
        id: mockUserId,
        email: 'test-heroes@example.com',
      },
    });

    // Create hero with no stories
    await prisma.hero.create({
      data: {
        id: mockHeroId1,
        userId: mockUserId,
        name: 'Luna',
        age: 7,
        traits: ['brave'],
        avatarUrl: null,
      },
    });

    const req = new NextRequest('http://localhost:3000/api/v1/analytics/heroes');
    const response = await GET(req);
    const data = await response.json();

    expect(response.status).toBe(200);
    expect(data.data.heroes).toHaveLength(1);

    const lunaAnalytics = data.data.heroes[0];
    expect(lunaAnalytics.heroName).toBe('Luna');
    expect(lunaAnalytics.storiesCount).toBe(0);
    expect(lunaAnalytics.totalListeningMinutes).toBe(0);
    expect(lunaAnalytics.isMostActive).toBe(false);
    expect(lunaAnalytics.avatarUrl).toBeNull();
  });

  it('should not mark any hero as most active when all have zero listening time', async () => {
    // Create user
    await prisma.user.create({
      data: {
        id: mockUserId,
        email: 'test-heroes@example.com',
      },
    });

    // Create heroes with stories but no listening sessions
    await prisma.hero.createMany({
      data: [
        {
          id: mockHeroId1,
          userId: mockUserId,
          name: 'Luna',
          age: 7,
          traits: ['brave'],
        },
        {
          id: mockHeroId2,
          userId: mockUserId,
          name: 'Max',
          age: 8,
          traits: ['adventurous'],
        },
      ],
    });

    await prisma.story.createMany({
      data: [
        {
          userId: mockUserId,
          heroId: mockHeroId1,
          title: 'Luna Adventure',
          content: 'Story content',
        },
        {
          userId: mockUserId,
          heroId: mockHeroId2,
          title: 'Max Adventure',
          content: 'Story content',
        },
      ],
    });

    const req = new NextRequest('http://localhost:3000/api/v1/analytics/heroes');
    const response = await GET(req);
    const data = await response.json();

    expect(response.status).toBe(200);
    expect(data.data.heroes).toHaveLength(2);

    // Neither should be marked as most active when both have 0 listening time
    const lunaAnalytics = data.data.heroes.find(
      (h: any) => h.heroName === 'Luna'
    );
    const maxAnalytics = data.data.heroes.find(
      (h: any) => h.heroName === 'Max'
    );

    expect(lunaAnalytics.isMostActive).toBe(false);
    expect(maxAnalytics.isMostActive).toBe(false);
    expect(lunaAnalytics.totalListeningMinutes).toBe(0);
    expect(maxAnalytics.totalListeningMinutes).toBe(0);
  });

  it('should correctly aggregate listening time across multiple stories per hero', async () => {
    // Create user
    await prisma.user.create({
      data: {
        id: mockUserId,
        email: 'test-heroes@example.com',
      },
    });

    // Create hero
    await prisma.hero.create({
      data: {
        id: mockHeroId1,
        userId: mockUserId,
        name: 'Luna',
        age: 7,
        traits: ['brave'],
      },
    });

    // Create multiple stories
    const story1 = await prisma.story.create({
      data: {
        userId: mockUserId,
        heroId: mockHeroId1,
        title: 'Luna Adventure 1',
        content: 'Story content',
      },
    });

    const story2 = await prisma.story.create({
      data: {
        userId: mockUserId,
        heroId: mockHeroId1,
        title: 'Luna Adventure 2',
        content: 'Story content',
      },
    });

    // Create listening sessions for both stories
    await prisma.listeningSession.createMany({
      data: [
        {
          userId: mockUserId,
          storyId: story1.id,
          duration: 120, // 2 minutes
          completed: true,
        },
        {
          userId: mockUserId,
          storyId: story1.id,
          duration: 180, // 3 minutes
          completed: true,
        },
        {
          userId: mockUserId,
          storyId: story2.id,
          duration: 240, // 4 minutes
          completed: true,
        },
      ],
    });

    const req = new NextRequest('http://localhost:3000/api/v1/analytics/heroes');
    const response = await GET(req);
    const data = await response.json();

    expect(response.status).toBe(200);
    expect(data.data.heroes).toHaveLength(1);

    const lunaAnalytics = data.data.heroes[0];
    expect(lunaAnalytics.heroName).toBe('Luna');
    expect(lunaAnalytics.storiesCount).toBe(2);
    expect(lunaAnalytics.totalListeningMinutes).toBe(9); // (120 + 180 + 240) / 60 = 9 minutes
  });
});
