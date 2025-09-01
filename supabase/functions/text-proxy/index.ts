// index.ts
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { encodeBase64 } from 'https://deno.land/std@0.224.0/encoding/base64.ts';
import { corsHeaders } from '../_shared/cors.ts';

const API_KEY = Deno.env.get('GEMINI_API_KEY');
const MODEL = 'gemini-1.5-flash-latest';
const API_URL = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${API_KEY}`;

function abortableFetch(url: string, opts: RequestInit = {}, timeoutMs = 5000) {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeoutMs);
  const combined = { ...opts, signal: controller.signal };
  return fetch(url, combined).finally(() => clearTimeout(id));
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    if (!API_KEY) {
      throw new Error('GEMINI_API_KEY is not set in project secrets');
    }

    const body = await req.json();
    const {
      prompt = '',
      chat_history = [],
      attachments = {},
      title = '',
    } = body;

    if (!prompt && (!attachments.session || attachments.session.length === 0)) {
      throw new Error('Prompt or attachments must be provided.');
    }

    // SERVER-SIDE TRIM: limit history to last N messages
    const MAX_HISTORY = 8;
    const trimmedHistory = (chat_history || []).slice(-MAX_HISTORY);

    // Only use a simple system instruction on followups to keep request small
    let systemInstructionText;
    if ((trimmedHistory || []).length === 0) {
      systemInstructionText = `You are an expert study assistant. Your primary goal is to help the user understand material. If a course title is provided, such as "${title}", tailor your expertise to that subject. Analyze all provided context, images, and the entire chat history to give the best possible answer.`;
    } else {
      systemInstructionText = 'You are an expert study assistant. Continue the conversation helpfully.';
    }

    const formattedHistory = trimmedHistory.map((msg: any) => ({
      role: msg.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: msg.text }],
    }));

    // Build the user message parts: prompt + only the NEW images for this message
    const userMessageParts: any[] = [{ text: prompt }];
    const newImageUrls = attachments?.session || [];

    for (const url of newImageUrls) {
      try {
        // use abortableFetch to avoid a single slow image blocking the function
        const imageRes = await abortableFetch(url, { method: 'GET' }, 5000);
        if (!imageRes.ok) {
          console.warn(`Skipping image ${url} (status ${imageRes.status})`);
          continue;
        }
        const mimeType = imageRes.headers.get('content-type')?.split(';')[0] || 'image/jpeg';
        const imageBuffer = await imageRes.arrayBuffer();
        const imageB64 = encodeBase64(imageBuffer);
        userMessageParts.push({
          inlineData: { mimeType, data: imageB64 },
        });
      } catch (imgErr) {
        console.error(`Failed to fetch/process image ${url}:`, imgErr);
        // continue — images are optional
      }
    }

    const requestBody = {
      systemInstruction: { parts: [{ text: systemInstructionText }] },
      contents: [
        ...formattedHistory,
        { role: 'user', parts: userMessageParts },
      ],
    };

    // Guard: if request too large, return helpful error
    const serialized = JSON.stringify(requestBody);
    const MAX_PAYLOAD = 600000; // ~600 KB; tune down if needed
    if (serialized.length > MAX_PAYLOAD) {
      return new Response(JSON.stringify({ error: 'Payload too large. Please send less history or smaller images.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    // Send to Gemini
    const res = await fetch(API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody),
    });

    if (!res.ok) {
      const errorBody = await res.text();
      throw new Error(`Gemini API Error: ${errorBody}`);
    }

    const data = await res.json();
    const aiText = data.candidates?.[0]?.content?.parts?.[0]?.text || 'Sorry, I could not generate a response.';

    return new Response(JSON.stringify({ response: aiText }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (e: any) {
    console.error('Edge Function Error:', e);
    return new Response(JSON.stringify({ error: e.message || `${e}` }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
