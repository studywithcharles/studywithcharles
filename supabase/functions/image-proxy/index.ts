// supabase/functions/image-proxy/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';

const API_KEY = Deno.env.get('GEMINI_API_KEY');
if (!API_KEY) {
  throw new Error("GEMINI_API_KEY environment variable not set!");
}

const MODEL = 'gemini-1.5-flash';
const API_URL = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${API_KEY}`;

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { prompt } = await req.json();
    if (!prompt) {
      throw new Error("Prompt is required for image generation.");
    }

    const requestBody = {
      contents: [
        {
          parts: [{ text: `Generate a clear, high-quality diagram or image for the following prompt: ${prompt}` }],
        },
      ],
      generationConfig: {
        responseMimeType: "image/png",
      },
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
    
    const base64ImageData = data.candidates?.[0]?.content?.parts?.[0]?.inlineData?.data;

    if (!base64ImageData) {
      throw new Error("Could not extract image data from Gemini response.");
    }

    return new Response(JSON.stringify({ response: base64ImageData }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (e: any) {
    console.error('An error occurred in the image-proxy function:', e);
    return new Response(JSON.stringify({ error: e.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
