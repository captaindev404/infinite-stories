import { NextRequest } from 'next/server';
import { prisma } from '@/lib/prisma/client';
import { withAuth } from '@/lib/api/with-auth';
import { successResponse, errorResponse } from '@/lib/utils/api-response';
import { generateSignedUrl } from '@/lib/storage/signed-url';

/**
 * POST /api/v1/heroes/[heroId]/visual-profile/extract
 * Extract visual attributes from hero avatar using AI (GPT-4o vision)
 */
export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ heroId: string }> }
) {
  return withAuth(req, async (user) => {
    const { heroId } = await params;

    // Get the hero to verify ownership and get avatar
    const hero = await prisma.hero.findUnique({
      where: { id: heroId },
      include: { visualProfile: true },
    });

    if (!hero) {
      return errorResponse('NotFound', 'Hero not found', 404);
    }

    if (hero.userId !== user.id) {
      return errorResponse('Forbidden', 'You do not have access to this hero', 403);
    }

    // Check if hero has an avatar to analyze
    if (!hero.avatarUrl) {
      return errorResponse(
        'BadRequest',
        'Hero does not have an avatar. Generate an avatar first before extracting visual profile.',
        400
      );
    }

    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
      return errorResponse('ServerError', 'AI service not configured', 500);
    }

    // Get signed URL for the avatar image
    const avatarUrl = await generateSignedUrl(hero.avatarUrl);

    // Use GPT-4o vision to analyze the avatar and extract visual characteristics
    const extractionPrompt = `Analyze this character avatar image and extract detailed visual characteristics for maintaining consistency in future illustrations.

Character Name: ${hero.name}
Character Age: ${hero.age}

Please extract the following attributes in JSON format:
{
  "hairStyle": "description of hair style (e.g., 'curly', 'straight', 'wavy', 'short', 'long')",
  "hairColor": "hair color (e.g., 'brown', 'blonde', 'black', 'red')",
  "hairTexture": "hair texture if notable",
  "eyeColor": "eye color",
  "eyeShape": "eye shape if notable (e.g., 'round', 'almond')",
  "skinTone": "skin tone description (e.g., 'light', 'medium', 'dark', 'fair')",
  "facialFeatures": "notable facial features (e.g., 'freckles', 'dimples')",
  "bodyType": "body type for a child character",
  "height": "relative height (e.g., 'average for age', 'tall', 'short')",
  "typicalClothing": "clothing style visible in the image",
  "colorPalette": ["array of 3-5 dominant colors in the image"],
  "accessories": "any accessories (e.g., 'glasses', 'hair bow')",
  "artStyle": "art style of the image (e.g., 'watercolor', 'cartoon', 'digital illustration')",
  "visualKeywords": ["array of 5-10 visual keywords for consistent generation"],
  "canonicalPrompt": "A detailed prompt that would recreate this exact character appearance",
  "simplifiedPrompt": "A shorter prompt (under 100 words) for scene illustrations"
}

Be specific and detailed. This data will be used to maintain visual consistency across all illustrations featuring this character.`;

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model: 'gpt-4o',
        messages: [
          {
            role: 'system',
            content: 'You are an expert at analyzing character illustrations and extracting detailed visual attributes for maintaining consistency in children\'s book illustrations. Always respond with valid JSON.',
          },
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: extractionPrompt,
              },
              {
                type: 'image_url',
                image_url: {
                  url: avatarUrl,
                  detail: 'high',
                },
              },
            ],
          },
        ],
        temperature: 0.3,
        max_tokens: 1500,
        response_format: { type: 'json_object' },
      }),
    });

    if (!response.ok) {
      const error = await response.json();
      console.error('OpenAI extraction error:', error);
      return errorResponse('AIError', 'Failed to extract visual profile', 502);
    }

    const data = await response.json();
    const extractedContent = data.choices[0].message.content;

    let extractedProfile;
    try {
      extractedProfile = JSON.parse(extractedContent);
    } catch (parseError) {
      console.error('Failed to parse AI response:', extractedContent);
      return errorResponse('AIError', 'AI returned invalid response format', 502);
    }

    // Upsert the visual profile (create or update)
    const visualProfile = await prisma.heroVisualProfile.upsert({
      where: { heroId },
      create: {
        heroId,
        hairStyle: extractedProfile.hairStyle,
        hairColor: extractedProfile.hairColor,
        hairTexture: extractedProfile.hairTexture,
        eyeColor: extractedProfile.eyeColor,
        eyeShape: extractedProfile.eyeShape,
        skinTone: extractedProfile.skinTone,
        facialFeatures: extractedProfile.facialFeatures,
        bodyType: extractedProfile.bodyType,
        height: extractedProfile.height,
        age: hero.age,
        typicalClothing: extractedProfile.typicalClothing,
        colorPalette: extractedProfile.colorPalette,
        accessories: extractedProfile.accessories,
        artStyle: extractedProfile.artStyle,
        visualKeywords: extractedProfile.visualKeywords,
        canonicalPrompt: extractedProfile.canonicalPrompt,
        simplifiedPrompt: extractedProfile.simplifiedPrompt,
      },
      update: {
        hairStyle: extractedProfile.hairStyle,
        hairColor: extractedProfile.hairColor,
        hairTexture: extractedProfile.hairTexture,
        eyeColor: extractedProfile.eyeColor,
        eyeShape: extractedProfile.eyeShape,
        skinTone: extractedProfile.skinTone,
        facialFeatures: extractedProfile.facialFeatures,
        bodyType: extractedProfile.bodyType,
        height: extractedProfile.height,
        typicalClothing: extractedProfile.typicalClothing,
        colorPalette: extractedProfile.colorPalette,
        accessories: extractedProfile.accessories,
        artStyle: extractedProfile.artStyle,
        visualKeywords: extractedProfile.visualKeywords,
        canonicalPrompt: extractedProfile.canonicalPrompt,
        simplifiedPrompt: extractedProfile.simplifiedPrompt,
      },
    });

    return successResponse(
      visualProfile,
      hero.visualProfile
        ? 'Visual profile re-extracted successfully'
        : 'Visual profile extracted successfully',
      hero.visualProfile ? 200 : 201
    );
  });
}
