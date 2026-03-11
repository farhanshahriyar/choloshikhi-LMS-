
-- Create a function to get quiz questions without correct_index (for enrolled students)
CREATE OR REPLACE FUNCTION public.get_student_quiz_questions(_quiz_id uuid)
RETURNS TABLE(id uuid, quiz_id uuid, question text, options jsonb, "position" integer)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT qq.id, qq.quiz_id, qq.question, qq.options, qq.position
  FROM public.quiz_questions qq
  JOIN public.quizzes q ON q.id = qq.quiz_id
  JOIN public.chapters ch ON ch.id = q.chapter_id
  JOIN public.courses c ON c.id = ch.course_id
  WHERE qq.quiz_id = _quiz_id
    AND ch.is_published = true
    AND c.is_published = true
    AND public.is_enrolled(auth.uid(), c.id)
  ORDER BY qq.position ASC;
$$;

-- Fix 2: Remove student INSERT on quiz_attempts to prevent score fabrication
DROP POLICY "Students can submit attempts" ON public.quiz_attempts;
