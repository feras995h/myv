/*
# إصلاح نظام المصادقة باستخدام JWT
تحديث نظام المصادقة بالكامل لاستخدام جلسات JWT القياسية بدلاً من الإعدادات المحلية للمعاملات.
هذا الإصلاح يحل مشكلة "Auth session missing" بشكل نهائي.

## Query Description:
- إزالة دوال المصادقة القديمة وغير الفعالة (set_current_user, get_current_user, clear_current_user).
- تعديل دالة `authenticate_user` لتقوم بإنشاء وإرجاع JWT صالح مع بيانات المستخدم.
- إضافة دالة `get_my_profile` لجلب بيانات المستخدم الحالي بشكل آمن.
- تحديث دالة `create_new_user` وسياسات RLS لاستخدام `auth.uid()` القياسي.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "High"
- Requires-Backup: true
- Reversible: false

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes
- Auth Requirements: يعتمد النظام الآن بشكل كامل على JWTs القياسية والآمنة.
*/

-- الخطوة 1: إزالة الدوال القديمة
DROP FUNCTION IF EXISTS set_current_user(uuid);
DROP FUNCTION IF EXISTS get_current_user();
DROP FUNCTION IF EXISTS clear_current_user();
DROP FUNCTION IF EXISTS authenticate_user(text, text);

-- الخطوة 2: تعديل دالة المصادقة لإنشاء وإرجاع JWT
CREATE OR REPLACE FUNCTION public.authenticate_user(p_username text, p_password text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    user_record public.users;
    token TEXT;
    jwt_secret TEXT;
BEGIN
    -- Fetch the user
    SELECT * INTO user_record
    FROM public.users u
    WHERE u.username = p_username;

    -- Verify user and password
    IF user_record IS NULL OR NOT (user_record.password_hash = crypt(p_password, user_record.password_hash)) THEN
        RAISE EXCEPTION 'اسم المستخدم أو كلمة المرور غير صحيحة';
    END IF;

    IF NOT user_record.is_active THEN
        RAISE EXCEPTION 'هذا الحساب غير نشط';
    END IF;

    -- Use the project's JWT secret from Supabase settings
    SELECT current_setting('secrets.jwt_secret', true) INTO jwt_secret;

    -- Generate JWT
    SELECT sign(
        json_build_object(
            'sub', user_record.id,
            'role', 'authenticated', -- Standard Supabase role
            'user_role', user_record.role, -- Custom role for app logic
            'exp', extract(epoch from now()) + 60*60*24 -- 24 hour expiration
        ),
        jwt_secret
    ) INTO token;

    -- Update last login
    UPDATE public.users SET last_login = NOW() WHERE public.users.id = user_record.id;

    -- Return user details and token
    RETURN json_build_object(
        'user', row_to_json(user_record),
        'token', token
    );
END;
$function$;

-- الخطوة 3: إضافة دالة لجلب ملف المستخدم الحالي
CREATE OR REPLACE FUNCTION public.get_my_profile()
 RETURNS SETOF users
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT *
    FROM public.users
    WHERE id = auth.uid();
END;
$function$;

-- الخطوة 4: تحديث دالة إنشاء المستخدمين
CREATE OR REPLACE FUNCTION public.create_new_user(p_username text, p_password text, p_full_name text, p_role user_role, p_email text DEFAULT NULL::text, p_phone text DEFAULT NULL::text)
 RETURNS users
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    new_user users;
    creator_role user_role;
BEGIN
    -- Check if creator is an admin
    SELECT u.role INTO creator_role FROM public.users u WHERE u.id = auth.uid();
    IF creator_role != 'admin' THEN
        RAISE EXCEPTION 'فقط مدير النظام يمكنه إنشاء مستخدمين جدد';
    END IF;
    
    -- Insert the new user
    INSERT INTO public.users (username, password_hash, full_name, role, email, phone, created_by)
    VALUES (
        p_username,
        crypt(p_password, gen_salt('bf')),
        p_full_name,
        p_role,
        p_email,
        p_phone,
        auth.uid()
    ) RETURNING * INTO new_user;

    RETURN new_user;
END;
$function$;

-- الخطوة 5: تحديث سياسات RLS
-- Drop existing policies to replace them
DROP POLICY IF EXISTS "Enable read access for all users" ON public.users;
DROP POLICY IF EXISTS "Enable insert for admins" ON public.users;
DROP POLICY IF EXISTS "Enable update for admins or self" ON public.users;
DROP POLICY IF EXISTS "Enable delete for admins" ON public.users;

-- Recreate policies using auth.uid()
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Enable read access for all authenticated users"
ON public.users FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Enable insert for admins"
ON public.users FOR INSERT
TO authenticated
WITH CHECK (((SELECT users.role FROM public.users WHERE (users.id = auth.uid())) = 'admin'));

CREATE POLICY "Enable update for admins or self"
ON public.users FOR UPDATE
TO authenticated
USING ((((SELECT users.role FROM public.users WHERE (users.id = auth.uid())) = 'admin') OR (id = auth.uid())))
WITH CHECK ((((SELECT users.role FROM public.users WHERE (users.id = auth.uid())) = 'admin') OR (id = auth.uid())));

CREATE POLICY "Enable delete for admins"
ON public.users FOR DELETE
TO authenticated
USING ((((SELECT users.role FROM public.users WHERE (users.id = auth.uid())) = 'admin') AND (id <> auth.uid())));
