// supabase/functions/verify-transaction-v2/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Helper to create Supabase client with admin rights
function getSupabaseAdminClient() {
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
  const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
  if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    throw new Error('Supabase URL or Service Role key not set in environment.');
  }
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { persistSession: false },
  });
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const { reference } = body as { reference?: string };
    if (!reference) {
      return new Response(JSON.stringify({ error: 'Missing reference' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    const PAYSTACK_SECRET = Deno.env.get('PAYSTACK_SECRET_KEY');
    if (!PAYSTACK_SECRET) {
      return new Response(JSON.stringify({ error: 'Server configuration missing: PAYSTACK_SECRET_KEY' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      });
    }

    // 1) Verify with Paystack
    const verifyRes = await fetch(`https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`, {
      method: 'GET',
      headers: { Authorization: `Bearer ${PAYSTACK_SECRET}` },
    });

    const verifyJson = await verifyRes.json().catch((e) => {
      console.error('Failed to parse Paystack response JSON', e);
      return null;
    });

    if (!verifyRes.ok || !verifyJson || !verifyJson.data) {
      console.error('Paystack verify failed', verifyJson);
      return new Response(JSON.stringify({ error: 'Paystack verify failed', details: verifyJson }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    const tx = verifyJson.data;

    // If transaction not success:
    if (tx.status !== 'success') {
      return new Response(JSON.stringify({ ok: false, reason: tx.status, data: tx }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    // 2) Extract metadata & user id (we expect metadata.user_id = firebase uid)
    const metadata = tx.metadata || {};
    const userId = metadata.user_id || null;
    const tier = metadata.tier || metadata.plan || 'plus';

    if (!userId) {
      // fallback: try to match by email if present in tx.customer.email
      const email = (tx.customer && tx.customer.email) || null;
      if (!email) {
        console.error('Verification success but no user_id and no email in metadata/tx.');
        return new Response(JSON.stringify({ error: 'No user_id in transaction metadata and no customer email' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 400,
        });
      } else {
        console.warn('No user_id in metadata; verification will try to match by email:', email);
      }
    }

    // 3) Robust extraction of subscription code and plan code (avoid mixed ?? + &&)
    // Use logical OR (||) and explicit checks to avoid parsing errors in Deno TS transformer.
    const subscriptionCode =
      tx.subscription_code ||
      (tx.subscription && (tx.subscription.code || tx.subscription.id)) ||
      (tx.authorization && tx.authorization.authorization_code) ||
      null;

    const planCode =
      (tx.plan_object && (tx.plan_object.plan_code || tx.plan_object.code)) ||
      tx.plan ||
      (tx.authorization && tx.authorization.plan) ||
      null;

    const supabaseAdmin = getSupabaseAdminClient();

    // Prepare update for users table
    const updateData: Record<string, any> = {
      is_premium: true,
      subscription_tier: tier,
    };

    if (subscriptionCode) {
      updateData.current_subscription_code = subscriptionCode;
    }

    // If we only have email (no userId), try to update by email; otherwise use id.
    let userUpdate;
    if (userId) {
      userUpdate = await supabaseAdmin.from('users').update(updateData).eq('id', userId).select().maybeSingle();
    } else {
      const email = (tx.customer && tx.customer.email) || null;
      userUpdate = await supabaseAdmin.from('users').update(updateData).eq('email', email).select().maybeSingle();
    }

    if (userUpdate.error) {
      console.error('Failed to update user profile', {
        error: userUpdate.error,
        userId,
        email: (tx.customer && tx.customer.email) || null,
        updateData,
      });
      // Don't die; return an error so the client knows verify failed
      return new Response(JSON.stringify({ error: 'Failed to update user', details: userUpdate.error.message }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      });
    }

    // 4) Insert a subscriptions record (non-fatal if it fails)
    if (subscriptionCode) {
      const insertSub = await supabaseAdmin.from('subscriptions').insert({
        user_id: userId || (tx.customer && tx.customer.email) || null,
        subscription_code: subscriptionCode,
        status: 'active',
        plan_id: planCode,
        created_at: new Date().toISOString(),
      });

      if (insertSub.error) {
        // Log but do not abort — it's non-critical
        console.error('Warning: failed to insert subscription record (non-fatal)', {
          error: insertSub.error,
          subscriptionCode,
          planCode,
          userId,
        });
      }
    } else {
      console.warn('No subscriptionCode extracted for reference', reference);
    }

    // 5) Insert payment record into payments table (safe insert)
    try {
      const insertPayment = await supabaseAdmin.from('payments').insert({
        reference: tx.reference || reference,
        amount: tx.amount ?? null,
        email: (tx.customer && tx.customer.email) || null,
        raw_payload: tx,
        status: 'success',
        created_at: new Date().toISOString(),
      });

      if (insertPayment.error) {
        console.error('Failed to insert payment record', insertPayment.error);
      }
    } catch (e) {
      console.error('Exception while inserting payment record', e);
    }

    // Success
    return new Response(JSON.stringify({ ok: true, data: tx }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (err) {
    console.error('verify-transaction-v2 error:', err);
    return new Response(JSON.stringify({ error: String(err) }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
