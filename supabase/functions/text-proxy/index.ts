import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { toB64 } from 'https://deno.land/std@0.224.0/encoding/base64.ts';
import { corsHeaders } from '../_shared/cors.ts';

// Ensure your Gemini API Key is set in your project's secrets
const API_KEY = Deno.env.get('GEMINI_API_KEY');
if (!API_KEY) {
  throw new Error('GEMINI_API_KEY environment variable not set!');
}

const MODEL = 'gemini-1.5-flash-latest';
const API_URL =
  `https://generativelanguage.googleapis.com/v1/models/${MODEL}:generateContent?key=${API_KEY}`;

function buildSystemInstruction(context_rules: any): string {
  let instruction = `You are an expert study assistant for a student studying "${
    context_rules.title || 'a given subject'
  }". Your primary goal is to help them understand the material. You must strictly follow all instructions.`;

  switch (context_rules.result_format) {
    case 'Summarize':
      instruction += ` The user requires a summary. Your response MUST be a concise and easy-to-understand summary.`;
      break;
    case 'Generate Q&A':
      instruction += ` The user requires questions and answers. Your response MUST be in a Q&A format.`;
      break;
    case 'Code for me':
      instruction += ` The user requires code. Your response MUST include a functional code block.`;
      break;
    case 'Solve my assignment':
      instruction += ` The user wants help with an assignment. Your response MUST provide a step-by-step solution.`;
      break;
    case 'Explain topic/Question':
      instruction += ` The user requires a detailed explanation. Your response MUST be a comprehensive and clear explanation.`;
      break;
    default:
      instruction += ` Respond helpfully to the user's prompt based on all provided context.`;
      break;
  }

  if (context_rules.more_context) {
    instruction += ` CRITICAL: You must also follow these additional user-provided rules: "${context_rules.more_context}".`;
  }

  instruction += ` Analyze the entire chat history and all attached images to inform your response.`;
  return instruction;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const {
      prompt = '',
      chat_history = [],
      attachments = {},
      context_rules = {},
    } = await req.json();

    const systemPromptText = buildSystemInstruction(context_rules);
    
    const formattedHistory = chat_history.map((msg: any) => ({
      role: msg.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: msg.text }],
    }));
    
    const userMessageParts: any[] = [];
    if (prompt) {
        userMessageParts.push({ text: prompt });
    }

    const allImageUrls = [
      ...(attachments.context || []),
      ...(attachments.session || []),
    ];
    const uniqueImageUrls = [...new Set(allImageUrls)];

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
    
    if (userMessageParts.length === 0) {
        throw new Error("Cannot send an empty message to the AI.");
    }

    const requestBody = {
      systemInstruction: {
        parts: [{ text: systemPromptText }],
      },
      contents: [
        ...formattedHistory,
        { role: 'user', parts: userMessageParts },
      ],
    };

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
    const aiText =
      data.candidates?.[0]?.content?.parts?.[0]?.text ||
      'I am sorry, but I could not generate a response. Please try again.';

    return new Response(JSON.stringify({ response: aiText }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (e: any) {
    console.error('An error occurred in the Edge Function:', e);
    return new Response(JSON.stringify({ error: e.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});