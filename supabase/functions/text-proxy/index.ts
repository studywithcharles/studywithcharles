import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { toB64 } from 'https://deno.land/std@0.224.0/encoding/base64.ts';

// Ensure your Gemini API Key is set in your project's secrets
const API_KEY = Deno.env.get('GEMINI_API_KEY');
if (!API_KEY) {
  throw new Error("GEMINI_API_KEY environment variable not set!");
}

const MODEL = 'gemini-1.5-flash-latest';
// UPDATED: Using the stable v1 API endpoint
const API_URL =
  `https://generativelanguage.googleapis.com/v1/models/${MODEL}:generateContent?key=${API_KEY}`;

/**
 * Builds a detailed system instruction prompt based on the context rules provided by the app.
 * This is the core logic that forces the AI to behave as expected.
 * @param {any} context_rules - The context rules object from the Flutter app.
 * @returns {string} A detailed prompt for the AI system instruction.
 */
function buildSystemInstruction(context_rules: any): string {
  let instruction = `You are an expert study assistant for a student studying "${context_rules.title || 'a given subject'}". Your primary goal is to help them understand the material. You must strictly follow all instructions.`;

  switch (context_rules.result_format) {
    case 'Summarize':
      instruction += ` The user requires a summary. Your response MUST be a concise and easy-to-understand summary of the provided text, images, and prompt.`;
      break;
    case 'Generate Q&A':
      instruction += ` The user requires questions and answers. Your response MUST be in a Q&A format. Generate relevant questions based on the provided material and then provide clear, correct answers for each.`;
      break;
    case 'Code for me':
      instruction += ` The user requires code. Your response MUST include a functional code block in the appropriate language. Explain the code clearly.`;
      break;
    case 'Solve my assignment':
      instruction += ` The user wants help with an assignment. Your response MUST provide a step-by-step solution. Break down the problem, show your work, and explain the reasoning behind each step.`;
      break;
    case 'Explain topic/Question':
      instruction += ` The user requires a detailed explanation. Your response MUST be a comprehensive and clear explanation of the topic or question provided. Use analogies and simple terms where possible.`;
      break;
    default:
      instruction += ` Respond helpfully to the user's prompt based on all provided context.`;
      break;
  }

  if (context_rules.more_context) {
    instruction += ` CRITICAL: You must also follow these additional user-provided rules: "${context_rules.more_context}".`;
  }
  
  instruction += ` Analyze the entire chat history and all attached images to inform your response.`

  return instruction;
}


serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const {
      prompt,
      chat_history,
      attachments,
      context_rules,
    } = await req.json();

    // 1. BUILD THE DYNAMIC SYSTEM INSTRUCTION FROM CONTEXT RULES
    const systemPromptText = buildSystemInstruction(context_rules);

    // 2. FORMAT THE CHAT HISTORY
    // Gemini expects the role 'assistant' to be 'model'.
    const formattedHistory = chat_history.map((msg: any) => ({
      role: msg.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: msg.text }],
    }));

    // 3. PREPARE THE NEW USER MESSAGE (TEXT + IMAGES)
    const userMessageParts: any[] = [{ text: prompt }];

    const allImageUrls = [
      ...(attachments.context || []),
      ...(attachments.session || []),
    ];
    const uniqueImageUrls = [...new Set(allImageUrls)];

    // Fetch each image, convert it to base64, and add it to the message parts
    for (const url of uniqueImageUrls) {
      try {
        const imageRes = await fetch(url);
        if (imageRes.ok) {
          const mimeType = imageRes.headers.get('Content-Type') || 'image/jpeg';
          const imageBuffer = await imageRes.arrayBuffer();
          const imageB64 = toB64(imageBuffer);

          userMessageParts.push({
            inlineData: { mimeType, data: imageB64 },
          });
        }
      } catch (e) {
        console.error(`Failed to fetch or process image ${url}:`, e);
      }
    }

    // 4. CONSTRUCT THE FINAL REQUEST BODY FOR GEMINI (using v1 format)
    const requestBody = {
      // The v1 API expects systemInstruction to be an object with a parts array
      systemInstruction: {
        parts: [{ text: systemPromptText }],
      },
      contents: [
        ...formattedHistory,
        { role: 'user', parts: userMessageParts },
      ],
    };

    // 5. CALL THE GEMINI API
    const res = await fetch(API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody),
    });

    if (!res.ok) {
        const errorBody = await res.text();
        console.error('Gemini API Error:', errorBody);
        throw new Error(`API request failed with status ${res.status}: ${errorBody}`);
    }

    const data = await res.json();
    
    // Safely access the response text with optional chaining
    const aiText = data.candidates?.[0]?.content?.parts?.[0]?.text ||
      'I am sorry, but I could not generate a response. Please try again.';

    // 6. RETURN THE RESPONSE TO THE FLUTTER APP
    return new Response(JSON.stringify({ response: aiText }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (e: any) {
    console.error('An error occurred in the Edge Function:', e);
    return new Response(JSON.stringify({ error: e.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500, // Use 500 for internal server errors
    });
  }
});