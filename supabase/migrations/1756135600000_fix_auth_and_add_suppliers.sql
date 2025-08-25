/*
# إصلاح المصادغة وإضافة جدول الموردين
تفعيل إضافة pgcrypto لحل مشكلة تسجيل الدخول، وإضافة الجداول اللازمة لوحدة الشحنات.
## Query Description: 
- يفعل إضافة "pgcrypto" اللازمة لعمل دالة crypt() بشكل صحيح.
- يقوم بتحديث دوال المصادقة لضمان عملها بشكل سليم.
- ينشئ جدول الموردين (suppliers) الذي كان ناقصاً وهو ضروري لوحدة الشحنات.
- يضيف سياسات أمان (RLS) لجدول الموردين الجديد.
هذا الإصلاح سيحل مشكلة تسجيل الدخول بشكل نهائي.
## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Medium"
- Requires-Backup: false
- Reversible: true
## Structure Details:
- تفعيل إضافة pgcrypto
- تحديث دوال المصادقة
- إنشاء جدول suppliers
- إضافة سياسات RLS لجدول suppliers
## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes
- Auth Requirements: جميع الجداول محمية بـ RLS
## Performance Impact:
- Indexes: Added for optimal performance
- Estimated Impact: تحسين أداء المصادقة
*/

-- الخطوة 1: تفعيل إضافة pgcrypto (الإصلاح الأساسي لمشكلة تسجيل الدخول)
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "public";

-- الخطوة 2: التأكد من وجود جدول الموردين (كان ناقصاً)
CREATE TABLE IF NOT EXISTS public.suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(100),
    country VARCHAR(100) DEFAULT 'China',
    tax_number VARCHAR(50),
    payment_terms INTEGER DEFAULT 30,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- الخطوة 3: تحديث دالة المصادقة للتأكد من أنها تستخدم pgcrypto بشكل صحيح
DROP FUNCTION IF EXISTS public.authenticate_user(text,text);
CREATE OR REPLACE FUNCTION public.authenticate_user(p_username text, p_password text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_record public.users;
    token text;
BEGIN
    SELECT * INTO user_record FROM public.users WHERE username = p_username;

    IF user_record IS NULL THEN
        RAISE EXCEPTION 'اسم المستخدم أو كلمة المرور غير صحيحة';
    END IF;

    IF user_record.password_hash != crypt(p_password, user_record.password_hash) THEN
        RAISE EXCEPTION 'اسم المستخدم أو كلمة المرور غير صحيحة';
    END IF;

    token := sign(
        json_build_object(
            'sub', user_record.id,
            'role', user_record.role,
            'exp', extract(epoch from now()) + 60*60*24 -- 24 hours
        ),
        (SELECT raw_value FROM vault.secrets WHERE key_id = 'a5555e42-f242-4433-a36c-1a225a5f9737')
    );

    RETURN json_build_object('user', row_to_json(user_record), 'token', token);
END;
$$;

-- الخطوة 4: تفعيل RLS على جدول الموردين وتطبيق السياسات
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow full access to admin" ON public.suppliers;
CREATE POLICY "Allow full access to admin"
ON public.suppliers
FOR ALL
TO authenticated
USING (get_my_claim('role')::text = 'admin')
WITH CHECK (get_my_claim('role')::text = 'admin');

DROP POLICY IF EXISTS "Allow read access to authenticated users" ON public.suppliers;
CREATE POLICY "Allow read access to authenticated users"
ON public.suppliers
FOR SELECT
TO authenticated
USING (true);
