// functions/_shared/cors.ts
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*', // For development. Lock this down to your domain in production.
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};
