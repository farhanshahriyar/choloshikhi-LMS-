
-- =============================================
-- Convert ALL restrictive RLS policies to permissive
-- =============================================

-- ========== chapter_progress ==========
DROP POLICY IF EXISTS "Students can insert own progress" ON public.chapter_progress;
DROP POLICY IF EXISTS "Students can update own progress" ON public.chapter_progress;
DROP POLICY IF EXISTS "Students can view own progress" ON public.chapter_progress;
DROP POLICY IF EXISTS "Teachers can view progress for their courses" ON public.chapter_progress;

CREATE POLICY "Students can insert own progress" ON public.chapter_progress FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "Students can update own progress" ON public.chapter_progress FOR UPDATE TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Students can view own progress" ON public.chapter_progress FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Teachers can view progress for their courses" ON public.chapter_progress FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM chapters ch WHERE ch.id = chapter_progress.chapter_id AND is_course_teacher(auth.uid(), ch.course_id)));

-- ========== chapters ==========
DROP POLICY IF EXISTS "Students can view published chapters" ON public.chapters;
DROP POLICY IF EXISTS "Teachers can manage own chapters" ON public.chapters;

CREATE POLICY "Students can view published chapters" ON public.chapters FOR SELECT TO authenticated USING (is_published = true AND EXISTS (SELECT 1 FROM courses c WHERE c.id = chapters.course_id AND c.is_published = true));
CREATE POLICY "Teachers can manage own chapters" ON public.chapters FOR ALL TO authenticated USING (is_course_teacher(auth.uid(), course_id));

-- ========== course_attachments ==========
DROP POLICY IF EXISTS "Enrolled students view attachments" ON public.course_attachments;
DROP POLICY IF EXISTS "Teachers manage attachments" ON public.course_attachments;

CREATE POLICY "Enrolled students view attachments" ON public.course_attachments FOR SELECT TO authenticated USING (is_enrolled(auth.uid(), course_id));
CREATE POLICY "Teachers manage attachments" ON public.course_attachments FOR ALL TO authenticated USING (is_course_teacher(auth.uid(), course_id));

-- ========== courses ==========
DROP POLICY IF EXISTS "Anyone can select published courses" ON public.courses;
DROP POLICY IF EXISTS "Teachers can delete own courses" ON public.courses;
DROP POLICY IF EXISTS "Teachers can insert own courses" ON public.courses;
DROP POLICY IF EXISTS "Teachers can select own courses" ON public.courses;
DROP POLICY IF EXISTS "Teachers can update own courses" ON public.courses;

CREATE POLICY "Anyone can select published courses" ON public.courses FOR SELECT USING (is_published = true);
CREATE POLICY "Teachers can delete own courses" ON public.courses FOR DELETE TO authenticated USING (teacher_id = auth.uid());
CREATE POLICY "Teachers can insert own courses" ON public.courses FOR INSERT TO authenticated WITH CHECK (teacher_id = auth.uid());
CREATE POLICY "Teachers can select own courses" ON public.courses FOR SELECT TO authenticated USING (teacher_id = auth.uid());
CREATE POLICY "Teachers can update own courses" ON public.courses FOR UPDATE TO authenticated USING (teacher_id = auth.uid());

-- ========== enrollments ==========
DROP POLICY IF EXISTS "Students can enroll" ON public.enrollments;
DROP POLICY IF EXISTS "Students can view own enrollments" ON public.enrollments;
DROP POLICY IF EXISTS "Teachers can update enrollments for their courses" ON public.enrollments;
DROP POLICY IF EXISTS "Teachers can view enrollments for their courses" ON public.enrollments;

CREATE POLICY "Students can enroll" ON public.enrollments FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid() AND EXISTS (SELECT 1 FROM courses WHERE courses.id = enrollments.course_id AND (courses.price IS NULL OR courses.price = 0)));
CREATE POLICY "Students can view own enrollments" ON public.enrollments FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Teachers can update enrollments for their courses" ON public.enrollments FOR UPDATE TO authenticated USING (is_course_teacher(auth.uid(), course_id)) WITH CHECK (is_course_teacher(auth.uid(), course_id));
CREATE POLICY "Teachers can view enrollments for their courses" ON public.enrollments FOR SELECT TO authenticated USING (is_course_teacher(auth.uid(), course_id));

-- ========== feedback ==========
DROP POLICY IF EXISTS "Teachers can view all feedback" ON public.feedback;
DROP POLICY IF EXISTS "Users can insert own feedback" ON public.feedback;
DROP POLICY IF EXISTS "Users can view own feedback" ON public.feedback;

CREATE POLICY "Teachers can view all feedback" ON public.feedback FOR SELECT TO authenticated USING (has_role(auth.uid(), 'teacher'::app_role));
CREATE POLICY "Users can insert own feedback" ON public.feedback FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can view own feedback" ON public.feedback FOR SELECT TO authenticated USING (user_id = auth.uid());

-- ========== profiles ==========
DROP POLICY IF EXISTS "Teachers can view enrolled student profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;

CREATE POLICY "Teachers can view enrolled student profiles" ON public.profiles FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM enrollments e JOIN courses c ON c.id = e.course_id WHERE e.user_id = profiles.user_id AND c.teacher_id = auth.uid()));
CREATE POLICY "Users can insert their own profile" ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT TO authenticated USING (auth.uid() = user_id);

-- ========== quiz_attempts ==========
DROP POLICY IF EXISTS "Students can submit attempts" ON public.quiz_attempts;
DROP POLICY IF EXISTS "Students view own attempts" ON public.quiz_attempts;
DROP POLICY IF EXISTS "Teachers view attempts for their courses" ON public.quiz_attempts;

CREATE POLICY "Students can submit attempts" ON public.quiz_attempts FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());
CREATE POLICY "Students view own attempts" ON public.quiz_attempts FOR SELECT TO authenticated USING (user_id = auth.uid());
CREATE POLICY "Teachers view attempts for their courses" ON public.quiz_attempts FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM quizzes q JOIN chapters ch ON ch.id = q.chapter_id WHERE q.id = quiz_attempts.quiz_id AND is_course_teacher(auth.uid(), ch.course_id)));

-- ========== quiz_questions ==========
DROP POLICY IF EXISTS "Students view quiz questions" ON public.quiz_questions;
DROP POLICY IF EXISTS "Teachers manage quiz questions" ON public.quiz_questions;

CREATE POLICY "Students view quiz questions" ON public.quiz_questions FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM quizzes q JOIN chapters ch ON ch.id = q.chapter_id JOIN courses c ON c.id = ch.course_id WHERE q.id = quiz_questions.quiz_id AND ch.is_published = true AND c.is_published = true AND is_enrolled(auth.uid(), c.id)));
CREATE POLICY "Teachers manage quiz questions" ON public.quiz_questions FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM quizzes q JOIN chapters ch ON ch.id = q.chapter_id WHERE q.id = quiz_questions.quiz_id AND is_course_teacher(auth.uid(), ch.course_id)));

-- ========== quizzes ==========
DROP POLICY IF EXISTS "Students view quizzes" ON public.quizzes;
DROP POLICY IF EXISTS "Teachers manage quizzes" ON public.quizzes;

CREATE POLICY "Students view quizzes" ON public.quizzes FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM chapters ch JOIN courses c ON c.id = ch.course_id WHERE ch.id = quizzes.chapter_id AND ch.is_published = true AND c.is_published = true AND is_enrolled(auth.uid(), c.id)));
CREATE POLICY "Teachers manage quizzes" ON public.quizzes FOR ALL TO authenticated USING (EXISTS (SELECT 1 FROM chapters ch WHERE ch.id = quizzes.chapter_id AND is_course_teacher(auth.uid(), ch.course_id)));

-- ========== user_roles ==========
DROP POLICY IF EXISTS "Users can view own roles" ON public.user_roles;

CREATE POLICY "Users can view own roles" ON public.user_roles FOR SELECT TO authenticated USING (auth.uid() = user_id);
