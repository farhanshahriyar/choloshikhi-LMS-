import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Auth check
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const userId = user.id;

    const { quiz_id, answers } = await req.json();

    if (!quiz_id || !Array.isArray(answers)) {
      return new Response(
        JSON.stringify({ error: "quiz_id and answers[] are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Use service role to read correct_index (not exposed to client)
    const serviceClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Fetch questions with correct answers server-side
    const { data: questions, error: qError } = await serviceClient
      .from("quiz_questions")
      .select("id, correct_index, position")
      .eq("quiz_id", quiz_id)
      .order("position", { ascending: true });

    if (qError || !questions || questions.length === 0) {
      return new Response(
        JSON.stringify({ error: "Quiz not found or has no questions" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Verify user is enrolled in the course this quiz belongs to
    const { data: quiz } = await serviceClient
      .from("quizzes")
      .select("chapter_id")
      .eq("id", quiz_id)
      .single();

    if (!quiz) {
      return new Response(
        JSON.stringify({ error: "Quiz not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: chapter } = await serviceClient
      .from("chapters")
      .select("course_id")
      .eq("id", quiz.chapter_id)
      .single();

    if (!chapter) {
      return new Response(
        JSON.stringify({ error: "Chapter not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { data: isEnrolled } = await serviceClient.rpc("is_enrolled", {
      _user_id: userId,
      _course_id: chapter.course_id,
    });

    if (!isEnrolled) {
      return new Response(
        JSON.stringify({ error: "Not enrolled in this course" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Calculate score server-side
    const total = questions.length;
    let score = 0;
    const correctAnswers: number[] = [];
    questions.forEach((q, i) => {
      correctAnswers.push(q.correct_index);
      if (i < answers.length && answers[i] === q.correct_index) {
        score++;
      }
    });

    // Insert attempt using service role
    const { data: attempt, error: insertError } = await serviceClient
      .from("quiz_attempts")
      .insert({ quiz_id, user_id: userId, score, total })
      .select()
      .single();

    if (insertError) {
      console.error("Failed to insert quiz attempt:", insertError);
      return new Response(
        JSON.stringify({ error: "Failed to save quiz attempt" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ score, total, attempt_id: attempt.id, correct_answers: correctAnswers }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Submit quiz error:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
