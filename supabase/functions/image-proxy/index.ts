// supabase/functions/image-proxy/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { encodeBase64 } from 'https://deno.land/std@0.168.0/encoding/base64.ts';
import { corsHeaders } from '../_shared/cors.ts';

const REPLICATE_API_TOKEN = Deno.env.get('REPLICATE_API_TOKEN');
if (!REPLICATE_API_TOKEN) {
  throw new Error('REPLICATE_API_TOKEN environment variable not set!');
}

const API_URL = 'https://api.replicate.com/v1/predictions';
const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

// Maximum polling time to prevent infinite loops (60 seconds)
const MAX_POLL_TIME = 60000;
const POLL_INTERVAL = 1000;

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { prompt } = await req.json();
    
    if (!prompt) {
      throw new Error('Prompt is required.');
    }

    // Start the prediction
    const startResponse = await fetch(API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Token ${REPLICATE_API_TOKEN}`,
      },
      body: JSON.stringify({
        version: '7117f36a53a4731a525a7a7261a8a25c345377f5255018659173f27301c34a45',
        input: {
          prompt: prompt,
          aspect_ratio: '1:1', // Options: "1:1", "16:9", "9:16", "4:3", "3:4"
        },
      }),
    });

    if (startResponse.status !== 201) {
      const errorBody = await startResponse.text();
      console.error('Replicate API Error (start):', errorBody);
      throw new Error(`Failed to start prediction: ${errorBody}`);
    }

    const prediction = await startResponse.json();
    const endpointUrl = prediction.urls?.get;

    if (!endpointUrl) {
      throw new Error('No polling URL returned from Replicate.');
    }

    // Poll for completion with timeout
    let finalPrediction;
    const startTime = Date.now();

    while (true) {
      // Check if we've exceeded max polling time
      if (Date.now() - startTime > MAX_POLL_TIME) {
        throw new Error('Image generation timed out. Please try again.');
      }

      const pollResponse = await fetch(endpointUrl, {
        headers: {
          'Authorization': `Token ${REPLICATE_API_TOKEN}`,
        },
      });

      if (!pollResponse.ok) {
        const errorBody = await pollResponse.text();
        console.error('Replicate API Error (poll):', errorBody);
        throw new Error(`Failed to poll prediction: ${errorBody}`);
      }

      finalPrediction = await pollResponse.json();

      if (finalPrediction.status === 'succeeded') {
        break;
      }

      if (finalPrediction.status === 'failed' || finalPrediction.status === 'canceled') {
        throw new Error(`Prediction ${finalPrediction.status}: ${finalPrediction.error || 'Unknown error'}`);
      }

      // Wait before polling again
      await sleep(POLL_INTERVAL);
    }

    // Extract image URL - Imagen-4 can return either a string or an array
    let imageUrl: string;
    
    if (Array.isArray(finalPrediction.output)) {
      // If output is an array, take the first element
      imageUrl = finalPrediction.output[0];
    } else if (typeof finalPrediction.output === 'string') {
      // If output is a string, use it directly
      imageUrl = finalPrediction.output;
    } else {
      console.error('Unexpected output format:', finalPrediction.output);
      throw new Error('No valid image URL in Replicate response.');
    }
    
    if (!imageUrl) {
      throw new Error('Image URL is empty or undefined.');
    }

    // Fetch the image with error handling
    const imageResponse = await fetch(imageUrl);
    
    if (!imageResponse.ok) {
      throw new Error(`Failed to fetch image: ${imageResponse.status} ${imageResponse.statusText}`);
    }

    const imageBuffer = await imageResponse.arrayBuffer();
    
    // Use Deno's standard library for base64 encoding (more efficient)
    const base64ImageData = encodeBase64(new Uint8Array(imageBuffer));

    return new Response(
      JSON.stringify({ response: base64ImageData }), 
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );

  } catch (e: any) {
    console.error('Error in image-proxy function:', e);
    return new Response(
      JSON.stringify({ error: e.message || 'An unexpected error occurred' }), 
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      }
    );
  }
});
