/*
# إصلاح دالة المصادقة لحل مشكلة JWT Malformed
تحديث دالة `authenticate_user` لاستخدام المفتاح السري الصحيح للمشروع (`secrets.jwt_secret`) عند توقيع JWTs، مما يضمن إنشاء توقيعات صالحة.

## Query Description:
هذا التحديث يستبدل دالة المصادقة الحالية (`authenticate_user`) بنسخة مصححة. النسخة الجديدة تستدعي `pg_catalog.current_setting('secrets.jwt_secret')` للوصول إلى مفتاح JWT السري للمشروع بشكل آمن، بدلاً من الطريقة السابقة التي كانت تسبب إنشاء توقيعات تالفة. هذا الإصلاح حاسم لعمل نظام تسجيل الدخول بشكل صحيح.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "High"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- تعديل دالة `authenticate_user(p_username text, p_password text)`.

## Security Implications:
- RLS Status: لا تغيير مباشر، لكنه ضروري لعمل RLS بشكل صحيح.
- Policy Changes: No
- Auth Requirements: هذا الإصلاح يصلح آلية المصادقة نفسها.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: لا يوجد تأثير على الأداء.
*/

CREATE OR REPLACE FUNCTION public.authenticate_user(
  p_username text,
  p_password text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  user_record public.users;
  token text;
  jwt_secret text;
BEGIN
  -- 1. Fetch the user record based on username
  SELECT * INTO user_record
  FROM public.users
  WHERE username = p_username;

  -- 2. Check if user exists and password is correct
  IF user_record IS NULL OR user_record.password_hash IS NULL OR user_record.password_hash != crypt(p_password, user_record.password_hash) THEN
    RAISE EXCEPTION 'اسم المستخدم أو كلمة المرور غير صحيحة';
  END IF;

  -- 3. Check if user is active
  IF NOT user_record.is_active THEN
    RAISE EXCEPTION 'هذا الحساب غير نشط';
  END IF;

  -- 4. Get the JWT secret from Supabase secrets
  SELECT pg_catalog.current_setting('secrets.jwt_secret') INTO jwt_secret;
  
  IF jwt_secret IS NULL OR jwt_secret = '' THEN
      RAISE EXCEPTION 'JWT secret not configured in Supabase project settings.';
  END IF;

  -- 5. Generate the JWT token
  token := sign(
    json_build_object(
      'role', user_record.role,
      'user_id', user_record.id,
      'exp', extract(epoch from now() + interval '1 day')
    ),
    jwt_secret
  );

  -- 6. Return user data and token
  RETURN json_build_object(
    'user', json_build_object(
      'id', user_record.id,
      'username', user_record.username,
      'full_name', user_record.full_name,
      'role', user_record.role,
      'email', user_record.email,
      'phone', user_record.phone,
      'is_active', user_record.is_active,
      'created_at', user_record.created_at
    ),
    'token', token
  );
END;
$$;
