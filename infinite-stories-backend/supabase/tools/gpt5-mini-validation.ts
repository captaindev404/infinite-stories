/**
 * GPT-5-mini Validation Tests
 *
 * This test suite validates the GPT-5-mini implementation with official OpenAI SDK
 */

import { assertEquals, assertExists, assert } from "https://deno.land/std@0.210.0/assert/mod.ts";
import { delay } from "https://deno.land/std@0.210.0/async/delay.ts";

import { openai, MODELS, getOptimalParams } from '../functions/_shared/openai-client.ts';
import { contentFilter } from '../functions/_shared/content-filter.ts';

/**
 * Test data for validation
 */
const TEST_DATA = {
  hero: {
    id: 'test-hero-123',
    name: 'Luna',
    primary_trait: 'brave',
    secondary_trait: 'kind',
    appearance: 'curly brown hair, bright green eyes'
  },
  simplePrompt: 'Tell a short bedtime story about a brave rabbit.',
  storyPrompt: 'Create a magical bedtime story about Luna the brave rabbit who helps forest animals.',
  problematicContent: 'The child was alone and scared in the dark forest.',
  languages: ['en', 'es', 'fr', 'de', 'it'],
  voices: ['coral', 'nova', 'fable', 'alloy', 'echo', 'onyx', 'shimmer']
};

/**
 * Test OpenAI Client with GPT-5-mini
 */
Deno.test("OpenAI Client - GPT-5-mini Integration", async (t) => {
  await t.step("Client initialization", () => {
    assertExists(openai);
    console.log('✓ OpenAI client initialized with GPT-5-mini');
  });

  await t.step("Basic GPT-5-mini completion", async () => {
    const startTime = Date.now();

    const response = await openai.createChatCompletion({
      messages: [
        { role: 'user', content: TEST_DATA.simplePrompt }
      ],
      max_tokens: 100,
      temperature: 0.7,
      reasoning_effort: 'low',
      text_verbosity: 'medium'
    });

    const responseTime = Date.now() - startTime;

    assertExists(response.choices[0].message.content);
    assert(response.choices[0].message.content.length > 50);
    assert(response.usage.total_tokens > 0);
    assertEquals(response.choices[0].finish_reason, 'stop');

    console.log(`✓ GPT-5-mini completion: ${responseTime}ms, ${response.usage.total_tokens} tokens`);
    console.log(`✓ Story preview: ${response.choices[0].message.content.substring(0, 100)}...`);
  });

  await t.step("Optimized parameters for story generation", async () => {
    const params = getOptimalParams('story_generation');
    const startTime = Date.now();

    const response = await openai.createChatCompletion({
      messages: [
        {
          role: 'system',
          content: 'You are a master storyteller for children.'
        },
        {
          role: 'user',
          content: TEST_DATA.storyPrompt
        }
      ],
      max_tokens: params.max_tokens,
      temperature: params.temperature,
      reasoning_effort: params.reasoning_effort,
      text_verbosity: params.text_verbosity
    });

    const responseTime = Date.now() - startTime;

    assertExists(response.choices[0].message.content);
    assert(response.choices[0].message.content.length > 200);
    assert(response.choices[0].message.content.includes('Luna'));

    console.log(`✓ Optimized story generation: ${responseTime}ms`);
    console.log(`✓ Parameters used:`, params);
    console.log(`✓ Reasoning tokens: ${response.usage.reasoning_tokens || 0}`);
  });

  await t.step("Scene extraction with high reasoning", async () => {
    const params = getOptimalParams('scene_extraction');

    const response = await openai.createChatCompletion({
      messages: [
        {
          role: 'system',
          content: 'You are an expert at scene analysis. Return only JSON.'
        },
        {
          role: 'user',
          content: 'Extract 2 scenes from this story: "Luna walked into the magical forest with her rabbit friends. They discovered a hidden treasure that helped all the forest animals."'
        }
      ],
      max_tokens: params.max_tokens,
      temperature: params.temperature,
      reasoning_effort: params.reasoning_effort,
      text_verbosity: params.text_verbosity,
      response_format: { type: 'json_object' }
    });

    assertExists(response.choices[0].message.content);

    const parsed = JSON.parse(response.choices[0].message.content);
    assertExists(parsed);

    console.log('✓ Scene extraction with high reasoning working');
    console.log(`✓ Extracted scenes:`, parsed);
  });
});

/**
 * Test content filtering with GPT-5-mini
 */
Deno.test("Content Filtering - GPT-5-mini", async (t) => {
  await t.step("Basic content filtering", async () => {
    const result = await contentFilter.filterContent(
      TEST_DATA.problematicContent,
      false
    );

    assert(!result.isClean || result.changesApplied.length > 0);
    assert(!result.filteredContent.toLowerCase().includes('alone'));
    assert(!result.filteredContent.toLowerCase().includes('scared'));

    console.log('✓ Basic filtering working');
    console.log(`✓ Changes: ${result.changesApplied.length}`);
  });

  await t.step("AI content filtering with GPT-5-mini", async () => {
    const result = await contentFilter.filterContent(
      TEST_DATA.problematicContent,
      true,
      'test-filter-1'
    );

    assert(result.filteredContent.length > 0);
    assert(!result.filteredContent.toLowerCase().includes('alone'));
    assert(result.filteredContent.toLowerCase().includes('friend') ||
           result.filteredContent.toLowerCase().includes('companion'));

    console.log('✓ AI filtering with GPT-5-mini working');
    console.log(`✓ Filtered content: "${result.filteredContent}"`);
  });

  await t.step("Story prompt filtering", async () => {
    const filtered = await contentFilter.filterStoryPrompt(
      'Create a story about a child who is alone in a scary place',
      'test-filter-2'
    );

    assert(filtered.length > 0);
    assert(!filtered.toLowerCase().includes('alone'));
    assert(!filtered.toLowerCase().includes('scary'));

    console.log('✓ Story prompt filtering working');
  });

  await t.step("Image prompt filtering", async () => {
    const filtered = await contentFilter.filterImagePrompt(
      'A child standing alone in a dark forest',
      'test-filter-3'
    );

    assert(filtered.length > 0);
    assert(!filtered.toLowerCase().includes('alone'));
    assert(!filtered.toLowerCase().includes('dark'));
    assert(filtered.toLowerCase().includes('bright') || filtered.toLowerCase().includes('cheerful'));

    console.log('✓ Image prompt filtering working');
  });
});

/**
 * Test TTS and Image generation (models unchanged)
 */
Deno.test("TTS and Image Generation", async (t) => {
  await t.step("TTS model validation", async () => {
    assertEquals(MODELS.TTS, 'tts-1-hd');
    console.log('✓ TTS model unchanged: tts-1-hd');
  });

  await t.step("Image model validation", async () => {
    assertEquals(MODELS.IMAGE, 'dall-e-3');
    console.log('✓ Image model unchanged: dall-e-3');
  });

  await t.step("OpenAI connection test", async () => {
    const connected = await openai.testConnection();
    assert(connected, 'Should be able to connect to OpenAI API');
    console.log('✓ OpenAI API connection successful');
  });
});

/**
 * Test parameter optimization
 */
Deno.test("GPT-5-mini Parameter Optimization", async (t) => {
  await t.step("Story generation parameters", () => {
    const params = getOptimalParams('story_generation');

    assertEquals(params.reasoning_effort, 'medium');
    assertEquals(params.text_verbosity, 'high');
    assertEquals(params.temperature, 0.7);
    assertEquals(params.max_tokens, 3000);

    console.log('✓ Story generation parameters optimized:', params);
  });

  await t.step("Scene extraction parameters", () => {
    const params = getOptimalParams('scene_extraction');

    assertEquals(params.reasoning_effort, 'high');
    assertEquals(params.text_verbosity, 'medium');
    assertEquals(params.temperature, 0.3);
    assertEquals(params.max_tokens, 2000);

    console.log('✓ Scene extraction parameters optimized:', params);
  });

  await t.step("Content filtering parameters", () => {
    const params = getOptimalParams('content_filtering');

    assertEquals(params.reasoning_effort, 'low');
    assertEquals(params.text_verbosity, 'low');
    assertEquals(params.temperature, 0.2);
    assertEquals(params.max_tokens, 500);

    console.log('✓ Content filtering parameters optimized for speed:', params);
  });
});

/**
 * Performance benchmark
 */
Deno.test("Performance Benchmark - GPT-5-mini", async (t) => {
  await t.step("Response time benchmark", async () => {
    const iterations = 3;
    const times: number[] = [];
    const tokenCounts: number[] = [];

    for (let i = 0; i < iterations; i++) {
      const startTime = Date.now();

      const response = await openai.createChatCompletion({
        messages: [
          { role: 'user', content: `${TEST_DATA.simplePrompt} (Test ${i + 1})` }
        ],
        max_tokens: 200,
        reasoning_effort: 'medium'
      });

      const responseTime = Date.now() - startTime;
      times.push(responseTime);
      tokenCounts.push(response.usage.total_tokens);

      await delay(1000); // Rate limit protection
    }

    const avgTime = times.reduce((a, b) => a + b, 0) / times.length;
    const avgTokens = tokenCounts.reduce((a, b) => a + b, 0) / tokenCounts.length;

    console.log(`✓ GPT-5-mini performance: ${avgTime.toFixed(0)}ms avg, ${avgTokens.toFixed(0)} tokens avg`);
    console.log(`✓ Individual times: ${times.map(t => `${t}ms`).join(', ')}`);

    // GPT-5-mini should be reasonably fast
    assert(avgTime < 5000, 'Average response time should be under 5 seconds');
  });
});

/**
 * Error handling validation
 */
Deno.test("Error Handling Validation", async (t) => {
  await t.step("Invalid request error", async () => {
    try {
      await openai.createChatCompletion({
        messages: [], // Invalid: empty messages
        max_tokens: 10
      });
      assert(false, 'Should have thrown an error');
    } catch (error) {
      assert(error.code === 'INVALID_REQUEST' || error.message.includes('Invalid'));
      console.log('✓ Invalid request error handling working');
    }
  });

  await t.step("Request count tracking", () => {
    const initialCount = openai.getRequestCount();
    assert(typeof initialCount === 'number');
    assert(initialCount >= 0);
    console.log(`✓ Request count tracking: ${initialCount} requests`);
  });
});

/**
 * Integration test
 */
Deno.test("Complete Story Generation Workflow", async (t) => {
  await t.step("End-to-end story creation", async () => {
    console.log('🧪 Testing complete story generation workflow...');

    // 1. Generate story with GPT-5-mini
    const storyParams = getOptimalParams('story_generation');
    const storyResponse = await openai.createChatCompletion({
      messages: [
        {
          role: 'system',
          content: 'Create a short bedtime story for children.'
        },
        {
          role: 'user',
          content: `Write a 150-word story about ${TEST_DATA.hero.name} going on a magical adventure with animal friends.`
        }
      ],
      max_tokens: storyParams.max_tokens,
      temperature: storyParams.temperature,
      reasoning_effort: storyParams.reasoning_effort,
      text_verbosity: storyParams.text_verbosity
    });

    assertExists(storyResponse.choices[0].message.content);
    const storyContent = storyResponse.choices[0].message.content;
    assert(storyContent.includes(TEST_DATA.hero.name));

    console.log(`✓ Story generated: ${storyContent.length} characters`);

    // 2. Extract scenes with high reasoning
    const sceneParams = getOptimalParams('scene_extraction');
    const sceneResponse = await openai.createChatCompletion({
      messages: [
        {
          role: 'system',
          content: 'Extract key scenes from stories and return as JSON.'
        },
        {
          role: 'user',
          content: `Extract 2 scenes from this story: ${storyContent.substring(0, 500)}`
        }
      ],
      max_tokens: sceneParams.max_tokens,
      temperature: sceneParams.temperature,
      reasoning_effort: sceneParams.reasoning_effort,
      text_verbosity: sceneParams.text_verbosity,
      response_format: { type: 'json_object' }
    });

    assertExists(sceneResponse.choices[0].message.content);
    const scenes = JSON.parse(sceneResponse.choices[0].message.content);
    assertExists(scenes);

    console.log(`✓ Scenes extracted successfully`);

    // 3. Filter content with fast filtering
    const filteredStory = await contentFilter.filterContent(storyContent, true, 'test-workflow-1');
    assert(filteredStory.filteredContent.length > 0);

    console.log(`✓ Content filtered: ${filteredStory.changesApplied.length} changes`);

    console.log('✅ Complete workflow test passed');
  });
});

/**
 * Run validation if this file is executed directly
 */
if (import.meta.main) {
  console.log('🧪 Starting GPT-5-mini Validation Tests...');
  console.log('==========================================');

  console.log(`📋 Test Configuration:`);
  console.log(`  Model: ${MODELS.CHAT}`);
  console.log(`  TTS Model: ${MODELS.TTS}`);
  console.log(`  Image Model: ${MODELS.IMAGE}`);
  console.log('');

  // Log parameter configurations
  const storyParams = getOptimalParams('story_generation');
  const sceneParams = getOptimalParams('scene_extraction');
  const filterParams = getOptimalParams('content_filtering');

  console.log('📊 Parameter Configurations:');
  console.log(`  Story Generation:`, storyParams);
  console.log(`  Scene Extraction:`, sceneParams);
  console.log(`  Content Filtering:`, filterParams);
  console.log('');
}
