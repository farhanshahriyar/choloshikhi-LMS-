-- Restrict direct enrollment to free courses only
DROP POLICY IF EXISTS "Students can enroll" ON public.enrollments;
CREATE POLICY "Students can enroll"
  ON public.enrollments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.courses
      WHERE id = course_id AND (price IS NULL OR price = 0)
    )
  );