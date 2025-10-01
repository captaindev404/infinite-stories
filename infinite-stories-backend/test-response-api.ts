#!/usr/bin/env -S deno run --allow-net --allow-env --allow-read

/**
 * Test script for OpenAI Response API implementation
 * Tests both GPT-5 (Response API) and non-GPT-5 (traditional API) models
 */

import { OpenAIClient } from './supabase/functions/_shared/openai-client.ts';

// Colors for output
const colors = {
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  reset: '\x1b[0m',
};

function log(message: string, color: keyof typeof colors = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

async function testGPT5ResponseAPI() {
  log('\n=== Testing GPT-5 with Response API ===', 'blue');

  const client = OpenAIClient.getInstance();

  try {
    // Test 1: Basic GPT-5 completion
    log('\nTest 1: Basic GPT-5 completion', 'yellow');
    const response1 = await client.createChatCompletion({
      model: 'gpt-5-mini',
      messages: [
        { role: 'system', content: 'You are a helpful assistant.' },
        { role: 'user', content: 'Say hello in 5 words or less.' }
      ],
      max_tokens: 50,
      reasoning_effort: 'minimal',
      text_verbosity: 'low'
    });

    log(`Response: ${response1.choices[0].message.content}`, 'green');
    log(`Tokens used: ${JSON.stringify(response1.usage)}`, 'green');

    // Test 2: GPT-5 with JSON response format
    log('\nTest 2: GPT-5 with JSON response', 'yellow');
    const response2 = await client.createChatCompletion({
      model: 'gpt-5-mini',
      messages: [
        { role: 'system', content: 'You are a helpful assistant that responds in JSON.' },
        { role: 'user', content: 'List 3 colors as a JSON array with "colors" key.' }
      ],
      max_tokens: 100,
      response_format: { type: 'json_object' },
      reasoning_effort: 'low',
      text_verbosity: 'medium'
    });

    log(`Response: ${response2.choices[0].message.content}`, 'green');

    // Test 3: GPT-5 with high reasoning
    log('\nTest 3: GPT-5 with high reasoning', 'yellow');
    const response3 = await client.createChatCompletion({
      model: 'gpt-5-mini',
      messages: [
        { role: 'system', content: 'You are a math tutor.' },
        { role: 'user', content: 'What is 15% of 240?' }
      ],
      max_tokens: 150,
      reasoning_effort: 'high',
      text_verbosity: 'high'
    });

    log(`Response: ${response3.choices[0].message.content}`, 'green');
    if (response3.usage.reasoning_tokens) {
      log(`Reasoning tokens: ${response3.usage.reasoning_tokens}`, 'green');
    }

    log('\n✅ GPT-5 Response API tests passed!', 'green');

  } catch (error) {
    log(`\n❌ GPT-5 Response API test failed: ${error}`, 'red');
    console.error(error);
  }
}

async function testTraditionalAPI() {
  log('\n=== Testing Non-GPT-5 with Traditional API ===', 'blue');

  const client = OpenAIClient.getInstance();

  try {
    // Test 4: GPT-4o with traditional API
    log('\nTest 4: GPT-4o with traditional API', 'yellow');
    const response4 = await client.createChatCompletion({
      model: 'gpt-4o',
      messages: [
        { role: 'system', content: 'You are a helpful assistant.' },
        { role: 'user', content: 'Say hello in 5 words or less.' }
      ],
      max_tokens: 50,
      temperature: 0.7
    });

    log(`Response: ${response4.choices[0].message.content}`, 'green');
    log(`Tokens used: ${JSON.stringify(response4.usage)}`, 'green');

    // Test 5: GPT-4o-mini with temperature
    log('\nTest 5: GPT-4o-mini with temperature', 'yellow');
    const response5 = await client.createChatCompletion({
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: 'You are a creative writer.' },
        { role: 'user', content: 'Write a one-sentence story about a cat.' }
      ],
      max_tokens: 100,
      temperature: 0.9
    });

    log(`Response: ${response5.choices[0].message.content}`, 'green');

    log('\n✅ Traditional API tests passed!', 'green');

  } catch (error) {
    log(`\n❌ Traditional API test failed: ${error}`, 'red');
    console.error(error);
  }
}

async function testStreaming() {
  log('\n=== Testing Streaming ===', 'blue');

  const client = OpenAIClient.getInstance();

  try {
    // Test 6: GPT-5 streaming
    log('\nTest 6: GPT-5 streaming', 'yellow');
    process.stdout.write('Response: ');

    const stream1 = client.createChatCompletionStream({
      model: 'gpt-5-mini',
      messages: [
        { role: 'user', content: 'Count from 1 to 5.' }
      ],
      max_tokens: 50,
      reasoning_effort: 'minimal'
    });

    for await (const chunk of stream1) {
      process.stdout.write(chunk.content);
    }
    console.log('');

    // Test 7: GPT-4o streaming
    log('\nTest 7: GPT-4o streaming', 'yellow');
    process.stdout.write('Response: ');

    const stream2 = client.createChatCompletionStream({
      model: 'gpt-4o',
      messages: [
        { role: 'user', content: 'Say hello world.' }
      ],
      max_tokens: 20,
      temperature: 0.5
    });

    for await (const chunk of stream2) {
      process.stdout.write(chunk.content);
    }
    console.log('');

    log('\n✅ Streaming tests passed!', 'green');

  } catch (error) {
    log(`\n❌ Streaming test failed: ${error}`, 'red');
    console.error(error);
  }
}

async function testErrorHandling() {
  log('\n=== Testing Error Handling ===', 'blue');

  const client = OpenAIClient.getInstance();

  try {
    // Test 8: Invalid model
    log('\nTest 8: Testing invalid model error', 'yellow');
    try {
      await client.createChatCompletion({
        model: 'invalid-model-xyz',
        messages: [
          { role: 'user', content: 'test' }
        ],
        max_tokens: 10
      });
      log('❌ Should have thrown an error', 'red');
    } catch (error) {
      log(`✅ Correctly caught error: ${error.message}`, 'green');
    }

    // Test 9: Rate limit simulation (if applicable)
    log('\nTest 9: Testing with missing API key', 'yellow');
    const originalKey = Deno.env.get('OPENAI_API_KEY');
    try {
      // Temporarily set invalid key
      Deno.env.set('OPENAI_API_KEY', 'invalid-key');

      // Need to create new instance with invalid key
      const testClient = new (OpenAIClient as any)();
      await testClient.createChatCompletion({
        model: 'gpt-5-mini',
        messages: [
          { role: 'user', content: 'test' }
        ],
        max_tokens: 10
      });
      log('❌ Should have thrown an error', 'red');
    } catch (error) {
      log(`✅ Correctly caught auth error: ${error.message}`, 'green');
    } finally {
      // Restore original key
      if (originalKey) {
        Deno.env.set('OPENAI_API_KEY', originalKey);
      }
    }

    log('\n✅ Error handling tests passed!', 'green');

  } catch (error) {
    log(`\n❌ Error handling test failed: ${error}`, 'red');
    console.error(error);
  }
}

async function main() {
  log('🚀 Starting OpenAI Response API Tests', 'blue');
  log('=====================================', 'blue');

  // Check for API key
  if (!Deno.env.get('OPENAI_API_KEY')) {
    log('\n❌ Error: OPENAI_API_KEY environment variable is not set', 'red');
    log('Please set it using: export OPENAI_API_KEY=your_api_key', 'yellow');
    Deno.exit(1);
  }

  // Run all tests
  await testGPT5ResponseAPI();
  await testTraditionalAPI();
  await testStreaming();
  await testErrorHandling();

  log('\n=====================================', 'blue');
  log('✨ All tests completed!', 'green');
}

// Run tests
if (import.meta.main) {
  main().catch(console.error);
}