// functions/verify-transaction/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

function getSupabaseAdminClient() {
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
  const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    throw new Error('Supabase URL or Service Key not set in environment.');
  }
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { persistSession: false },
  });
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { reference } = await req.json();
    if (!reference) throw new Error('Missing reference');

    const PAYSTACK_SECRET = Deno.env.get('PAYSTACK_SECRET_KEY');
    if (!PAYSTACK_SECRET) throw new Error('Server configuration missing: PAYSTACK_SECRET_KEY');

    const verifyRes = await fetch(`https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`, {
      method: 'GET',
      headers: { Authorization: `Bearer ${PAYSTACK_SECRET}` },
    });

    const verifyJson = await verifyRes.json();
    if (!verifyRes.ok || !verifyJson.data) {
      throw new Error(`Paystack verify failed: ${verifyJson.message || 'Unknown error'}`);
    }

    const tx = verifyJson.data;

    if (tx.status !== 'success') {
      return new Response(JSON.stringify({ ok: false, reason: tx.status, data: tx }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    const metadata = tx.metadata ?? {};
    const userId = metadata.user_id ?? null;
    const tier = metadata.tier ?? 'plus';
    const subscriptionCode = tx.subscription?.subscription_code ?? tx.authorization?.authorization_code ?? null;
    const planCode = tx.plan_object?.plan_code ?? tx.plan ?? null;

    if (!userId) {
      throw new Error('Verification success, but no user_id found in transaction metadata.');
    }
    
    const supabaseAdmin = getSupabaseAdminClient();

    await supabaseAdmin
      .from('users')
      .update({
        is_premium: true,
        subscription_tier: tier,
        current_subscription_code: subscriptionCode,
      })
      .eq('id', userId);

    await supabaseAdmin
      .from('subscriptions')
      .insert({
          user_id: userId,
          subscription_code: subscriptionCode,
          status: 'active',
          plan_id: planCode,
      });

    return new Response(JSON.stringify({ ok: true, data: tx }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});

