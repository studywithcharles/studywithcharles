import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { toB64 } from 'https://deno.land/std@0.224.0/encoding/base64.ts';

// Ensure your Gemini API Key is set in your project's secrets
const API_KEY = Deno.env.get('GEMINI_API_KEY');
const MODEL = 'gemini-1.5-flash-latest'; // Using the latest Flash model for multimodal capabilities
const API_URL =
  `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${API_KEY}`;

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // 1. RECEIVE THE FULL PAYLOAD FROM THE FLUTTER APP
    const {
      prompt,
      chat_history,
      attachments,
      context_rules
    } = await req.json();

    // 2. BUILD THE SYSTEM INSTRUCTION FROM CONTEXT RULES
    const systemInstruction = {
      role: 'system',
      parts: [{
        text: `You are an expert assistant. Follow these rules precisely for your response:
        - Your output format must be: "${context_rules.result_format}".
        - Adhere to the following user-provided context: "${context_rules.more_context}".
        - Analyze the content of any provided images and text from the user's attachments.
        - The user's entire chat history is provided for context. Use it to understand the flow of the conversation.`,
      }, ],
    };

    // 3. FORMAT THE CHAT HISTORY
    // Gemini expects the role 'assistant' to be 'model'.
    const formattedHistory = chat_history.map((msg: any) => ({
      role: msg.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: msg.text }],
    }));

    // 4. PREPARE THE NEW USER MESSAGE (TEXT + IMAGES)
    const userMessageParts: any[] = [{ text: prompt }];

    // Combine all image URLs (from context and session) and remove duplicates
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

    // 5. CONSTRUCT THE FINAL REQUEST BODY FOR GEMINI
    const requestBody = {
      systemInstruction: systemInstruction.parts[0], // The v1beta API takes a single part object
      contents: [
        ...formattedHistory,
        { role: 'user', parts: userMessageParts },
      ],
    };

    // 6. CALL THE GEMINI API
    const res = await fetch(API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(requestBody),
    });

    const raw = await res.text();
    console.log('Gemini API Response Status:', res.status);
    if (!res.ok) {
      console.error('Gemini API Error Body:', raw);
      throw new Error(`Gemini API Error (Status ${res.status}): ${raw}`);
    }

    const data = JSON.parse(raw);
    // Add safety checks for the response structure
    const aiText = data.candidates?.[0]?.content?.parts?.[0]?.text ||
      'Sorry, I could not generate a response.';

    return new Response(JSON.stringify({ response: aiText }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (e: any) {
    console.error('Main function error:', e);
    return new Response(JSON.stringify({ error: e.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});