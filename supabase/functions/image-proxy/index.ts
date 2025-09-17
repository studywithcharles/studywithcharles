// supabase/functions/image-proxy/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';

const REPLICATE_API_TOKEN = Deno.env.get('REPLICATE_API_TOKEN');
if (!REPLICATE_API_TOKEN) {
  throw new Error('REPLICATE_API_TOKEN environment variable not set!');
}

const API_URL = 'https://api.replicate.com/v1/predictions';

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { prompt } = await req.json();
    if (!prompt) {
      throw new Error('Prompt is required.');
    }

    const startResponse = await fetch(API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Token ${REPLICATE_API_TOKEN}`,
      },
      body: JSON.stringify({
        // --- THIS IS THE NEW MODEL IDENTIFIER ---
        // This is the full version hash for google/imagen-4 on Replicate
        version: '7117f36a53a4731a525a7a7261a8a25c345377f5255018659173f27301c34a45',
        // -----------------------------------------
        input: {
          prompt: prompt,
          aspect_ratio: '1:1', // Or "16:9", "9:16", etc.
        },
      }),
    });

    if (startResponse.status !== 201) {
      const errorBody = await startResponse.text();
      console.error('Replicate API Error (start):', errorBody);
      throw new Error(`Failed to start prediction: ${errorBody}`);
    }

    const prediction = await startResponse.json();
    const endpointUrl = prediction.urls.get;

    let finalPrediction;
    while (true) {
      const pollResponse = await fetch(endpointUrl, {
        headers: {
          'Authorization': `Token ${REPLICATE_API_TOKEN}`,
        },
      });
      finalPrediction = await pollResponse.json();

      if (finalPrediction.status === 'succeeded') {
        break;
      }
      if (finalPrediction.status === 'failed') {
        throw new Error(`Prediction failed: ${finalPrediction.error}`);
      }
      await sleep(1000);
    }

    // Imagen-4 returns the image URL directly in the output, not in an array
    const imageUrl = finalPrediction.output;
    if (!imageUrl) {
      throw new Error('No image URL in Replicate response.');
    }

    const imageResponse = await fetch(imageUrl);
    const imageBuffer = await imageResponse.arrayBuffer();
    
    const base64ImageData = btoa(
      new Uint8Array(imageBuffer).reduce((data, byte) => data + String.fromCharCode(byte), '')
    );

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

