
-- Allow teachers to view profiles of students enrolled in their courses
CREATE POLICY "Teachers can view enrolled student profiles"
  ON public.profiles
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM enrollments e
      JOIN courses c ON c.id = e.course_id
      WHERE e.user_id = profiles.user_id
        AND c.teacher_id = auth.uid()
    )
  );
