// initialize-payment/index.ts (robust: fetch plan amount then initialize)
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const body = await req.json();
    const { plan_code, email, reference, metadata } = body ?? {};

    if (!plan_code || !email || !reference) {
      throw new Error('Missing required fields: plan_code, email and reference are required.');
    }

    const PAYSTACK_SECRET = Deno.env.get('PAYSTACK_SECRET_KEY');
    if (!PAYSTACK_SECRET) throw new Error('Paystack secret key not found in environment.');

    // 1) Fetch the plan to get a reliable amount (kobo)
    const planRes = await fetch(`https://api.paystack.co/plan/${encodeURIComponent(plan_code)}`, {
      method: 'GET',
      headers: { Authorization: `Bearer ${PAYSTACK_SECRET}` },
    });
    const planJson = await planRes.json();
    if (!planRes.ok) {
      throw new Error(`Failed to fetch plan: ${planJson.message || JSON.stringify(planJson)}`);
    }
    const planAmount = planJson?.data?.amount;
    if (!planAmount || typeof planAmount !== 'number') {
      throw new Error('Plan found but amount missing or invalid.');
    }

    // 2) Build initialize payload (include explicit amount and plan)
    const initBody: Record<string, unknown> = {
      email,
      reference,
      plan: plan_code,
      amount: planAmount, // amount in kobo
      callback_url: 'https://studywithcharles.app/success',
    };
    if (metadata) initBody.metadata = metadata;

    // 3) Call Paystack
    const paystackRes = await fetch('https://api.paystack.co/transaction/initialize', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(initBody),
    });

    const responseData = await paystackRes.json();
    if (!paystackRes.ok) {
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
    console.error('init-payment-v2 error:', err);
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});

