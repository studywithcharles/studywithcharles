// functions/text-proxy/index.ts
// Deploy this as your Supabase Edge Function at: functions/text-proxy/index.ts

import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';
import { encodeBase64 } from 'https://deno.land/std@0.224.0/encoding/base64.ts';
import { corsHeaders } from '../_shared/cors.ts';

const API_KEY = AIzaSyDulD4UdclW_216_qiiRwXDyOREP0DgVoc;
const MODEL = 'gemini-1.5-flash-latest';
const API_URL = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${API_KEY}`;

// Small helper to perform a fetch with an AbortController and timeout
function abortableFetch(url: string, opts: RequestInit = {}, timeoutMs = 5000) {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeoutMs);
  const combined: RequestInit = {
    ...opts,
    signal: controller.signal,
  };
  return fetch(url, combined).finally(() => clearTimeout(id));
}

// Function to clean markdown formatting from AI responses
function cleanAIResponse(text: string): string {
  return text
    // Remove bold formatting (**text**)
    .replace(/\*\*(.*?)\*\*/g, '$1')
    // Remove italic formatting (*text*)
    .replace(/(?<!\*)\*(?!\*)([^*]+?)\*(?!\*)/g, '$1')
    // Remove markdown headers (# ## ### etc.)
    .replace(/^#{1,6}\s+/gm, '')
    // Remove bullet point asterisks at start of lines
    .replace(/^\s*\*\s+/gm, '• ')
    // Clean up multiple spaces and normalize whitespace
    .replace(/\s+/g, ' ')
    // Remove trailing spaces and normalize line breaks
    .replace(/[ \t]+$/gm, '')
    .trim();
}

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

    if (!prompt && (!attachments.session || attachments.session.length === 0)) {
      throw new Error('Prompt or attachments must be provided.');
    }

    // Server-side trim of history to keep payload small
    const MAX_HISTORY = 8;
    const trimmedHistory = (chat_history || []).slice(-MAX_HISTORY);

    let systemInstructionText: string;
    if ((trimmedHistory || []).length === 0) {
      systemInstructionText = `You are an expert study assistant. Your primary goal is to help the user understand material. If a course title is provided, such as "${title}", tailor your expertise to that subject. Analyze all provided context, images, and the entire chat history to give the best possible answer. Please provide clear, educational explanations in plain text format without using markdown formatting, asterisks for emphasis, or special characters. Use simple, readable text only.`;
    } else {
      systemInstructionText = 'You are an expert study assistant. Continue the conversation helpfully. Provide responses in plain text format without markdown formatting or asterisks.';
    }

    const formattedHistory = trimmedHistory.map((msg: any) => ({
      role: msg.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: msg.text }],
    }));

    // Build user message parts: the prompt plus only NEW session images
    const userMessageParts: any[] = [{ text: prompt }];
    const newImageUrls = attachments?.session || [];

    for (const url of newImageUrls) {
      try {
        // Use abortableFetch to avoid one slow image blocking everything
        const imageRes = await abortableFetch(url, { method: 'GET' }, 5000);
        if (!imageRes || !imageRes.ok) {
          console.warn(`Skipping image ${url} (status ${imageRes?.status})`);
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
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 2048,
        candidateCount: 1,
      },
    };

    // Guard: avoid sending gigantic payloads
    const serialized = JSON.stringify(requestBody);
    const MAX_PAYLOAD = 600000; // ~600 KB
    if (serialized.length > MAX_PAYLOAD) {
      return new Response(JSON.stringify({
        error: 'Payload too large. Please send less history or smaller images.'
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    // Send to Gemini with a server-side timeout using abortableFetch
    let res: Response;
    try {
      res = await abortableFetch(API_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(requestBody),
      }, 5000); // 5s server-side timeout for Gemini call
    } catch (e) {
      console.error('Gemini fetch failed/aborted:', e);
      return new Response(JSON.stringify({
        error: 'AI service timed out or failed. Please try again.'
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 504,
      });
    }

    if (!res.ok) {
      const errorBody = await res.text();
      throw new Error(`Gemini API Error: ${errorBody}`);
    }

    const data = await res.json();
    const rawAIText = data.candidates?.[0]?.content?.parts?.[0]?.text || 'Sorry, I could not generate a response.';
    
    // Clean the AI response to remove formatting artifacts
    const cleanedAIText = cleanAIResponse(rawAIText);

    return new Response(JSON.stringify({ response: cleanedAIText }), {
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
