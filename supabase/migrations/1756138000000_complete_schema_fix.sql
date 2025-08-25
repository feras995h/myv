/*
# إصلاح شامل وإعادة بناء لقاعدة البيانات
هذا الملف يقوم بإعادة بناء هيكل قاعدة البيانات بالكامل لضمان الاستقرار وحل جميع مشاكل الـ migration السابقة.

## Query Description:
سيقوم هذا الملف بحذف جميع الجداول والأنواع والدوال الموجودة (إذا كانت موجودة) ثم إعادة إنشائها بالترتيب الصحيح.
هذا يضمن بيئة نظيفة ومتوافقة مع التطبيق.
هذه العملية آمنة لبيئة التطوير ولكنها ستحذف جميع البيانات الموجودة.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "High"
- Requires-Backup: true
- Reversible: false (سيتم حذف البيانات)

## Structure Details:
- إنشاء جميع الجداول بما في ذلك `shipment_items` المفقود.
- إنشاء جميع الدوال المساعدة وسياسات الأمان (RLS).
- إدراج البيانات الأساسية (دليل الحسابات، المستخدم المدير).

## Security Implications:
- RLS Status: Enabled on all tables.
- Policy Changes: All policies are recreated correctly.
- Auth Requirements: JWT-based authentication.
*/

-- الخطوة 1: تفعيل الإضافات المطلوبة
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "public";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "public";

-- الخطوة 2: حذف الكيانات القديمة (إذا كانت موجودة) لضمان بداية نظيفة
DROP TABLE IF EXISTS "public"."expenses" CASCADE;
DROP TABLE IF EXISTS "public"."employees" CASCADE;
DROP TABLE IF EXISTS "public"."payments" CASCADE;
DROP TABLE IF EXISTS "public"."journal_entry_details" CASCADE;
DROP TABLE IF EXISTS "public"."journal_entries" CASCADE;
DROP TABLE IF EXISTS "public"."shipment_items" CASCADE;
DROP TABLE IF EXISTS "public"."shipments" CASCADE;
DROP TABLE IF EXISTS "public"."chart_of_accounts" CASCADE;
DROP TABLE IF EXISTS "public"."suppliers" CASCADE;
DROP TABLE IF EXISTS "public"."customers" CASCADE;
DROP TABLE IF EXISTS "public"."users" CASCADE;

DROP TYPE IF EXISTS "public"."user_role" CASCADE;
DROP TYPE IF EXISTS "public"."shipment_status" CASCADE;
DROP TYPE IF EXISTS "public"."payment_status" CASCADE;
DROP TYPE IF EXISTS "public"."account_type" CASCADE;

DROP FUNCTION IF EXISTS "public"."get_my_claim"(text) CASCADE;
DROP FUNCTION IF EXISTS "public"."get_my_role"() CASCADE;
DROP FUNCTION IF EXISTS "public"."authenticate_user"(text, text) CASCADE;
DROP FUNCTION IF EXISTS "public"."create_new_user"(text, text, text, user_role, text, text) CASCADE;
DROP FUNCTION IF EXISTS "public"."get_my_profile"() CASCADE;

-- الخطوة 3: إنشاء أنواع البيانات (Enums)
CREATE TYPE "public"."user_role" AS ENUM ('admin', 'financial', 'sales', 'customer_service', 'operations');
CREATE TYPE "public"."shipment_status" AS ENUM ('pending', 'processing', 'shipped', 'in_transit', 'delivered', 'cancelled');
CREATE TYPE "public"."payment_status" AS ENUM ('pending', 'paid', 'partial', 'overdue', 'cancelled');
CREATE TYPE "public"."account_type" AS ENUM ('asset', 'liability', 'equity', 'revenue', 'expense');

-- الخطوة 4: إنشاء الجداول بالترتيب الصحيح
CREATE TABLE "public"."users" (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "username" character varying(255) UNIQUE NOT NULL,
    "email" character varying(255) UNIQUE,
    "password_hash" text NOT NULL,
    "full_name" character varying(255) NOT NULL,
    "role" public.user_role NOT NULL DEFAULT 'sales',
    "phone" character varying(20),
    "is_active" boolean DEFAULT true,
    "created_by" uuid REFERENCES public.users(id),
    "created_at" timestamp with time zone DEFAULT now(),
    "updated_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE "public"."customers" (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "company_name" character varying(255) NOT NULL,
    "contact_person" character varying(255),
    "email" character varying(255),
    "phone" character varying(20),
    "address" text,
    "city" character varying(100),
    "country" character varying(100) DEFAULT 'Libya',
    "tax_number" character varying(50),
    "credit_limit" numeric(15,2) DEFAULT 0,
    "current_balance" numeric(15,2) DEFAULT 0,
    "payment_terms" integer DEFAULT 30,
    "is_active" boolean DEFAULT true,
    "created_by" uuid REFERENCES public.users(id),
    "created_at" timestamp with time zone DEFAULT now(),
    "updated_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE "public"."suppliers" (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "company_name" character varying(255) NOT NULL,
    "contact_person" character varying(255),
    "email" character varying(255),
    "phone" character varying(20),
    "address" text,
    "city" character varying(100),
    "country" character varying(100) DEFAULT 'China',
    "tax_number" character varying(50),
    "payment_terms" integer DEFAULT 30,
    "is_active" boolean DEFAULT true,
    "created_by" uuid REFERENCES public.users(id),
    "created_at" timestamp with time zone DEFAULT now(),
    "updated_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE "public"."chart_of_accounts" (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "account_code" character varying(20) UNIQUE NOT NULL,
    "account_name" character varying(255) NOT NULL,
    "account_type" public.account_type NOT NULL,
    "parent_account_id" uuid REFERENCES public.chart_of_accounts(id),
    "level" integer NOT NULL DEFAULT 1,
    "is_active" boolean DEFAULT true,
    "balance" numeric(15,2) DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE "public"."shipments" (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "shipment_number" character varying(50) UNIQUE NOT NULL,
    "customer_id" uuid REFERENCES public.customers(id) NOT NULL,
    "supplier_id" uuid REFERENCES public.suppliers(id),
    "origin_port" character varying(100) DEFAULT 'Shanghai',
    "destination_port" character varying(100) DEFAULT 'Tripoli',
    "departure_date" date,
    "arrival_date" date,
    "estimated_arrival" date,
    "status" public.shipment_status DEFAULT 'pending',
    "container_number" character varying(50),
    "seal_number" character varying(50),
    "weight_kg" numeric(10,2),
    "volume_cbm" numeric(10,2),
    "total_amount" numeric(15,2) NOT NULL,
    "paid_amount" numeric(15,2) DEFAULT 0,
    "payment_status" public.payment_status DEFAULT 'pending',
    "notes" text,
    "created_by" uuid REFERENCES public.users(id),
    "created_at" timestamp with time zone DEFAULT now(),
    "updated_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE "public"."shipment_items" (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "shipment_id" uuid REFERENCES public.shipments(id) ON DELETE CASCADE,
    "item_description" text NOT NULL,
    "quantity" integer NOT NULL,
    "unit_price" numeric(10,2) NOT NULL,
    "total_price" numeric(15,2) NOT NULL,
    "weight_kg" numeric(10,2),
    "volume_cbm" numeric(10,2),
    "hs_code" character varying(20),
    "created_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE "public"."journal_entries" (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "entry_number" character varying(50) UNIQUE NOT NULL,
    "entry_date" date NOT NULL,
    "description" text NOT NULL,
    "reference_type" character varying(50),
    "reference_id" uuid,
    "total_debit" numeric(15,2) NOT NULL,
    "total_credit" numeric(15,2) NOT NULL,
    "is_approved" boolean DEFAULT false,
    "approved_by" uuid REFERENCES public.users(id),
    "approved_at" timestamp with time zone,
    "created_by" uuid REFERENCES public.users(id),
    "created_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE "public"."journal_entry_details" (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "journal_entry_id" uuid REFERENCES public.journal_entries(id) ON DELETE CASCADE,
    "account_id" uuid REFERENCES public.chart_of_accounts(id) NOT NULL,
    "debit_amount" numeric(15,2) DEFAULT 0,
    "credit_amount" numeric(15,2) DEFAULT 0,
    "description" text,
    "created_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE "public"."payments" (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "payment_number" character varying(50) UNIQUE NOT NULL,
    "customer_id" uuid REFERENCES public.customers(id),
    "shipment_id" uuid REFERENCES public.shipments(id),
    "payment_date" date NOT NULL,
    "amount" numeric(15,2) NOT NULL,
    "payment_method" character varying(50) NOT NULL,
    "bank_account" character varying(100),
    "reference_number" character varying(100),
    "notes" text,
    "journal_entry_id" uuid REFERENCES public.journal_entries(id),
    "created_by" uuid REFERENCES public.users(id),
    "created_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE "public"."employees" (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "employee_number" character varying(20) UNIQUE NOT NULL,
    "full_name" character varying(255) NOT NULL,
    "email" character varying(255),
    "phone" character varying(20),
    "position" character varying(100),
    "department" character varying(100),
    "hire_date" date,
    "salary" numeric(10,2),
    "is_active" boolean DEFAULT true,
    "user_id" uuid REFERENCES public.users(id),
    "created_at" timestamp with time zone DEFAULT now(),
    "updated_at" timestamp with time zone DEFAULT now()
);

CREATE TABLE "public"."expenses" (
    "id" uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    "expense_number" character varying(50) UNIQUE NOT NULL,
    "expense_date" date NOT NULL,
    "category" character varying(100) NOT NULL,
    "description" text NOT NULL,
    "amount" numeric(15,2) NOT NULL,
    "supplier_id" uuid REFERENCES public.suppliers(id),
    "account_id" uuid REFERENCES public.chart_of_accounts(id),
    "journal_entry_id" uuid REFERENCES public.journal_entries(id),
    "receipt_attached" boolean DEFAULT false,
    "created_by" uuid REFERENCES public.users(id),
    "created_at" timestamp with time zone DEFAULT now()
);

-- الخطوة 5: إدراج البيانات الأساسية
-- إدراج المستخدم المدير
INSERT INTO public.users (username, full_name, password_hash, role, is_active)
VALUES ('admin', 'مدير النظام', crypt('admin123', gen_salt('bf')), 'admin', true);

-- إدراج دليل الحسابات
INSERT INTO chart_of_accounts (account_code, account_name, account_type, level) VALUES
('1000', 'الأصول', 'asset', 1),
('1100', 'الأصول المتداولة', 'asset', 2),
('1110', 'النقدية وما في حكمها', 'asset', 3),
('1111', 'الصندوق الرئيسي', 'asset', 4),
('1120', 'العملاء والذمم المدينة', 'asset', 3),
('1200', 'الأصول الثابتة', 'asset', 2),
('2000', 'الخصوم', 'liability', 1),
('2100', 'الخصوم المتداولة', 'liability', 2),
('2110', 'الموردين والذمم الدائنة', 'liability', 3),
('3000', 'حقوق الملكية', 'equity', 1),
('3100', 'رأس المال', 'equity', 2),
('4000', 'الإيرادات', 'revenue', 1),
('4100', 'إيرادات التشغيل', 'revenue', 2),
('5000', 'المصاريف', 'expense', 1),
('5100', 'تكلفة الخدمات المباعة', 'expense', 2);
-- يمكنك إضافة باقي دليل الحسابات هنا إذا أردت

-- الخطوة 6: إنشاء الدوال المساعدة
CREATE OR REPLACE FUNCTION public.get_my_claim(claim TEXT)
RETURNS JSONB
LANGUAGE sql STABLE
AS $$
  SELECT coalesce(current_setting('request.jwt.claims', true)::jsonb ->> claim, null)::jsonb;
$$;

CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS user_role
LANGUAGE sql STABLE
AS $$
  SELECT (get_my_claim('user_role'))::text::user_role;
$$;

CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS SETOF public.users
LANGUAGE sql STABLE
AS $$
  SELECT * FROM public.users WHERE id = (current_setting('request.jwt.claims', true)::jsonb ->> 'sub')::uuid;
$$;

CREATE OR REPLACE FUNCTION public.authenticate_user(p_username TEXT, p_password TEXT)
RETURNS json
LANGUAGE plpgsql
AS $$
DECLARE
  user_record public.users;
  token_payload json;
  token text;
BEGIN
  SELECT * INTO user_record FROM public.users WHERE username = p_username;

  IF user_record IS NULL THEN
    RAISE EXCEPTION 'اسم المستخدم أو كلمة المرور غير صحيحة';
  END IF;

  IF user_record.password_hash != crypt(p_password, user_record.password_hash) THEN
    RAISE EXCEPTION 'اسم المستخدم أو كلمة المرور غير صحيحة';
  END IF;

  token_payload := json_build_object(
    'sub', user_record.id,
    'user_role', user_record.role,
    'aud', 'authenticated',
    'exp', extract(epoch from now() + interval '1 day')
  );

  token := sign(token_payload, current_setting('secrets.jwt_secret'));

  RETURN json_build_object('user', row_to_json(user_record), 'token', token);
END;
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
AS $$
DECLARE
  new_user public.users;
  creator_id uuid := (current_setting('request.jwt.claims', true)::jsonb ->> 'sub')::uuid;
BEGIN
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

-- الخطوة 7: تفعيل RLS على جميع الجداول
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chart_of_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipment_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entry_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

-- الخطوة 8: إنشاء سياسات RLS
-- سياسات جدول المستخدمين
CREATE POLICY "Allow admin to manage users" ON public.users FOR ALL
  USING (get_my_role() = 'admin')
  WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "Allow users to view their own profile" ON public.users FOR SELECT
  USING (id = (current_setting('request.jwt.claims', true)::jsonb ->> 'sub')::uuid);

-- سياسات جدول العملاء
CREATE POLICY "Allow admin and sales to manage customers" ON public.customers FOR ALL
  USING (get_my_role() IN ('admin', 'sales', 'customer_service'))
  WITH CHECK (get_my_role() IN ('admin', 'sales'));
CREATE POLICY "Allow financial to view customers" ON public.customers FOR SELECT
  USING (get_my_role() = 'financial');

-- سياسات جدول الشحنات
CREATE POLICY "Allow all authenticated users to view shipments" ON public.shipments FOR SELECT
  USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin, sales, and operations to manage shipments" ON public.shipments FOR ALL
  USING (get_my_role() IN ('admin', 'sales', 'operations', 'customer_service'))
  WITH CHECK (get_my_role() IN ('admin', 'sales', 'operations'));

-- سياسات جدول عناصر الشحنة (الجدول المفقود)
CREATE POLICY "Allow all authenticated users to view shipment items" ON public.shipment_items FOR SELECT
  USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin, sales, and operations to manage shipment items" ON public.shipment_items FOR ALL
  USING (get_my_role() IN ('admin', 'sales', 'operations'))
  WITH CHECK (get_my_role() IN ('admin', 'sales', 'operations'));

-- سياسات عامة للقراءة للجداول المحاسبية (للمدير والقسم المالي)
CREATE POLICY "Allow admin and financial to view financial data" ON public.chart_of_accounts FOR SELECT USING (get_my_role() IN ('admin', 'financial'));
CREATE POLICY "Allow admin and financial to view journal entries" ON public.journal_entries FOR SELECT USING (get_my_role() IN ('admin', 'financial'));
CREATE POLICY "Allow admin and financial to view journal details" ON public.journal_entry_details FOR SELECT USING (get_my_role() IN ('admin', 'financial'));
CREATE POLICY "Allow admin and financial to view payments" ON public.payments FOR SELECT USING (get_my_role() IN ('admin', 'financial'));
CREATE POLICY "Allow admin and financial to view expenses" ON public.expenses FOR SELECT USING (get_my_role() IN ('admin', 'financial'));

-- سياسات الإدارة للجداول المحاسبية (للمدير والقسم المالي)
CREATE POLICY "Allow admin and financial to manage financial data" ON public.chart_of_accounts FOR ALL USING (get_my_role() IN ('admin', 'financial')) WITH CHECK (get_my_role() IN ('admin', 'financial'));
CREATE POLICY "Allow admin and financial to manage journal entries" ON public.journal_entries FOR ALL USING (get_my_role() IN ('admin', 'financial')) WITH CHECK (get_my_role() IN ('admin', 'financial'));
CREATE POLICY "Allow admin and financial to manage journal details" ON public.journal_entry_details FOR ALL USING (get_my_role() IN ('admin', 'financial')) WITH CHECK (get_my_role() IN ('admin', 'financial'));
CREATE POLICY "Allow admin and financial to manage payments" ON public.payments FOR ALL USING (get_my_role() IN ('admin', 'financial')) WITH CHECK (get_my_role() IN ('admin', 'financial'));
CREATE POLICY "Allow admin and financial to manage expenses" ON public.expenses FOR ALL USING (get_my_role() IN ('admin', 'financial')) WITH CHECK (get_my_role() IN ('admin', 'financial'));

-- سياسات الموردين والموظفين
CREATE POLICY "Allow authenticated to view suppliers" ON public.suppliers FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin to manage suppliers" ON public.suppliers FOR ALL USING (get_my_role() = 'admin') WITH CHECK (get_my_role() = 'admin');
CREATE POLICY "Allow admin to manage employees" ON public.employees FOR ALL USING (get_my_role() = 'admin') WITH CHECK (get_my_role() = 'admin');
