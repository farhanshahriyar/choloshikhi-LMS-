
-- courses table
CREATE TABLE public.courses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  teacher_id uuid NOT NULL,
  title text NOT NULL,
  description text,
  image_url text,
  category text,
  price numeric DEFAULT 0,
  is_published boolean DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- chapters table
CREATE TABLE public.chapters (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  position integer NOT NULL DEFAULT 0,
  is_published boolean DEFAULT false,
  is_free boolean DEFAULT false,
  video_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- enrollments table
CREATE TABLE public.enrollments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  course_id uuid NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, course_id)
);

-- quizzes table
CREATE TABLE public.quizzes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chapter_id uuid NOT NULL REFERENCES public.chapters(id) ON DELETE CASCADE,
  title text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- quiz_questions table
CREATE TABLE public.quiz_questions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_id uuid NOT NULL REFERENCES public.quizzes(id) ON DELETE CASCADE,
  question text NOT NULL,
  options jsonb NOT NULL DEFAULT '[]'::jsonb,
  correct_index integer NOT NULL DEFAULT 0,
  position integer NOT NULL DEFAULT 0
);

-- quiz_attempts table
CREATE TABLE public.quiz_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quiz_id uuid NOT NULL REFERENCES public.quizzes(id) ON DELETE CASCADE,
  user_id uuid NOT NULL,
  score integer NOT NULL,
  total integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- course_attachments table
CREATE TABLE public.course_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES public.courses(id) ON DELETE CASCADE,
  name text NOT NULL,
  url text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- updated_at triggers
CREATE TRIGGER update_courses_updated_at BEFORE UPDATE ON public.courses
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_chapters_updated_at BEFORE UPDATE ON public.chapters
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Storage bucket
INSERT INTO storage.buckets (id, name, public) VALUES ('course-assets', 'course-assets', true);

-- Enable RLS
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chapters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.course_attachments ENABLE ROW LEVEL SECURITY;

-- Helper: check if user is teacher of a course
CREATE OR REPLACE FUNCTION public.is_course_teacher(_user_id uuid, _course_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.courses WHERE id = _course_id AND teacher_id = _user_id
  )
$$;

-- Helper: check if user is enrolled in a course
CREATE OR REPLACE FUNCTION public.is_enrolled(_user_id uuid, _course_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.enrollments WHERE user_id = _user_id AND course_id = _course_id
  )
$$;

-- COURSES RLS
CREATE POLICY "Teachers can select own courses" ON public.courses FOR SELECT TO authenticated
  USING (teacher_id = auth.uid());
CREATE POLICY "Anyone can select published courses" ON public.courses FOR SELECT TO authenticated
  USING (is_published = true);
CREATE POLICY "Teachers can insert own courses" ON public.courses FOR INSERT TO authenticated
  WITH CHECK (teacher_id = auth.uid());
CREATE POLICY "Teachers can update own courses" ON public.courses FOR UPDATE TO authenticated
  USING (teacher_id = auth.uid());
CREATE POLICY "Teachers can delete own courses" ON public.courses FOR DELETE TO authenticated
  USING (teacher_id = auth.uid());

-- CHAPTERS RLS
CREATE POLICY "Teachers can manage own chapters" ON public.chapters FOR ALL TO authenticated
  USING (public.is_course_teacher(auth.uid(), course_id));
CREATE POLICY "Students can view published chapters" ON public.chapters FOR SELECT TO authenticated
  USING (is_published = true AND EXISTS (
    SELECT 1 FROM public.courses c WHERE c.id = course_id AND c.is_published = true
  ));

-- ENROLLMENTS RLS
CREATE POLICY "Students can enroll" ON public.enrollments FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());
CREATE POLICY "Students can view own enrollments" ON public.enrollments FOR SELECT TO authenticated
  USING (user_id = auth.uid());
CREATE POLICY "Teachers can view enrollments for their courses" ON public.enrollments FOR SELECT TO authenticated
  USING (public.is_course_teacher(auth.uid(), course_id));

-- QUIZZES RLS
CREATE POLICY "Teachers manage quizzes" ON public.quizzes FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.chapters ch WHERE ch.id = chapter_id AND public.is_course_teacher(auth.uid(), ch.course_id)
  ));
CREATE POLICY "Students view quizzes" ON public.quizzes FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.chapters ch
    JOIN public.courses c ON c.id = ch.course_id
    WHERE ch.id = chapter_id AND ch.is_published = true AND c.is_published = true
      AND public.is_enrolled(auth.uid(), c.id)
  ));

-- QUIZ_QUESTIONS RLS
CREATE POLICY "Teachers manage quiz questions" ON public.quiz_questions FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.quizzes q
    JOIN public.chapters ch ON ch.id = q.chapter_id
    WHERE q.id = quiz_id AND public.is_course_teacher(auth.uid(), ch.course_id)
  ));
CREATE POLICY "Students view quiz questions" ON public.quiz_questions FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.quizzes q
    JOIN public.chapters ch ON ch.id = q.chapter_id
    JOIN public.courses c ON c.id = ch.course_id
    WHERE q.id = quiz_id AND ch.is_published = true AND c.is_published = true
      AND public.is_enrolled(auth.uid(), c.id)
  ));

-- QUIZ_ATTEMPTS RLS
CREATE POLICY "Students can submit attempts" ON public.quiz_attempts FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());
CREATE POLICY "Students view own attempts" ON public.quiz_attempts FOR SELECT TO authenticated
  USING (user_id = auth.uid());
CREATE POLICY "Teachers view attempts for their courses" ON public.quiz_attempts FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.quizzes q
    JOIN public.chapters ch ON ch.id = q.chapter_id
    WHERE q.id = quiz_id AND public.is_course_teacher(auth.uid(), ch.course_id)
  ));

-- COURSE_ATTACHMENTS RLS
CREATE POLICY "Teachers manage attachments" ON public.course_attachments FOR ALL TO authenticated
  USING (public.is_course_teacher(auth.uid(), course_id));
CREATE POLICY "Enrolled students view attachments" ON public.course_attachments FOR SELECT TO authenticated
  USING (public.is_enrolled(auth.uid(), course_id));

-- STORAGE RLS for course-assets bucket
CREATE POLICY "Teachers can upload course assets" ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'course-assets' AND (storage.foldername(name))[1] = auth.uid()::text);
CREATE POLICY "Anyone can view course assets" ON storage.objects FOR SELECT TO authenticated
  USING (bucket_id = 'course-assets');
CREATE POLICY "Teachers can delete own assets" ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'course-assets' AND (storage.foldername(name))[1] = auth.uid()::text);
