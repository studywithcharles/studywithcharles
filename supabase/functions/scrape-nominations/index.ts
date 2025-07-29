import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

console.log("Starting scrape-nominations function");

Deno.serve(async (req) => {
  try {
    // We will simulate getting raw comments for now.
    // In the future, this data will come from the Social Media APIs.
    const { rawComments } = await req.json();
    if (!rawComments) {
      throw new Error("No raw comments provided.");
    }
    
    // Create a Supabase admin client to interact with the database
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // 1. Find the current active nomination cycle
    const { data: cycle, error: cycleError } = await supabaseAdmin
      .from("swc_cycles")
      .select("id")
      .eq("status", "nominations")
      .single();

    if (cycleError || !cycle) {
      throw new Error("No active nomination cycle found.");
    }
    
    // 2. Normalize all the usernames as per your plan
    const nominationsToInsert = rawComments.map((comment) => {
      return {
        cycle_id: cycle.id,
        username: comment.username.trim().toLowerCase(), // Convert to lowercase and remove spaces [cite: 299, 300]
        platform: comment.platform,
      };
    });

    if (nominationsToInsert.length === 0) {
      return new Response(JSON.stringify({ message: "No new nominations to insert." }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      });
    }

    // 3. Save the cleaned-up nominations to the 'tca_nominations' table
    const { error: insertError } = await supabaseAdmin
      .from("tca_nominations")
      .insert(nominationsToInsert);

    if (insertError) {
      throw insertError;
    }

    console.log(`Successfully inserted ${nominationsToInsert.length} nominations.`);

    return new Response(JSON.stringify({ message: `Successfully inserted ${nominationsToInsert.length} nominations.` }), {
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