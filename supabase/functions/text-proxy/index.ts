import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { encodeBase64 } from 'https://deno.land/std@0.224.0/encoding/base64.ts';
import { corsHeaders } from '../_shared/cors.ts';

const API_KEY = Deno.env.get('GEMINI_API_KEY');
const MODEL = 'gemini-1.5-flash-latest';

// --- THE FIX IS HERE: Point to the v1beta endpoint ---
const API_URL = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${API_KEY}`;

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    if (!API_KEY) {
      throw new Error('GEMINI_API_KEY is not set in project secrets');
    }

    const {
      prompt = '',
      chat_history = [],
      attachments = {},
      title = '',
    } = await req.json();

    if (!prompt) {
      throw new Error('Prompt cannot be empty.');
    }

    let systemInstructionText = 'You are an expert study assistant. Help the user understand the material based on the provided context, images, and chat history.';
    if (title) {
        systemInstructionText = `You are an expert study assistant for a student studying "${title}". Help them understand the material based on the provided context, images, and chat history.`;
    }

    const formattedHistory = chat_history.map((msg: any) => ({
      role: msg.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: msg.text }],
    }));

    const userMessageParts: any[] = [{ text: prompt }];
    
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
          const imageB64 = encodeBase64(imageBuffer);
          userMessageParts.push({
            inlineData: { mimeType, data: imageB64 },
          });
        }
      } catch (e) {
        console.error(`Failed to process image ${url}:`, e);
      }
    }
    
    // --- AND THE SECOND FIX IS HERE: Use the correct payload format for v1beta ---
    const requestBody = {
      systemInstruction: { parts: [{ text: systemInstructionText }] },
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
    return new Response(JSON.stringify({ error: e.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});