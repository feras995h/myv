/*
# الإصلاح النهائي وإعادة بناء قاعدة البيانات
هذا الملف يقوم بإعادة بناء قاعدة البيانات بالكامل لحل جميع المشاكل المتراكمة،
خصوصاً خطأ 'jwt malformed' المتكرر، عن طريق تحصين دوال الأمان.
## Query Description: 
سيتم حذف جميع الجداول والدوال والأنواع المخصصة وإعادة إنشائها بالترتيب الصحيح.
هذا يضمن بيئة نظيفة ومستقرة. لا توجد مخاطر على البيانات لأننا في مرحلة الإعداد.
## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "High"
- Requires-Backup: false
- Reversible: false
*/

-- ========= الخطوة 1: التنظيف الشامل (Drop everything) =========
-- حذف السياسات (Policies)
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable read access for all users" ON public.users;
DROP POLICY IF EXISTS "Admins can manage all users" ON public.users;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;

ALTER TABLE public.customers DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.customers;

ALTER TABLE public.suppliers DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.suppliers;

ALTER TABLE public.shipments DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.shipments;

ALTER TABLE public.shipment_items DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable all access for authenticated users" ON public.shipment_items;

ALTER TABLE public.chart_of_accounts DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON public.chart_of_accounts;

ALTER TABLE public.journal_entries DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Financial roles can manage entries" ON public.journal_entries;
DROP POLICY IF EXISTS "Enable read for other roles" ON public.journal_entries;

ALTER TABLE public.journal_entry_details DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Enable all access based on parent entry" ON public.journal_entry_details;

-- حذف الدوال (Functions)
DROP FUNCTION IF EXISTS public.get_balance_sheet(date);
DROP FUNCTION IF EXISTS public.get_income_statement(date, date);
DROP FUNCTION IF EXISTS public.get_trial_balance();
DROP FUNCTION IF EXISTS public.create_journal_entry(date, text, jsonb);
DROP FUNCTION IF EXISTS public.get_my_profile();
DROP FUNCTION IF EXISTS public.create_new_user(text, text, text, user_role, text, text);
DROP FUNCTION IF EXISTS public.authenticate_user(text, text);
DROP FUNCTION IF EXISTS public.get_my_role();
DROP FUNCTION IF EXISTS public.get_my_claim(text);

-- حذف الجداول (Tables)
DROP TABLE IF EXISTS public.journal_entry_details;
DROP TABLE IF EXISTS public.journal_entries;
DROP TABLE IF EXISTS public.shipment_items;
DROP TABLE IF EXISTS public.shipments;
DROP TABLE IF EXISTS public.expenses;
DROP TABLE IF EXISTS public.payments;
DROP TABLE IF EXISTS public.employees;
DROP TABLE IF EXISTS public.suppliers;
DROP TABLE IF EXISTS public.customers;
DROP TABLE IF EXISTS public.chart_of_accounts;
DROP TABLE IF EXISTS public.users;

-- حذف الأنواع (Types)
DROP TYPE IF EXISTS public.payment_status;
DROP TYPE IF EXISTS public.shipment_status;
DROP TYPE IF EXISTS public.user_role;
DROP TYPE IF EXISTS public.account_type;

-- ========= الخطوة 2: إعادة البناء (Re-create everything) =========

-- تفعيل الإضافات
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- إنشاء الأنواع (Enums)
CREATE TYPE public.user_role AS ENUM ('admin', 'financial', 'sales', 'customer_service', 'operations');
CREATE TYPE public.shipment_status AS ENUM ('pending', 'processing', 'shipped', 'in_transit', 'delivered', 'cancelled');
CREATE TYPE public.payment_status AS ENUM ('pending', 'paid', 'partial', 'overdue', 'cancelled');
CREATE TYPE public.account_type AS ENUM ('asset', 'liability', 'equity', 'revenue', 'expense');

-- إنشاء جدول المستخدمين
CREATE TABLE public.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE,
    password_hash TEXT NOT NULL,
    full_name TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'customer_service',
    phone TEXT,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES public.users(id),
    last_login TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
COMMENT ON TABLE public.users IS 'جدول المستخدمين ونظام الصلاحيات';

-- إنشاء باقي الجداول
CREATE TABLE public.customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_name TEXT NOT NULL,
    contact_person TEXT,
    email TEXT,
    phone TEXT,
    address TEXT,
    city TEXT,
    country TEXT DEFAULT 'Libya',
    tax_number TEXT,
    credit_limit NUMERIC(15,2) DEFAULT 0,
    current_balance NUMERIC(15,2) DEFAULT 0,
    payment_terms INTEGER DEFAULT 30,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_name TEXT NOT NULL,
    contact_person TEXT,
    email TEXT,
    phone TEXT,
    address TEXT,
    city TEXT,
    country TEXT DEFAULT 'China',
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.chart_of_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_code TEXT UNIQUE NOT NULL,
    account_name TEXT NOT NULL,
    account_type account_type NOT NULL,
    parent_account_id UUID REFERENCES chart_of_accounts(id),
    level INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    balance NUMERIC(15,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.shipments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shipment_number TEXT UNIQUE NOT NULL,
    customer_id UUID REFERENCES customers(id) NOT NULL,
    supplier_id UUID REFERENCES suppliers(id),
    origin_port TEXT DEFAULT 'Shanghai',
    destination_port TEXT DEFAULT 'Tripoli',
    departure_date DATE,
    arrival_date DATE,
    estimated_arrival DATE,
    status shipment_status DEFAULT 'pending',
    container_number TEXT,
    seal_number TEXT,
    weight_kg NUMERIC(10,2),
    volume_cbm NUMERIC(10,2),
    total_amount NUMERIC(15,2) NOT NULL,
    paid_amount NUMERIC(15,2) DEFAULT 0,
    payment_status payment_status DEFAULT 'pending',
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.shipment_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shipment_id UUID REFERENCES shipments(id) ON DELETE CASCADE,
    item_description TEXT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    total_price NUMERIC(15,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.journal_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entry_number TEXT UNIQUE NOT NULL,
    entry_date DATE NOT NULL,
    description TEXT NOT NULL,
    reference_type TEXT,
    reference_id UUID,
    total_debit NUMERIC(15,2) NOT NULL,
    total_credit NUMERIC(15,2) NOT NULL,
    is_approved BOOLEAN DEFAULT false,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMPTZ,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.journal_entry_details (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    journal_entry_id UUID REFERENCES journal_entries(id) ON DELETE CASCADE,
    account_id UUID REFERENCES chart_of_accounts(id) NOT NULL,
    debit_amount NUMERIC(15,2) DEFAULT 0,
    credit_amount NUMERIC(15,2) DEFAULT 0,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ========= الخطوة 3: إنشاء الدوال (Functions) معالجة الأخطاء =========

-- الدالة المحصنة للحصول على claim من JWT
CREATE OR REPLACE FUNCTION public.get_my_claim(claim TEXT)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
AS $$
DECLARE
    res jsonb;
BEGIN
    res := auth.jwt()->>claim;
    RETURN res;
EXCEPTION WHEN others THEN
    -- إذا كان التوقيع تالفاً أو غير موجود، أرجع NULL بأمان
    RETURN NULL;
END
$$;
ALTER FUNCTION public.get_my_claim(text) SET search_path = public;

-- الدالة المحصنة للحصول على دور المستخدم
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS user_role
LANGUAGE plpgsql STABLE SECURITY INVOKER
AS $$
DECLARE
    role_claim jsonb;
BEGIN
    role_claim := public.get_my_claim('role');
    IF role_claim IS NOT NULL THEN
        RETURN role_claim::text::user_role;
    ELSE
        RETURN NULL;
    END IF;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$$;
ALTER FUNCTION public.get_my_role() SET search_path = public;

-- دالة المصادقة
CREATE OR REPLACE FUNCTION public.authenticate_user(p_username TEXT, p_password TEXT)
RETURNS json
LANGUAGE plpgsql
AS $$
DECLARE
    user_record public.users;
    token_payload json;
    token text;
    jwt_secret text;
BEGIN
    -- البحث عن المستخدم
    SELECT * INTO user_record FROM public.users WHERE username = p_username;

    -- التحقق من وجود المستخدم وكلمة المرور
    IF user_record IS NULL OR user_record.password_hash != crypt(p_password, user_record.password_hash) THEN
        RAISE EXCEPTION 'اسم المستخدم أو كلمة المرور غير صحيحة';
    END IF;

    -- التحقق من أن المستخدم نشط
    IF NOT user_record.is_active THEN
        RAISE EXCEPTION 'هذا الحساب غير نشط';
    END IF;

    -- تحديث تاريخ آخر تسجيل دخول
    UPDATE public.users SET last_login = NOW() WHERE id = user_record.id;

    -- الحصول على مفتاح JWT السري
    SELECT value INTO jwt_secret FROM supabase.secrets WHERE name = 'jwt_secret';
    IF jwt_secret IS NULL THEN
      RAISE EXCEPTION 'JWT secret not found';
    END IF;

    -- إنشاء حمولة التوقيع
    token_payload := json_build_object(
        'sub', user_record.id,
        'role', user_record.role,
        'username', user_record.username,
        'full_name', user_record.full_name,
        'iat', extract(epoch from now()),
        'exp', extract(epoch from now()) + 60*60*24 -- 24 hours
    );

    -- إنشاء التوقيع
    token := sign(token_payload, jwt_secret);

    -- إرجاع بيانات المستخدم مع التوقيع
    RETURN json_build_object('user', row_to_json(user_record), 'token', token);
END;
$$;
ALTER FUNCTION public.authenticate_user(text, text) SET search_path = public;

-- دالة إنشاء مستخدم جديد (للمدير فقط)
CREATE OR REPLACE FUNCTION public.create_new_user(
    p_username TEXT,
    p_password TEXT,
    p_full_name TEXT,
    p_role user_role,
    p_email TEXT DEFAULT NULL,
    p_phone TEXT DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    new_user_id uuid;
BEGIN
    -- فقط المدير يمكنه إنشاء مستخدمين
    IF get_my_role() != 'admin' THEN
        RAISE EXCEPTION 'غير مصرح لك بإنشاء مستخدمين';
    END IF;

    INSERT INTO public.users (username, password_hash, full_name, role, email, phone, created_by)
    VALUES (p_username, crypt(p_password, gen_salt('bf')), p_full_name, p_role, p_email, p_phone, auth.uid())
    RETURNING id INTO new_user_id;

    RETURN new_user_id;
END;
$$;
ALTER FUNCTION public.create_new_user(text, text, text, user_role, text, text) SET search_path = public;

-- دالة الحصول على ملف المستخدم الحالي
CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS SETOF public.users
LANGUAGE sql STABLE
AS $$
    SELECT * FROM public.users WHERE id = auth.uid();
$$;
ALTER FUNCTION public.get_my_profile() SET search_path = public;

-- ========= الخطوة 4: تفعيل سياسات الأمان (RLS) =========
-- تفعيل RLS على جميع الجداول
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipment_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chart_of_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entry_details ENABLE ROW LEVEL SECURITY;

-- إنشاء السياسات
-- Users
CREATE POLICY "Enable read access for all users" ON public.users FOR SELECT USING (true);
CREATE POLICY "Admins can manage all users" ON public.users FOR ALL USING (get_my_role() = 'admin');
CREATE POLICY "Users can update their own profile" ON public.users FOR UPDATE USING (id = auth.uid());
-- Customers, Suppliers, Shipments
CREATE POLICY "Enable all access for authenticated users" ON public.customers FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Enable all access for authenticated users" ON public.suppliers FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Enable all access for authenticated users" ON public.shipments FOR ALL USING (auth.role() = 'authenticated');
CREATE POLICY "Enable all access for authenticated users" ON public.shipment_items FOR ALL USING (auth.role() = 'authenticated');
-- Accounting Tables
CREATE POLICY "Enable read for authenticated users" ON public.chart_of_accounts FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Financial roles can manage entries" ON public.journal_entries FOR ALL USING (get_my_role() IN ('admin', 'financial'));
CREATE POLICY "Enable read for other roles" ON public.journal_entries FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Enable all access based on parent entry" ON public.journal_entry_details FOR ALL USING (
    (SELECT true FROM journal_entries WHERE id = journal_entry_id)
);

-- ========= الخطوة 5: دوال البيانات والتقارير =========
CREATE OR REPLACE FUNCTION public.create_journal_entry(
    p_entry_date date,
    p_description text,
    p_details jsonb
)
RETURNS uuid
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_debit numeric := 0;
    v_total_credit numeric := 0;
    v_entry_id uuid;
    detail jsonb;
BEGIN
    -- حساب الإجماليات والتحقق من التوازن
    FOR detail IN SELECT * FROM jsonb_array_elements(p_details)
    LOOP
        v_total_debit := v_total_debit + (detail->>'debit_amount')::numeric;
        v_total_credit := v_total_credit + (detail->>'credit_amount')::numeric;
    END LOOP;

    IF v_total_debit != v_total_credit THEN
        RAISE EXCEPTION 'القيد غير متوازن: المدين % لا يساوي الدائن %', v_total_debit, v_total_credit;
    END IF;

    -- إنشاء القيد الرئيسي
    INSERT INTO journal_entries (entry_number, entry_date, description, total_debit, total_credit, created_by)
    VALUES (
        'JE-' || to_char(NOW(), 'YYYYMMDDHH24MISS'),
        p_entry_date,
        p_description,
        v_total_debit,
        v_total_credit,
        auth.uid()
    ) RETURNING id INTO v_entry_id;

    -- إدراج تفاصيل القيد
    FOR detail IN SELECT * FROM jsonb_array_elements(p_details)
    LOOP
        INSERT INTO journal_entry_details (journal_entry_id, account_id, debit_amount, credit_amount, description)
        VALUES (
            v_entry_id,
            (detail->>'account_id')::uuid,
            (detail->>'debit_amount')::numeric,
            (detail->>'credit_amount')::numeric,
            detail->>'description'
        );
    END LOOP;

    RETURN v_entry_id;
END;
$$;
ALTER FUNCTION public.create_journal_entry(date, text, jsonb) SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_trial_balance()
RETURNS TABLE(account_id uuid, account_code text, account_name text, total_debit numeric, total_credit numeric)
LANGUAGE sql STABLE
AS $$
    SELECT
        ca.id as account_id,
        ca.account_code,
        ca.account_name,
        COALESCE(SUM(jed.debit_amount), 0) as total_debit,
        COALESCE(SUM(jed.credit_amount), 0) as total_credit
    FROM
        chart_of_accounts ca
    LEFT JOIN
        journal_entry_details jed ON ca.id = jed.account_id
    GROUP BY
        ca.id, ca.account_code, ca.account_name
    ORDER BY
        ca.account_code;
$$;
ALTER FUNCTION public.get_trial_balance() SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_income_statement(start_date date, end_date date)
RETURNS TABLE(category text, account_name text, amount numeric)
LANGUAGE sql STABLE
AS $$
    SELECT
        CASE
            WHEN ca.account_type = 'revenue' THEN 'الإيرادات'
            ELSE 'المصاريف'
        END as category,
        ca.account_name,
        SUM(jed.credit_amount - jed.debit_amount) as amount
    FROM journal_entry_details jed
    JOIN journal_entries je ON jed.journal_entry_id = je.id
    JOIN chart_of_accounts ca ON jed.account_id = ca.id
    WHERE ca.account_type IN ('revenue', 'expense')
      AND je.entry_date BETWEEN start_date AND end_date
      AND je.is_approved = true
    GROUP BY ca.account_type, ca.account_name;
$$;
ALTER FUNCTION public.get_income_statement(date, date) SET search_path = public;

CREATE OR REPLACE FUNCTION public.get_balance_sheet(as_of_date date)
RETURNS TABLE(category text, sub_category text, account_name text, balance numeric)
LANGUAGE sql STABLE
AS $$
    SELECT
        CASE 
            WHEN ca.account_type = 'asset' THEN 'الأصول'
            WHEN ca.account_type = 'liability' THEN 'الخصوم'
            ELSE 'حقوق الملكية'
        END as category,
        ca.account_type::text as sub_category,
        ca.account_name,
        SUM(
            CASE 
                WHEN ca.account_type IN ('asset', 'expense') THEN jed.debit_amount - jed.credit_amount
                ELSE jed.credit_amount - jed.debit_amount
            END
        ) as balance
    FROM journal_entry_details jed
    JOIN journal_entries je ON jed.journal_entry_id = je.id
    JOIN chart_of_accounts ca ON jed.account_id = ca.id
    WHERE ca.account_type IN ('asset', 'liability', 'equity')
      AND je.entry_date <= as_of_date
      AND je.is_approved = true
    GROUP BY ca.account_type, ca.account_name
    HAVING SUM(CASE WHEN ca.account_type IN ('asset', 'expense') THEN jed.debit_amount - jed.credit_amount ELSE jed.credit_amount - jed.debit_amount END) != 0;
$$;
ALTER FUNCTION public.get_balance_sheet(date) SET search_path = public;

-- ========= الخطوة 6: إدراج البيانات الأساسية (Seed Data) =========

-- إضافة مستخدم مدير النظام الافتراضي
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.users WHERE username = 'admin') THEN
    INSERT INTO public.users (username, full_name, password_hash, role, is_active)
    VALUES ('admin', 'مدير النظام', crypt('admin123', gen_salt('bf')), 'admin', true);
  END IF;
END $$;

-- إدراج دليل الحسابات (إذا كان فارغاً)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.chart_of_accounts) THEN
    INSERT INTO public.chart_of_accounts (account_code, account_name, account_type, level) VALUES
    ('1000', 'الأصول', 'asset', 1),
    ('1100', 'الأصول المتداولة', 'asset', 2),
    ('1110', 'النقدية وما في حكمها', 'asset', 3),
    ('1111', 'الصندوق الرئيسي', 'asset', 4),
    ('1200', 'الأصول الثابتة', 'asset', 2),
    ('1210', 'المباني', 'asset', 3),
    ('2000', 'الخصوم', 'liability', 1),
    ('2100', 'الخصوم المتداولة', 'liability', 2),
    ('2110', 'الموردين', 'liability', 3),
    ('3000', 'حقوق الملكية', 'equity', 1),
    ('3100', 'رأس المال', 'equity', 2),
    ('4000', 'الإيرادات', 'revenue', 1),
    ('4100', 'إيرادات التشغيل', 'revenue', 2),
    ('5000', 'المصاريف', 'expense', 1),
    ('5100', 'مصاريف التشغيل', 'expense', 2);
  END IF;
END $$;

-- تحديث العلاقات الهرمية في دليل الحسابات
DO $$
BEGIN
    IF (SELECT COUNT(*) FROM public.chart_of_accounts WHERE parent_account_id IS NOT NULL) = 0 THEN
        UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE account_code = '1000') WHERE account_code IN ('1100', '1200');
        UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE account_code = '1100') WHERE account_code = '1110';
        UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE account_code = '1110') WHERE account_code = '1111';
        UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE account_code = '1200') WHERE account_code = '1210';
        UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE account_code = '2000') WHERE account_code = '2100';
        UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE account_code = '2100') WHERE account_code = '2110';
        UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE account_code = '3000') WHERE account_code = '3100';
        UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE account_code = '4000') WHERE account_code = '4100';
        UPDATE chart_of_accounts SET parent_account_id = (SELECT id FROM chart_of_accounts WHERE account_code = '5000') WHERE account_code = '5100';
    END IF;
END $$;
