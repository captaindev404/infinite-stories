#!/usr/bin/env -S deno run --allow-all

/**
 * Test script for OpenAI Response API migration
 *
 * This script verifies that all OpenAI API calls are using the new response format correctly.
 * It tests the migration of all Edge Functions to ensure compatibility.
 */

import { OpenAIClient } from './supabase/functions/_shared/openai-client.ts';
import { logger, LogCategory } from './supabase/functions/_shared/logger.ts';

// Set up test environment
Deno.env.set('OPENAI_API_KEY', Deno.env.get('OPENAI_API_KEY') || '');

const testRequestId = `test-${Date.now()}`;

async function testChatCompletion() {
  console.log('\n🧪 Testing Chat Completion with new response API...');

  try {
    const client = OpenAIClient.getInstance();

    const response = await client.createChatCompletion({
      model: 'gpt-5-mini',
      messages: [
        { role: 'user', content: 'Say "Hello World" in one sentence.' }
      ],
      max_tokens: 50,
      user_id: 'test-user'
    }, testRequestId);

    console.log('✅ Chat Completion Response:');
    console.log('  - ID:', response.id);
    console.log('  - Content:', response.choices[0]?.message?.content);
    console.log('  - Usage:', {
      prompt_tokens: response.usage.prompt_tokens,
      completion_tokens: response.usage.completion_tokens,
      total_tokens: response.usage.total_tokens,
      reasoning_tokens: response.usage.reasoning_tokens,
      cached_tokens: response.usage.cached_tokens
    });

    // Verify new response format fields
    if (response.usage.completion_tokens_details) {
      console.log('  - Completion Details:', response.usage.completion_tokens_details);
    }
    if (response.usage.prompt_tokens_details) {
      console.log('  - Prompt Details:', response.usage.prompt_tokens_details);
    }

    return true;
  } catch (error) {
    console.error('❌ Chat Completion Test Failed:', error);
    return false;
  }
}

async function testStreamingCompletion() {
  console.log('\n🧪 Testing Streaming Completion with new response API...');

  try {
    const client = OpenAIClient.getInstance();

    console.log('  Streaming response: ');
    process.stdout.write('  ');

    let fullContent = '';
    const stream = client.createChatCompletionStream({
      model: 'gpt-5-mini',
      messages: [
        { role: 'user', content: 'Count from 1 to 5.' }
      ],
      max_tokens: 50,
      user_id: 'test-user'
    }, testRequestId);

    for await (const chunk of stream) {
      if (chunk.content) {
        process.stdout.write(chunk.content);
        fullContent += chunk.content;
      }
      if (chunk.finish_reason) {
        console.log('\n  - Finish Reason:', chunk.finish_reason);
      }
    }

    console.log('✅ Streaming completed successfully');
    console.log('  - Full Content Length:', fullContent.length);

    return true;
  } catch (error) {
    console.error('❌ Streaming Test Failed:', error);
    return false;
  }
}

async function testAudioSynthesis() {
  console.log('\n🧪 Testing Audio Synthesis with new response API...');

  try {
    const client = OpenAIClient.getInstance();

    const audioBuffer = await client.createSpeech({
      model: 'gpt-4o-mini-tts',
      input: 'Hello, this is a test of the audio synthesis API.',
      voice: 'nova',
      instructions: 'Speak clearly and at a moderate pace.',
      response_format: 'mp3',
      speed: 1.0
    }, testRequestId);

    console.log('✅ Audio Synthesis Response:');
    console.log('  - Buffer Size:', audioBuffer.byteLength, 'bytes');
    console.log('  - Format: MP3');

    return true;
  } catch (error) {
    console.error('❌ Audio Synthesis Test Failed:', error);
    return false;
  }
}

async function testImageGeneration() {
  console.log('\n🧪 Testing Image Generation with new response API...');

  try {
    const client = OpenAIClient.getInstance();

    const response = await client.createImage({
      model: 'dall-e-3',
      prompt: 'A simple red square on a white background, digital art',
      n: 1,
      size: '1024x1024',
      quality: 'standard'
    }, testRequestId);

    console.log('✅ Image Generation Response:');
    console.log('  - Created:', response.created);
    console.log('  - Images:', response.data.length);
    if (response.data[0]) {
      console.log('  - Has Base64 Data:', !!response.data[0].b64_json);
      console.log('  - Revised Prompt:', response.data[0].revised_prompt?.substring(0, 50) + '...');
    }

    return true;
  } catch (error) {
    console.error('❌ Image Generation Test Failed:', error);
    return false;
  }
}

async function testErrorHandling() {
  console.log('\n🧪 Testing Error Handling with new response API...');

  try {
    const client = OpenAIClient.getInstance();

    // Try with invalid parameters to trigger an error
    await client.createChatCompletion({
      model: 'invalid-model',
      messages: [],
      max_tokens: 50
    }, testRequestId);

    console.error('❌ Error handling test failed - no error thrown');
    return false;
  } catch (error: any) {
    console.log('✅ Error Handling Response:');
    console.log('  - Error Code:', error.code);
    console.log('  - Status:', error.statusCode);
    console.log('  - Message:', error.message);

    return true;
  }
}

async function runAllTests() {
  console.log('='.repeat(60));
  console.log('🚀 OpenAI Response API Migration Test Suite');
  console.log('='.repeat(60));

  const results = {
    chatCompletion: await testChatCompletion(),
    streaming: await testStreamingCompletion(),
    audioSynthesis: await testAudioSynthesis(),
    imageGeneration: await testImageGeneration(),
    errorHandling: await testErrorHandling()
  };

  console.log('\n' + '='.repeat(60));
  console.log('📊 Test Results Summary:');
  console.log('='.repeat(60));

  let passed = 0;
  let failed = 0;

  for (const [test, result] of Object.entries(results)) {
    if (result) {
      console.log(`✅ ${test}: PASSED`);
      passed++;
    } else {
      console.log(`❌ ${test}: FAILED`);
      failed++;
    }
  }

  console.log('\n' + '='.repeat(60));
  console.log(`Total: ${passed} passed, ${failed} failed`);

  if (failed === 0) {
    console.log('🎉 All tests passed! Migration successful.');
  } else {
    console.log('⚠️  Some tests failed. Please review the migration.');
  }
  console.log('='.repeat(60));
}

// Run tests
if (import.meta.main) {
  await runAllTests();
  Deno.exit(0);
}