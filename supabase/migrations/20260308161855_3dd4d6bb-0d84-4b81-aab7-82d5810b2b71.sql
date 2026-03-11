
-- Drop the restrictive policy and recreate as permissive
DROP POLICY IF EXISTS "Anyone can select published courses" ON public.courses;

CREATE POLICY "Anyone can select published courses"
  ON public.courses
  FOR SELECT
  TO anon, authenticated
  USING (is_published = true);
