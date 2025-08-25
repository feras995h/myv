/*
# إصلاح خطأ في دالة المصادقة
تصحيح خطأ الصياغة في دالة authenticate_user الذي كان يمنع تسجيل الدخول.

## Query Description:
يقوم هذا الملف بتحديث دالة `authenticate_user` لتستخدم الصيغة الصحيحة `public.users%ROWTYPE` بدلاً من `public.users`. هذا الإصلاح ضروري لكي تعمل عملية المصادقة بشكل صحيح. لن يؤثر هذا التغيير على البيانات الموجودة.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- تعديل دالة `authenticate_user` في قاعدة البيانات.

## Security Implications:
- RLS Status: No Change
- Policy Changes: No
- Auth Requirements: No Change

## Performance Impact:
- Indexes: No Change
- Triggers: No Change
- Estimated Impact: No performance impact.
*/
CREATE OR REPLACE FUNCTION authenticate_user(p_username TEXT, p_password TEXT)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_record public.users%ROWTYPE;
    token TEXT;
    user_info json;
BEGIN
    -- البحث عن المستخدم باستخدام اسم المستخدم
    SELECT * INTO user_record
    FROM public.users
    WHERE username = p_username;

    -- التحقق من وجود المستخدم وصحة كلمة المرور
    IF user_record IS NULL OR NOT (user_record.password_hash = crypt(p_password, user_record.password_hash)) THEN
        RAISE EXCEPTION 'اسم المستخدم أو كلمة المرور غير صحيحة';
    END IF;

    -- التحقق من أن المستخدم نشط
    IF NOT user_record.is_active THEN
        RAISE EXCEPTION 'هذا الحساب غير نشط';
    END IF;

    -- إنشاء JWT token
    token := sign(
        json_build_object(
            'sub', user_record.id,
            'role', user_record.role,
            'exp', extract(epoch from now() at time zone 'utc') + 60*60*24 -- 24 hours
        ),
        current_setting('app.jwt_secret')
    );

    -- تحديث آخر تسجيل دخول
    UPDATE public.users SET last_login = NOW() WHERE id = user_record.id;

    -- إرجاع بيانات المستخدم مع التوكن
    user_info := json_build_object(
        'id', user_record.id,
        'username', user_record.username,
        'email', user_record.email,
        'full_name', user_record.full_name,
        'role', user_record.role,
        'phone', user_record.phone,
        'is_active', user_record.is_active,
        'can_create_users', user_record.can_create_users,
        'created_at', user_record.created_at,
        'updated_at', user_record.updated_at
    );

    RETURN json_build_object('user', user_info, 'token', token);
END;
$$;
