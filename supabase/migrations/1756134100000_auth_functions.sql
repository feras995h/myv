/*
# دوال المصادقة باسم المستخدم
إنشاء الدوال المطلوبة للمصادقة باستخدام username وإدارة المستخدمين
## Query Description: 
إنشاء دوال PL/pgSQL للمصادقة وإدارة المستخدمين
آمنة تماماً ولا تؤثر على البيانات الموجودة
## Metadata:
- Schema-Category: "Safe"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true
## Structure Details:
- دوال المصادقة
- دوال إدارة المستخدمين
- دوال إدارة الجلسات
## Security Implications:
- RLS Status: Compatible
- Policy Changes: No
- Auth Requirements: متوافق مع النظام الحالي
## Performance Impact:
- Indexes: Uses existing indexes
- Triggers: No impact
- Estimated Impact: تحسين الأداء
*/

-- دالة المصادقة باستخدام username
CREATE OR REPLACE FUNCTION authenticate_user(p_username text, p_password text)
RETURNS TABLE(
    id uuid,
    username varchar,
    full_name varchar,
    role user_role,
    email varchar,
    phone varchar,
    is_active boolean,
    can_create_users boolean,
    created_at timestamptz
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id,
        u.username,
        u.full_name,
        u.role,
        u.email,
        u.phone,
        u.is_active,
        u.can_create_users,
        u.created_at
    FROM users u
    WHERE u.username = p_username 
    AND u.password_hash = crypt(p_password, u.password_hash)
    AND u.is_active = true;
END;
$$;

-- دالة إنشاء مستخدم جديد
CREATE OR REPLACE FUNCTION create_new_user(
    p_username text,
    p_password text,
    p_full_name text,
    p_role user_role,
    p_email text DEFAULT NULL,
    p_phone text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_user_id uuid;
    current_user_id uuid;
BEGIN
    -- التحقق من المستخدم الحالي
    current_user_id := (current_setting('app.current_user_id', true))::uuid;
    
    IF current_user_id IS NULL THEN
        RAISE EXCEPTION 'غير مصرح لك بإنشاء مستخدمين';
    END IF;
    
    -- التحقق من صلاحية إنشاء المستخدمين
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = current_user_id 
        AND (role = 'admin' OR can_create_users = true)
    ) THEN
        RAISE EXCEPTION 'ليس لديك صلاحية إنشاء مستخدمين';
    END IF;
    
    -- التحقق من عدم وجود username مكرر
    IF EXISTS (SELECT 1 FROM users WHERE username = p_username) THEN
        RAISE EXCEPTION 'اسم المستخدم موجود مسبقاً';
    END IF;
    
    -- إنشاء المستخدم الجديد
    INSERT INTO users (
        username, 
        password_hash, 
        full_name, 
        role, 
        email, 
        phone, 
        is_active, 
        created_by,
        created_at,
        updated_at
    ) VALUES (
        p_username,
        crypt(p_password, gen_salt('bf')),
        p_full_name,
        p_role,
        p_email,
        p_phone,
        true,
        current_user_id,
        NOW(),
        NOW()
    ) RETURNING id INTO new_user_id;
    
    RETURN new_user_id;
END;
$$;

-- دالة تحديد المستخدم الحالي للجلسة
CREATE OR REPLACE FUNCTION set_current_user(user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    PERFORM set_config('app.current_user_id', user_id::text, true);
END;
$$;

-- دالة الحصول على المستخدم الحالي
CREATE OR REPLACE FUNCTION get_current_user()
RETURNS TABLE(
    id uuid,
    username varchar,
    full_name varchar,
    role user_role,
    email varchar,
    phone varchar,
    is_active boolean,
    can_create_users boolean,
    created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id uuid;
BEGIN
    current_user_id := (current_setting('app.current_user_id', true))::uuid;
    
    IF current_user_id IS NULL THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        u.id,
        u.username,
        u.full_name,
        u.role,
        u.email,
        u.phone,
        u.is_active,
        u.can_create_users,
        u.created_at
    FROM users u
    WHERE u.id = current_user_id
    AND u.is_active = true;
END;
$$;

-- دالة إزالة المستخدم الحالي من الجلسة
CREATE OR REPLACE FUNCTION clear_current_user()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    PERFORM set_config('app.current_user_id', '', true);
END;
$$;

-- دالة تغيير كلمة المرور
CREATE OR REPLACE FUNCTION change_password(
    p_username text,
    p_old_password text,
    p_new_password text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- التحقق من كلمة المرور القديمة
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE username = p_username 
        AND password_hash = crypt(p_old_password, password_hash)
    ) THEN
        RAISE EXCEPTION 'كلمة المرور القديمة غير صحيحة';
    END IF;
    
    -- تحديث كلمة المرور
    UPDATE users 
    SET password_hash = crypt(p_new_password, gen_salt('bf')),
        updated_at = NOW()
    WHERE username = p_username;
    
    RETURN true;
END;
$$;

-- دالة إعادة تعيين كلمة المرور (للمديرين فقط)
CREATE OR REPLACE FUNCTION reset_user_password(
    p_username text,
    p_new_password text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_user_id uuid;
BEGIN
    current_user_id := (current_setting('app.current_user_id', true))::uuid;
    
    -- التحقق من أن المستخدم الحالي مدير
    IF NOT EXISTS (
        SELECT 1 FROM users 
        WHERE id = current_user_id 
        AND role = 'admin'
    ) THEN
        RAISE EXCEPTION 'ليس لديك صلاحية إعادة تعيين كلمات المرور';
    END IF;
    
    -- تحديث كلمة المرور
    UPDATE users 
    SET password_hash = crypt(p_new_password, gen_salt('bf')),
        updated_at = NOW()
    WHERE username = p_username;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'المستخدم غير موجود';
    END IF;
    
    RETURN true;
END;
$$;
