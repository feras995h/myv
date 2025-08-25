/*
# إصلاح دوال RLS المساعدة
إنشاء الدوال المساعدة get_my_claim و get_my_role التي تحتاجها سياسات الأمان.
## Query Description: 
هذا الملف سيقوم بإنشاء دالتين مساعدتين ضروريتين لعمل سياسات الأمان على مستوى الصف (RLS).
سيتم أيضاً التأكد من تفعيل إضافة pgcrypto اللازمة للمصادقة.
هذا الإصلاح ضروري لحل الخطأ "function get_my_claim does not exist".
لا توجد مخاطر على البيانات الموجودة.
## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true
## Structure Details:
- إنشاء دالة get_my_claim
- إنشاء دالة get_my_role
- إعادة تطبيق سياسات الأمان على الجداول
## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes (Re-applying existing policies to use new functions)
- Auth Requirements: JWT based authentication
## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: تحسين أمان واستقرار النظام
*/

-- تفعيل الإضافات المطلوبة
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";

-- Helper function to get a specific claim from the JWT
CREATE OR REPLACE FUNCTION public.get_my_claim(claim TEXT)
RETURNS JSONB
LANGUAGE sql STABLE
AS $$
  SELECT COALESCE(NULLIF(current_setting('request.jwt.claims', true), '')::JSONB ->> claim, NULL)::JSONB;
$$;

-- Helper function to get the role of the current user
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT
LANGUAGE sql STABLE
AS $$
  SELECT COALESCE(NULLIF(current_setting('request.jwt.claims', true), '')::JSONB ->> 'role', NULL)::TEXT;
$$;

-- إعادة تفعيل RLS وإنشاء السياسات لضمان استخدام الدوال الجديدة

-- جدول المستخدمين
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can manage all users" ON public.users;
CREATE POLICY "Admins can manage all users" ON public.users FOR ALL
  USING (get_my_role() = 'admin');
DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;
CREATE POLICY "Users can view their own profile" ON public.users FOR SELECT
  USING (auth.uid() = id);
DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
CREATE POLICY "Users can update their own profile" ON public.users FOR UPDATE
  USING (auth.uid() = id);

-- جدول العملاء
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated users can manage customers" ON public.customers;
CREATE POLICY "Authenticated users can manage customers" ON public.customers FOR ALL
  USING (auth.role() = 'authenticated');

-- جدول الموردين
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated users can manage suppliers" ON public.suppliers;
CREATE POLICY "Authenticated users can manage suppliers" ON public.suppliers FOR ALL
  USING (auth.role() = 'authenticated');

-- جدول الشحنات
ALTER TABLE public.shipments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated users can manage shipments" ON public.shipments;
CREATE POLICY "Authenticated users can manage shipments" ON public.shipments FOR ALL
  USING (auth.role() = 'authenticated');

-- جدول عناصر الشحنة
ALTER TABLE public.shipment_items ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Authenticated users can manage shipment items" ON public.shipment_items;
CREATE POLICY "Authenticated users can manage shipment items" ON public.shipment_items FOR ALL
  USING (auth.role() = 'authenticated');

-- جدول دليل الحسابات
ALTER TABLE public.chart_of_accounts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Financial team and admins can manage accounts" ON public.chart_of_accounts;
CREATE POLICY "Financial team and admins can manage accounts" ON public.chart_of_accounts FOR ALL
  USING (get_my_role() IN ('admin', 'financial'));
DROP POLICY IF EXISTS "Authenticated users can view accounts" ON public.chart_of_accounts;
CREATE POLICY "Authenticated users can view accounts" ON public.chart_of_accounts FOR SELECT
  USING (auth.role() = 'authenticated');

-- جدول قيود اليومية
ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Financial team and admins can manage journal entries" ON public.journal_entries;
CREATE POLICY "Financial team and admins can manage journal entries" ON public.journal_entries FOR ALL
  USING (get_my_role() IN ('admin', 'financial'));

-- تفاصيل قيود اليومية
ALTER TABLE public.journal_entry_details ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Financial team and admins can manage journal entry details" ON public.journal_entry_details;
CREATE POLICY "Financial team and admins can manage journal entry details" ON public.journal_entry_details FOR ALL
  USING (get_my_role() IN ('admin', 'financial'));

-- جدول المدفوعات
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Financial team and admins can manage payments" ON public.payments;
CREATE POLICY "Financial team and admins can manage payments" ON public.payments FOR ALL
  USING (get_my_role() IN ('admin', 'financial'));

-- جدول الموظفين
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Admins can manage employees" ON public.employees;
CREATE POLICY "Admins can manage employees" ON public.employees FOR ALL
  USING (get_my_role() = 'admin');

-- جدول المصاريف
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Financial team and admins can manage expenses" ON public.expenses;
CREATE POLICY "Financial team and admins can manage expenses" ON public.expenses FOR ALL
  USING (get_my_role() IN ('admin', 'financial'));
