import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

// Helper function to pick a random item from an array
function getRandomItem<T>(items: T[]): T | undefined {
  if (items.length === 0) return undefined;
  return items[Math.floor(Math.random() * items.length)];
}

Deno.serve(async (req) => {
  try {
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // === 1. FIND ACTIVE CYCLE & COUNT PREMIUM USERS ===
    const { data: cycle, error: cycleError } = await supabaseAdmin
      .from("swc_cycles").select("id").eq("status", "nominations").single();
    if (cycleError) throw new Error("No active nomination cycle found.");

    const { count: premiumUserCount, error: countError } = await supabaseAdmin
      .from("users").select('*', { count: 'exact', head: true }).is("is_premium", true);
    if (countError) throw countError;

    // === 2. DETERMINE NUMBER OF WINNERS BASED ON YOUR FORMULA ===
    let numberOfWinners = 0;
    if (premiumUserCount <= 100) numberOfWinners = 1;
    else if (premiumUserCount <= 1000) numberOfWinners = 3;
    else if (premiumUserCount <= 10000) numberOfWinners = 5;
    else if (premiumUserCount <= 50000) numberOfWinners = 10;
    else if (premiumUserCount <= 100000) numberOfWinners = 25;
    else if (premiumUserCount <= 500000) numberOfWinners = 50;
    else if (premiumUserCount <= 1000000) numberOfWinners = 100;
    else numberOfWinners = 100 + Math.floor((premiumUserCount - 1000000) / 10000);
    
    // === 3. FETCH AND COUNT ALL NOMINATIONS ===
    const { data: nominations, error: nomError } = await supabaseAdmin
      .from("tca_nominations").select("username").eq("cycle_id", cycle.id);
    if (nomError) throw nomError;
    if (!nominations || nominations.length === 0) throw new Error("No nominations found.");

    const counts = new Map<string, number>();
    nominations.forEach(n => counts.set(n.username, (counts.get(n.username) || 0) + 1));
    const sortedNominees = [...counts.entries()].sort((a, b) => b[1] - a[1]);

    // === 4. SELECT NOMINEES BASED ON RULES ===
    const finalNominees = new Set<string>();

    // Rule A: Most Commented (with tie-breaking)
    const maxCount = sortedNominees[0][1];
    const mostCommentedTies = sortedNominees.filter(n => n[1] === maxCount).map(n => n[0]);
    const mostCommentedWinner = getRandomItem(mostCommentedTies);
    if (mostCommentedWinner) finalNominees.add(mostCommentedWinner);

    // Rule B: Least Commented (with tie-breaking)
    if (sortedNominees.length > 1) {
        const minCount = sortedNominees[sortedNominees.length - 1][1];
        const leastCommentedTies = sortedNominees.filter(n => n[1] === minCount).map(n => n[0]);
        const leastCommentedWinner = getRandomItem(leastCommentedTies.filter(n => !finalNominees.has(n)));
        if (leastCommentedWinner) finalNominees.add(leastCommentedWinner);
    }
    
    // Rule C: Provably Fair WEIGHTED Random Selection
    const remainingSlots = numberOfWinners - finalNominees.size;
    if (remainingSlots > 0) {
        const uniqueNominees = [...new Set(nominations.map(n => n.username))].filter(n => !finalNominees.has(n));
        
        // Get premium status for all unique nominees
        const { data: userStatuses } = await supabaseAdmin.from('users').select('username, is_premium').in('username', uniqueNominees);
        const premiumStatusMap = new Map(userStatuses.map(u => [u.username, u.is_premium]));

        // Create the weighted "raffle" list
        const weightedList: string[] = [];
        uniqueNominees.forEach(username => {
            const weight = premiumStatusMap.get(username) ? 5 : 1; // 5 tickets for premium, 1 for free
            for (let i = 0; i < weight; i++) {
                weightedList.push(username);
            }
        });

        // Fetch public seed
        const seedResponse = await fetch("http://worldtimeapi.org/api/ip");
        const seed = (await seedResponse.json()).utc_datetime;
        
        // Select remaining winners
        for (let i = 0; i < remainingSlots; i++) {
            if (weightedList.length === 0) break;

            const dataToHash = new TextEncoder().encode(seed + i + JSON.stringify(weightedList));
            const hashBuffer = await crypto.subtle.digest("SHA-256", dataToHash);
            const hashInt = BigInt('0x' + Array.from(new Uint8Array(hashBuffer)).map(b => b.toString(16).padStart(2, '0')).join(''));
            const randomIndex = Number(hashInt % BigInt(weightedList.length));
            const randomWinner = weightedList[randomIndex];
            
            if (randomWinner && !finalNominees.has(randomWinner)) {
                finalNominees.add(randomWinner);
                // Remove all instances of the winner from the list to prevent re-selection
                const listWithoutWinner = weightedList.filter(u => u !== randomWinner);
                weightedList.length = 0;
                weightedList.push(...listWithoutWinner);
            } else {
                i--; // Try again if we somehow picked a duplicate
            }
        }
    }
    
    // === 5. SAVE FINAL NOMINEES & UPDATE CYCLE ===
    const nomineesToInsert = [...finalNominees].map(username => ({
        cycle_id: cycle.id, username: username, method: 'community_selection',
    }));

    await supabaseAdmin.from("tca_nominees").insert(nomineesToInsert);
    await supabaseAdmin.from("swc_cycles").update({ status: 'voting', end_date: new Date().toISOString() }).eq('id', cycle.id);
        
    console.log(`Selected ${finalNominees.size} nominees: ${[...finalNominees].join(', ')}`);

    return new Response(JSON.stringify({ nominees: [...finalNominees] }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});