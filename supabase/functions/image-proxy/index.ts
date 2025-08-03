import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';

const API_KEY = Deno.env.get('GEMINI_API_KEY');
// Imagen “predict” endpoint for version 4 preview
const MODEL = 'imagen-4.0-generate-preview-06-06';
const API_URL =
  `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:predict?key=${API_KEY}`;

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  try {
    const { prompt } = await req.json();
    // Build the body per the REST example :contentReference[oaicite:0]{index=0}
    const body = {
      instances: [{ prompt }],
      parameters: {
        sampleCount: 1
      }
    };

    const res = await fetch(API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const err = await res.text();
      throw new Error(`Status ${res.status}: ${err}`);
    }

    const data = await res.json();
    // The response has `predictions[0].image.imageBytes` as base64 :contentReference[oaicite:1]{index=1}
    const b64 = data.predictions[0].image.imageBytes;
    // Convert to a data URL so Flutter can display it
    const imageUrl = `data:image/png;base64,${b64}`;

    return new Response(JSON.stringify({ response: imageUrl }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e: any) {
    return new Response(JSON.stringify({ error: e.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
