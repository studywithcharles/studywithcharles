// supabase/functions/initialize-payment/index.ts (or index.html if using .ts)
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const body = await req.json();
    const { amount, email, reference, metadata } = body; // metadata can contain user_id

    const paystackSecretKey = Deno.env.get('PAYSTACK_SECRET_KEY');
    if (!paystackSecretKey) throw new Error('Paystack secret key not found.');

    // Build payload for Paystack initialize
    const initBody: Record<string, unknown> = {
      amount,
      email,
      reference,
      callback_url: 'https://studywithcharles.app/success', // keep this as your redirect
    };

    // if metadata provided (e.g. { user_id }), include it
    if (metadata) initBody.metadata = metadata;

    const paystackRes = await fetch('https://api.paystack.co/transaction/initialize', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${paystackSecretKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(initBody),
    });

    const responseData = await paystackRes.json();
    if (!paystackRes.ok) {
      // include the API response message for debugging only (it will be visible to client)
      return new Response(JSON.stringify({ error: responseData }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    return new Response(JSON.stringify(responseData), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
