-- Add status column to enrollments table
CREATE TYPE public.enrollment_status AS ENUM ('active', 'suspended', 'banned');

ALTER TABLE public.enrollments
  ADD COLUMN status public.enrollment_status NOT NULL DEFAULT 'active';

-- Allow teachers to update enrollments for their courses (to change status)
CREATE POLICY "Teachers can update enrollments for their courses"
  ON public.enrollments
  FOR UPDATE
  USING (is_course_teacher(auth.uid(), course_id))
  WITH CHECK (is_course_teacher(auth.uid(), course_id));