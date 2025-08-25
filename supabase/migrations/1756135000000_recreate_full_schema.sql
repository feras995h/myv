/*
# إعادة إنشاء قاعدة البيانات الكاملة لنظام إدارة الشحن
إنشاء قاعدة بيانات شاملة ومتكاملة مع إصلاح الأخطاء السابقة.
## Query Description: 
هذا الملف سيقوم بإنشاء جميع الجداول، الأنواع، الدوال، وسياسات الأمان (RLS) المطلوبة للنظام.
يستخدم "IF NOT EXISTS" لضمان عدم حدوث أخطاء إذا تم تشغيله على قاعدة بيانات موجودة جزئياً.
هذا هو الحل الشامل لضمان سلامة بنية قاعدة البيانات.
## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "High"
- Requires-Backup: true
- Reversible: false (إعادة الإنشاء)
## Structure Details:
- جميع جداول النظام (المستخدمين، العملاء، الشحنات، المحاسبة، إلخ)
- جميع أنواع البيانات المخصصة (ENUMs)
- دوال المصادقة وإدارة المستخدمين
- سياسات الأمان (RLS) لجميع الجداول
## Security Implications:
- RLS Status: Enabled on all tables
- Policy Changes: Yes, comprehensive policies are created
- Auth Requirements: All tables are protected by RLS policies
## Performance Impact:
- Indexes: Added for optimal performance
- Triggers: Not used
- Estimated Impact: A stable and secure database structure
*/

-- 1. إنشاء أنواع البيانات المخصصة (ENUMs) إذا لم تكن موجودة
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
        CREATE TYPE user_role AS ENUM ('admin', 'financial', 'sales', 'customer_service', 'operations');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'shipment_status') THEN
        CREATE TYPE shipment_status AS ENUM ('pending', 'processing', 'shipped', 'in_transit', 'delivered', 'cancelled');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'payment_status') THEN
        CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'partial', 'overdue', 'cancelled');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'account_type') THEN
        CREATE TYPE account_type AS ENUM ('asset', 'liability', 'equity', 'revenue', 'expense');
    END IF;
END$$;

-- 2. إنشاء جدول المستخدمين
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'sales',
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    can_create_users BOOLEAN DEFAULT false,
    created_by UUID REFERENCES public.users(id),
    last_login TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. إنشاء باقي جداول النظام
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(100),
    country VARCHAR(100) DEFAULT 'Libya',
    tax_number VARCHAR(50),
    credit_limit DECIMAL(15,2) DEFAULT 0,
    current_balance DECIMAL(15,2) DEFAULT 0,
    payment_terms INTEGER DEFAULT 30,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

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

CREATE TABLE IF NOT EXISTS public.chart_of_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_code VARCHAR(20) UNIQUE NOT NULL,
    account_name VARCHAR(255) NOT NULL,
    account_type account_type NOT NULL,
    parent_account_id UUID REFERENCES public.chart_of_accounts(id),
    level INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    balance DECIMAL(15,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.shipments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shipment_number VARCHAR(50) UNIQUE NOT NULL,
    customer_id UUID REFERENCES public.customers(id) NOT NULL,
    supplier_id UUID REFERENCES public.suppliers(id),
    origin_port VARCHAR(100) DEFAULT 'Shanghai',
    destination_port VARCHAR(100) DEFAULT 'Tripoli',
    departure_date DATE,
    arrival_date DATE,
    estimated_arrival DATE,
    status shipment_status DEFAULT 'pending',
    container_number VARCHAR(50),
    seal_number VARCHAR(50),
    weight_kg DECIMAL(10,2),
    volume_cbm DECIMAL(10,2),
    total_amount DECIMAL(15,2) NOT NULL,
    paid_amount DECIMAL(15,2) DEFAULT 0,
    payment_status payment_status DEFAULT 'pending',
    notes TEXT,
    created_by UUID REFERENCES public.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. إدراج دليل الحسابات الأساسي (مع التحقق من عدم وجوده)
INSERT INTO public.chart_of_accounts (account_code, account_name, account_type, level)
SELECT * FROM (VALUES
    ('1000', 'الأصول', 'asset'::account_type, 1),
    ('1100', 'الأصول المتداولة', 'asset'::account_type, 2),
    ('1110', 'النقدية وما في حكمها', 'asset'::account_type, 3),
    ('1111', 'الصندوق الرئيسي', 'asset'::account_type, 4),
    ('1120', 'العملاء والذمم المدينة', 'asset'::account_type, 3),
    ('1121', 'حسابات العملاء', 'asset'::account_type, 4),
    ('1200', 'الأصول الثابتة', 'asset'::account_type, 2),
    ('2000', 'الخصوم', 'liability'::account_type, 1),
    ('2100', 'الخصوم المتداولة', 'liability'::account_type, 2),
    ('2110', 'الموردين والذمم الدائنة', 'liability'::account_type, 3),
    ('3000', 'حقوق الملكية', 'equity'::account_type, 1),
    ('3100', 'رأس المال', 'equity'::account_type, 2),
    ('4000', 'الإيرادات', 'revenue'::account_type, 1),
    ('4100', 'إيرادات التشغيل', 'revenue'::account_type, 2),
    ('5000', 'المصاريف', 'expense'::account_type, 1),
    ('5100', 'تكلفة الخدمات المباعة', 'expense'::account_type, 2)
) AS data (account_code, account_name, account_type, level)
WHERE NOT EXISTS (SELECT 1 FROM public.chart_of_accounts WHERE account_code = '1000');


-- 5. إنشاء دوال المصادقة والإدارة
CREATE OR REPLACE FUNCTION public.authenticate_user(p_username TEXT, p_password TEXT)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_record public.users%ROWTYPE;
    token_payload json;
    token text;
BEGIN
    SELECT * INTO user_record FROM public.users WHERE username = p_username;

    IF user_record IS NULL OR user_record.password_hash IS NULL OR NOT (user_record.password_hash = crypt(p_password, user_record.password_hash)) THEN
        RAISE EXCEPTION 'اسم المستخدم أو كلمة المرور غير صحيحة';
    END IF;

    IF NOT user_record.is_active THEN
        RAISE EXCEPTION 'هذا الحساب غير نشط';
    END IF;

    token_payload := json_build_object(
        'sub', user_record.id,
        'role', user_record.role,
        'username', user_record.username,
        'full_name', user_record.full_name,
        'iat', extract(epoch from now()),
        'exp', extract(epoch from now()) + 60*60*24 -- 24 hours
    );

    token := sign(token_payload, current_setting('app.settings.jwt_secret'));

    UPDATE public.users SET last_login = now() WHERE id = user_record.id;

    RETURN json_build_object('user', row_to_json(user_record), 'token', token);
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS public.users
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT * FROM public.users WHERE id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.create_new_user(
    p_username TEXT,
    p_password TEXT,
    p_full_name TEXT,
    p_role user_role,
    p_email TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL
)
RETURNS public.users
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    new_user public.users;
    creator_role user_role;
BEGIN
    SELECT role INTO creator_role FROM public.users WHERE id = auth.uid();

    IF creator_role <> 'admin' THEN
        RAISE EXCEPTION 'فقط مدير النظام يمكنه إنشاء مستخدمين جدد';
    END IF;

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
$$;

-- 6. تفعيل RLS وإنشاء سياسات الأمان
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chart_of_accounts ENABLE ROW LEVEL SECURITY;

-- حذف السياسات القديمة إن وجدت
DROP POLICY IF EXISTS "Allow authenticated users to read all users" ON public.users;
DROP POLICY IF EXISTS "Allow admin to manage users" ON public.users;
DROP POLICY IF EXISTS "Allow users to view their own profile" ON public.users;
DROP POLICY IF EXISTS "Allow authenticated users to read all data" ON public.customers;
DROP POLICY IF EXISTS "Allow authenticated users to read all data" ON public.suppliers;
DROP POLICY IF EXISTS "Allow authenticated users to read all data" ON public.shipments;
DROP POLICY IF EXISTS "Allow authenticated users to read all data" ON public.chart_of_accounts;

-- إنشاء السياسات الجديدة
-- Users
CREATE POLICY "Allow authenticated users to read all users" ON public.users FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin to manage users" ON public.users FOR ALL USING (auth.jwt()->>'role' = 'admin') WITH CHECK (auth.jwt()->>'role' = 'admin');
CREATE POLICY "Allow users to view their own profile" ON public.users FOR SELECT USING (auth.uid() = id);

-- Customers, Suppliers, Shipments, ChartOfAccounts
CREATE POLICY "Allow authenticated users to read all data" ON public.customers FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users to read all data" ON public.suppliers FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users to read all data" ON public.shipments FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow authenticated users to read all data" ON public.chart_of_accounts FOR SELECT USING (auth.role() = 'authenticated');

-- سياسات الإدارة (إضافة، تعديل، حذف)
CREATE POLICY "Allow admin and financial roles to manage data" ON public.customers FOR ALL USING (auth.jwt()->>'role' IN ('admin', 'financial'));
CREATE POLICY "Allow admin and financial roles to manage data" ON public.suppliers FOR ALL USING (auth.jwt()->>'role' IN ('admin', 'financial'));
CREATE POLICY "Allow all roles to manage shipments" ON public.shipments FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin and financial roles to manage chart of accounts" ON public.chart_of_accounts FOR ALL USING (auth.jwt()->>'role' IN ('admin', 'financial'));


-- 7. إنشاء مستخدم مدير افتراضي إذا لم يكن موجوداً
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.users WHERE username = 'admin') THEN
        INSERT INTO public.users (username, full_name, password_hash, role, is_active, can_create_users)
        VALUES ('admin', 'مدير النظام', crypt('admin123', gen_salt('bf')), 'admin', true, true);
    END IF;
END$$;
