import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

console.log("Starting finalize-voting-cycle function");

Deno.serve(async (_req) => {
  try {
    // Create a Supabase client with the admin role
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // 1. Find the current active voting cycle
    const { data: cycle, error: cycleError } = await supabaseAdmin
      .from("swc_cycles")
      .select("id, prize_amount") // Also get the prize amount
      .eq("status", "voting")
      .single();

    if (cycleError || !cycle) {
      throw new Error("No active voting cycle found to finalize.");
    }

    // 2. Fetch all votes for the current cycle
    const { data: votes, error: votesError } = await supabaseAdmin
      .from("tca_votes")
      .select("nominee_username")
      .eq("cycle_id", cycle.id);

    if (votesError) throw votesError;
    if (!votes || votes.length === 0) {
      // If no one voted, we can't determine a winner.
      // We'll just complete the cycle to prevent it from getting stuck.
      await supabaseAdmin
        .from("swc_cycles")
        .update({ status: "completed" })
        .eq("id", cycle.id);
      return new Response(JSON.stringify({ message: "Voting closed. No votes were cast." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    // 3. Tally votes to find the winner
    const voteCounts = new Map<string, number>();
    for (const vote of votes) {
      const username = vote.nominee_username;
      voteCounts.set(username, (voteCounts.get(username) || 0) + 1);
    }

    let winnerUsername = "";
    let maxVotes = 0;
    for (const [username, count] of voteCounts.entries()) {
      if (count > maxVotes) {
        maxVotes = count;
        winnerUsername = username;
      }
    }
    // Note: This simple logic picks the first user in case of a tie.
    // You could enhance this later to handle ties if needed.

    // 4. Get the winner's wallet address from the users table
    const { data: winnerProfile, error: profileError } = await supabaseAdmin
      .from("users")
      .select("wallet_address")
      .eq("username", winnerUsername)
      .single();

    if (profileError || !winnerProfile) {
      throw new Error(`Could not find profile for winner: ${winnerUsername}`);
    }

    // 5. Create a new award record with 'pending_approval' status
    const prizeAmount = cycle.prize_amount || 0; // Default to 0 if not set
    const { data: award, error: awardError } = await supabaseAdmin
      .from("tca_awards")
      .insert({
        cycle_id: cycle.id,
        winner_username: winnerUsername,
        prize_amount: prizeAmount,
        wallet_address: winnerProfile.wallet_address,
        status: "pending_approval", // The crucial step for your dashboard!
      }).select().single();

    if (awardError) throw awardError;

    // 6. Update the cycle status to 'completed'
    await supabaseAdmin
      .from("swc_cycles")
      .update({ status: "completed" })
      .eq("id", cycle.id);

    console.log(`Successfully finalized cycle ${cycle.id}. Winner: ${winnerUsername}`);

    // 7. Return the winner's details to n8n for the notification
    return new Response(JSON.stringify({
      winner_username: winnerUsername,
      prize_amount: prizeAmount,
      wallet_address: winnerProfile.wallet_address,
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error) {
    console.error(error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
