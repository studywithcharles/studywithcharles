import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

console.log("Starting start-nomination-cycle function");

Deno.serve(async (req) => {
  // This is the logic that will run when the function is called.
  try {
    // Create a Supabase client with the admin role to allow it to write to tables.
    const supabaseAdmin = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // 1. Get the current date to create a cycle name, e.g., "July 2025"
    const now = new Date();
    const cycleName = now.toLocaleString('default', { month: 'long', year: 'numeric' });
    
    // 2. Create a new entry in the 'swc_cycles' table to start the nomination period.
    const { data, error } = await supabaseAdmin.from("swc_cycles").insert({
      id: cycleName.replace(' ', '-'), // Creates an ID like "July-2025"
      status: "nominations", // Sets the current status to 'nominations'
      start_date: now.toISOString(),
    }).select().single();

    if (error) {
      throw error;
    }

    console.log(`Successfully created TCA cycle: ${data.id}`);
    
    // TODO: In a future step, we will add code here to post the announcement to social media.

    return new Response(JSON.stringify({ message: `Successfully created TCA cycle: ${data.id}` }), {
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