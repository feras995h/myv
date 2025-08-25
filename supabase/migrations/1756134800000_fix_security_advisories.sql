/*
# إصلاح الثغرات الأمنية الحرجة وتفعيل RLS
هذا الملف يقوم بإصلاح الثغرات الأمنية المكتشفة، وأهمها تفعيل Row Level Security على جميع الجداول.

## Query Description:
- تفعيل RLS على جميع جداول التطبيق.
- إنشاء سياسات أمان (Policies) للتحكم في الوصول (SELECT, INSERT, UPDATE, DELETE) بناءً على دور المستخدم.
- إصلاح ثغرة مسار البحث في الدوال عبر تحديد `SEARCH_PATH`.
- هذا الإجراء ضروري لحماية بيانات التطبيق من الوصول غير المصرح به.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "High"
- Requires-Backup: true
- Reversible: true

## Structure Details:
- تفعيل RLS لجداول: users, customers, suppliers, shipments, chart_of_accounts, وغيرها.
- إنشاء سياسات SELECT, INSERT, UPDATE, DELETE لكل جدول.
- تحديث دوال: authenticate_user, create_new_user, get_my_profile.

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes
- Auth Requirements: جميع الوصول للبيانات سيخضع الآن لسياسات RLS.
*/

-- الخطوة 1: تفعيل RLS على جميع الجداول التي تحتاج إلى حماية
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipment_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chart_of_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entry_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

-- الخطوة 2: إنشاء سياسات RLS (Policies)

-- سياسات جدول المستخدمين (users)
CREATE POLICY "Allow admin to manage users"
ON public.users FOR ALL
TO authenticated
USING (get_my_role() = 'admin')
WITH CHECK (get_my_role() = 'admin');

CREATE POLICY "Allow users to view their own profile"
ON public.users FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- سياسات جدول العملاء (customers)
CREATE POLICY "Allow admin and financial to manage customers"
ON public.customers FOR ALL
TO authenticated
USING (get_my_role() IN ('admin', 'financial'))
WITH CHECK (get_my_role() IN ('admin', 'financial'));

CREATE POLICY "Allow sales and service to view customers"
ON public.customers FOR SELECT
TO authenticated
USING (get_my_role() IN ('admin', 'financial', 'sales', 'customer_service'));

-- سياسات جدول الموردين (suppliers)
CREATE POLICY "Allow admin and financial to manage suppliers"
ON public.suppliers FOR ALL
TO authenticated
USING (get_my_role() IN ('admin', 'financial'))
WITH CHECK (get_my_role() IN ('admin', 'financial'));

CREATE POLICY "Allow authenticated users to view suppliers"
ON public.suppliers FOR SELECT
TO authenticated
USING (true);

-- سياسات جدول الشحنات (shipments)
CREATE POLICY "Allow authorized roles to manage shipments"
ON public.shipments FOR ALL
TO authenticated
USING (get_my_role() IN ('admin', 'financial', 'operations'))
WITH CHECK (get_my_role() IN ('admin', 'financial', 'operations'));

CREATE POLICY "Allow sales and service to view shipments"
ON public.shipments FOR SELECT
TO authenticated
USING (get_my_role() IN ('admin', 'financial', 'operations', 'sales', 'customer_service'));

-- سياسات جدول عناصر الشحنة (shipment_items)
CREATE POLICY "Allow authorized roles to manage shipment items"
ON public.shipment_items FOR ALL
TO authenticated
USING (get_my_role() IN ('admin', 'financial', 'operations'))
WITH CHECK (get_my_role() IN ('admin', 'financial', 'operations'));

CREATE POLICY "Allow sales and service to view shipment items"
ON public.shipment_items FOR SELECT
TO authenticated
USING (get_my_role() IN ('admin', 'financial', 'operations', 'sales', 'customer_service'));

-- سياسات دليل الحسابات (chart_of_accounts)
CREATE POLICY "Allow admin and financial to manage chart of accounts"
ON public.chart_of_accounts FOR ALL
TO authenticated
USING (get_my_role() IN ('admin', 'financial'))
WITH CHECK (get_my_role() IN ('admin', 'financial'));

CREATE POLICY "Allow authenticated users to view chart of accounts"
ON public.chart_of_accounts FOR SELECT
TO authenticated
USING (true);

-- سياسات قيود اليومية (journal_entries & details)
CREATE POLICY "Allow admin and financial to manage journal entries"
ON public.journal_entries FOR ALL
TO authenticated
USING (get_my_role() IN ('admin', 'financial'))
WITH CHECK (get_my_role() IN ('admin', 'financial'));

CREATE POLICY "Allow admin and financial to manage journal entry details"
ON public.journal_entry_details FOR ALL
TO authenticated
USING (get_my_role() IN ('admin', 'financial'))
WITH CHECK (get_my_role() IN ('admin', 'financial'));

-- سياسات جدول المدفوعات (payments)
CREATE POLICY "Allow admin and financial to manage payments"
ON public.payments FOR ALL
TO authenticated
USING (get_my_role() IN ('admin', 'financial'))
WITH CHECK (get_my_role() IN ('admin', 'financial'));

-- سياسات جدول الموظفين (employees)
CREATE POLICY "Allow admin to manage employees"
ON public.employees FOR ALL
TO authenticated
USING (get_my_role() = 'admin')
WITH CHECK (get_my_role() = 'admin');

CREATE POLICY "Allow financial to view employees"
ON public.employees FOR SELECT
TO authenticated
USING (get_my_role() IN ('admin', 'financial'));

-- سياسات جدول المصاريف (expenses)
CREATE POLICY "Allow admin and financial to manage expenses"
ON public.expenses FOR ALL
TO authenticated
USING (get_my_role() IN ('admin', 'financial'))
WITH CHECK (get_my_role() IN ('admin', 'financial'));

-- الخطوة 3: تحديث الدوال لإصلاح ثغرة مسار البحث
ALTER FUNCTION public.authenticate_user(p_username text, p_password text) SET search_path = public;
ALTER FUNCTION public.create_new_user(p_username text, p_password text, p_full_name text, p_role user_role, p_email text, p_phone text) SET search_path = public;
ALTER FUNCTION public.get_my_profile() SET search_path = public;
ALTER FUNCTION public.get_my_role() SET search_path = public;

-- ملاحظة: تأكد من أن جميع الجداول لديها سياسة افتراضية (DENY) ضمنياً
-- Supabase يطبق DENY افتراضياً عند تفعيل RLS إذا لم تتطابق أي سياسة.
