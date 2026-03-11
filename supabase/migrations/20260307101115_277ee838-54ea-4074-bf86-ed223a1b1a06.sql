
-- Create chapter_progress table to track student completion
CREATE TABLE public.chapter_progress (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL,
  chapter_id UUID NOT NULL REFERENCES public.chapters(id) ON DELETE CASCADE,
  is_completed BOOLEAN NOT NULL DEFAULT false,
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  UNIQUE(user_id, chapter_id)
);

-- Enable RLS
ALTER TABLE public.chapter_progress ENABLE ROW LEVEL SECURITY;

-- Students can view their own progress
CREATE POLICY "Students can view own progress"
  ON public.chapter_progress FOR SELECT
  USING (user_id = auth.uid());

-- Students can insert their own progress
CREATE POLICY "Students can insert own progress"
  ON public.chapter_progress FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Students can update their own progress
CREATE POLICY "Students can update own progress"
  ON public.chapter_progress FOR UPDATE
  USING (user_id = auth.uid());

-- Teachers can view progress for their courses
CREATE POLICY "Teachers can view progress for their courses"
  ON public.chapter_progress FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM chapters ch
    WHERE ch.id = chapter_progress.chapter_id
    AND is_course_teacher(auth.uid(), ch.course_id)
  ));

-- Add updated_at trigger
CREATE TRIGGER update_chapter_progress_updated_at
  BEFORE UPDATE ON public.chapter_progress
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();
