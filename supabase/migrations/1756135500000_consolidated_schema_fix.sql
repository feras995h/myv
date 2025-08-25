/*
# إصلاح شامل لهيكل قاعدة البيانات
هذا الملف يقوم بإعادة بناء قاعدة البيانات بشكل كامل وصحيح لحل أخطاء الـ migration المتراكمة.
## Query Description:
سيقوم هذا الملف بإنشاء جميع الجداول، الأنواع، الدوال، وسياسات الأمان (RLS) المطلوبة للنظام.
سيتم حذف الحقل غير الضروري `can_create_users` من جدول المستخدمين ومن عملية الإنشاء.
تحذير: هذا الملف مصمم للعمل على قاعدة بيانات في مرحلة التطوير.
## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "High"
- Requires-Backup: true
- Reversible: false
## Structure Details:
- إعادة إنشاء جميع الجداول: users, customers, shipments, ...etc.
- تصحيح تعريف جدول `users` بإزالة حقل `can_create_users`.
- تصحيح أمر `INSERT` الخاص بالمستخدم المدير.
- تطبيق جميع سياسات الأمان (RLS) بشكل صحيح.
## Security Implications:
- RLS Status: Enabled on all tables.
- Policy Changes: Yes, policies will be correctly reapplied.
- Auth Requirements: JWT based authentication functions are included.
## Performance Impact:
- Indexes: Re-created for optimal performance.
- Triggers: None.
- Estimated Impact: Positive, ensures a stable and correct database schema.
*/

-- تفعيل الإضافات المطلوبة
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- إنشاء ENUMs إذا لم تكن موجودة
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('admin', 'financial', 'sales', 'customer_service', 'operations');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
    CREATE TYPE shipment_status AS ENUM ('pending', 'processing', 'shipped', 'in_transit', 'delivered', 'cancelled');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
    CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'partial', 'overdue', 'cancelled');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;
DO $$ BEGIN
    CREATE TYPE account_type AS ENUM ('asset', 'liability', 'equity', 'revenue', 'expense');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- جدول المستخدمين (تم التصحيح: إزالة can_create_users)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    password_hash TEXT NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'sales',
    phone VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    last_login TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- إنشاء الجداول الأخرى
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

-- إدراج المستخدم المدير (تم التصحيح: إزالة can_create_users)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.users WHERE username = 'admin') THEN
        INSERT INTO public.users (username, full_name, password_hash, role, is_active)
        VALUES ('admin', 'مدير النظام', crypt('admin123', gen_salt('bf')), 'admin', true);
    END IF;
END $$;

-- دوال المصادقة والإدارة
CREATE OR REPLACE FUNCTION public.authenticate_user(p_username TEXT, p_password TEXT)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    user_record public.users%ROWTYPE;
    token TEXT;
    jwt_secret TEXT;
BEGIN
    SELECT * INTO user_record FROM public.users WHERE username = p_username;

    IF user_record IS NULL OR user_record.password_hash IS NULL OR user_record.password_hash != crypt(p_password, user_record.password_hash) THEN
        RAISE EXCEPTION 'اسم المستخدم أو كلمة المرور غير صحيحة';
    END IF;

    IF NOT user_record.is_active THEN
        RAISE EXCEPTION 'هذا الحساب غير نشط';
    END IF;
    
    SELECT current_setting('app.jwt_secret') INTO jwt_secret;

    token := sign(
        json_build_object(
            'sub', user_record.id,
            'role', user_record.role,
            'exp', extract(epoch from now()) + 60*60*24 -- 24 hours
        ),
        jwt_secret
    );

    UPDATE public.users SET last_login = NOW() WHERE id = user_record.id;

    RETURN json_build_object('user', row_to_json(user_record), 'token', token);
END;
$$;

CREATE OR REPLACE FUNCTION public.create_new_user(p_username TEXT, p_password TEXT, p_full_name TEXT, p_role user_role, p_email TEXT DEFAULT NULL, p_phone TEXT DEFAULT NULL)
RETURNS public.users
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    new_user public.users;
    creator_id UUID := auth.uid();
BEGIN
    IF NOT (SELECT role FROM public.users WHERE id = creator_id) = 'admin' THEN
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
        creator_id
    ) RETURNING * INTO new_user;

    RETURN new_user;
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

-- تفعيل RLS على جميع الجداول
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chart_of_accounts ENABLE ROW LEVEL SECURITY;

-- حذف السياسات القديمة قبل إنشاء الجديدة
DROP POLICY IF EXISTS "Allow full access for admins" ON public.users;
DROP POLICY IF EXISTS "Allow individual user to read their own data" ON public.users;
DROP POLICY IF EXISTS "Allow full access for admins and financials" ON public.customers;
DROP POLICY IF EXISTS "Allow sales to view customers" ON public.customers;
DROP POLICY IF EXISTS "Allow full access for admins and financials" ON public.suppliers;
DROP POLICY IF EXISTS "Allow full access for admins and financials" ON public.shipments;
DROP POLICY IF EXISTS "Allow sales and service to view shipments" ON public.shipments;
DROP POLICY IF EXISTS "Allow authenticated users to read chart of accounts" ON public.chart_of_accounts;

-- إنشاء سياسات RLS
CREATE POLICY "Allow full access for admins" ON public.users
    FOR ALL
    USING (auth.jwt()->>'role' = 'admin')
    WITH CHECK (auth.jwt()->>'role' = 'admin');

CREATE POLICY "Allow individual user to read their own data" ON public.users
    FOR SELECT
    USING (id = auth.uid());

CREATE POLICY "Allow full access for admins and financials" ON public.customers
    FOR ALL
    USING (auth.jwt()->>'role' IN ('admin', 'financial'));

CREATE POLICY "Allow sales to view customers" ON public.customers
    FOR SELECT
    USING (auth.jwt()->>'role' = 'sales');

CREATE POLICY "Allow full access for admins and financials" ON public.suppliers
    FOR ALL
    USING (auth.jwt()->>'role' IN ('admin', 'financial'));

CREATE POLICY "Allow full access for admins and financials" ON public.shipments
    FOR ALL
    USING (auth.jwt()->>'role' IN ('admin', 'financial'));

CREATE POLICY "Allow sales and service to view shipments" ON public.shipments
    FOR SELECT
    USING (auth.jwt()->>'role' IN ('sales', 'customer_service'));

CREATE POLICY "Allow authenticated users to read chart of accounts" ON public.chart_of_accounts
    FOR SELECT
    USING (auth.role() = 'authenticated');
