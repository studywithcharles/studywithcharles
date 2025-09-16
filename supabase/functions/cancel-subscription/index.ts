// functions/cancel-subscription/index.ts
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
    const body = await req.json();
    const { subscription_code, user_id } = body ?? {};

    if (!subscription_code || !user_id) {
      throw new Error('subscription_code and user_id are required');
    }

    const PAYSTACK_SECRET = Deno.env.get('PAYSTACK_SECRET_KEY');
    if (!PAYSTACK_SECRET) throw new Error('Server configuration missing: PAYSTACK_SECRET_KEY');
    
    const supabaseAdmin = getSupabaseAdminClient();

    // 1) Call Paystack to disable the subscription
    const disableRes = await fetch('https://api.paystack.co/subscription/disable', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ code: subscription_code, token: null }),
    });

    const disableJson = await disableRes.json();
    if (!disableRes.ok) {
        // If it's already disabled, that's okay, just proceed.
        if (disableJson.message !== 'Subscription is not active') {
             throw new Error(`Paystack disable failed: ${disableJson.message}`);
        }
    }

    // 2) Update your internal 'subscriptions' table
    await supabaseAdmin
      .from('subscriptions')
      .update({ 
          status: 'cancelled', 
          cancelled_at: new Date().toISOString() 
      })
      .eq('subscription_code', subscription_code);

    // 3) Update the 'users' table. Set them back to 'free'.
    await supabaseAdmin
      .from('users')
      .update({ 
          is_premium: false, 
          subscription_tier: 'free', // SET THEM BACK TO FREE
          current_subscription_code: null // CLEAR THE CODE
      })
      .eq('id', user_id);

    return new Response(JSON.stringify({ ok: true, disabled: disableJson }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500
    });
  }
});

