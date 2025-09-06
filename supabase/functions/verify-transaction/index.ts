// functions/verify-transaction/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { corsHeaders } from '../_shared/cors.ts';

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    // parse JSON body
    const { reference } = await req.json();
    if (!reference) {
      return new Response(JSON.stringify({ error: 'Missing reference' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    const PAYSTACK_SECRET = Deno.env.get('PAYSTACK_SECRET_KEY');
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!PAYSTACK_SECRET || !SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
      return new Response(JSON.stringify({ error: 'Server configuration missing' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      });
    }

    // 1) verify with Paystack
    const verifyRes = await fetch(`https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`, {
      method: 'GET',
      headers: { Authorization: `Bearer ${PAYSTACK_SECRET}` },
    });

    const verifyJson = await verifyRes.json();
    if (!verifyRes.ok) {
      return new Response(JSON.stringify({ error: 'Paystack verify failed', details: verifyJson }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    const tx = verifyJson.data;
    if (!tx) {
      return new Response(JSON.stringify({ error: 'No transaction data returned by Paystack' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    // If transaction is successful, insert payment and update user
    if (tx.status === 'success') {
      const referenceReturned = tx.reference;
      const amount = tx.amount; // kobo
      const email = tx.customer?.email ?? null;
      const metadata = tx.metadata ?? {};
      const userId = metadata.user_id ?? null; // we expect firebase UID here

      // 2) insert into payments table via Supabase REST API (service role)
      await fetch(`${SUPABASE_URL}/rest/v1/payments`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          apikey: SUPABASE_SERVICE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
          Prefer: 'return=representation',
        },
        body: JSON.stringify([{
          reference: referenceReturned,
          amount,
          email,
          raw_payload: tx,
          status: 'success',
          created_at: new Date().toISOString()
        }]),
      });

      // 3) mark user premium if we have a userId
      if (userId) {
        await fetch(`${SUPABASE_URL}/rest/v1/users?id=eq.${encodeURIComponent(userId)}`, {
          method: 'PATCH',
          headers: {
            'Content-Type': 'application/json',
            apikey: SUPABASE_SERVICE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
            Prefer: 'return=representation',
          },
          body: JSON.stringify({ is_premium: true }),
        });
      }

      // success response back to client
      return new Response(JSON.stringify({ ok: true, data: tx }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    // if transaction not success:
    return new Response(JSON.stringify({ ok: false, reason: tx.status, data: tx }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});
