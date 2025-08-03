import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';

const API_KEY = Deno.env.get('GEMINI_API_KEY');
// Switched to the smaller Flash-8B model to stay within free quotas
const MODEL = 'gemini-1.5-flash-8b-001';
// Use the v1 endpoint for generateContent
const API_URL =
  `https://generativelanguage.googleapis.com/v1/models/${MODEL}:generateContent?key=${API_KEY}`;

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { prompt } = await req.json();

    // Correct request format for generateContent
    const requestBody = {
      contents: [{ parts: [{ text: prompt }] }],
    };

    const res = await fetch(API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody),
    });

    const raw = await res.text();
    console.log('STATUS', res.status, 'BODY', raw);
    if (!res.ok) {
      throw new Error(`Status ${res.status}: ${raw}`);
    }

    const data = JSON.parse(raw);
    const aiText = data.candidates[0].content.parts[0].text;

    return new Response(JSON.stringify({ response: aiText }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (e: any) {
    console.error(e);
    return new Response(JSON.stringify({ error: e.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
