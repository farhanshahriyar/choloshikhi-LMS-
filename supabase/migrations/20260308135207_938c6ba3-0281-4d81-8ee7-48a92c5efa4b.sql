CREATE OR REPLACE FUNCTION public.get_public_course_detail(_course_id uuid)
RETURNS json
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT json_build_object(
    'id', c.id,
    'title', c.title,
    'description', c.description,
    'image_url', c.image_url,
    'category', c.category,
    'price', c.price,
    'created_at', c.created_at,
    'teacher_name', COALESCE(p.full_name, 'Unknown Teacher'),
    'chapter_count', (SELECT count(*) FROM chapters ch WHERE ch.course_id = c.id AND ch.is_published = true)
  )
  FROM courses c
  LEFT JOIN profiles p ON p.user_id = c.teacher_id
  WHERE c.id = _course_id AND c.is_published = true
$$;