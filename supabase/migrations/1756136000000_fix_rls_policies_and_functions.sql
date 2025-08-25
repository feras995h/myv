/*
# إصلاح سياسات الأمان (RLS) ودوال المصادقة
إعادة كتابة سياسات RLS لاستخدام دوال Supabase الرسمية (auth.uid(), auth.jwt()) بدلاً من الدالة المخصصة get_my_claim.

## Query Description:
هذا الملف سيقوم بإصلاح خطأ "function get_my_claim(unknown) does not exist" عن طريق:
1.  حذف جميع سياسات RLS القديمة التي تعتمد على الدالة الخاطئة.
2.  إنشاء سياسات RLS جديدة وصحيحة لجميع الجداول.
3.  تحديث الدوال المساعدة مثل get_my_profile لتعمل بشكل صحيح.
هذا الإصلاح سيؤمن قاعدة البيانات بشكل صحيح ويحل أخطاء الـ migration.

## Metadata:
- Schema-Category: "Security"
- Impact-Level: "High"
- Requires-Backup: true
- Reversible: false

## Structure Details:
- إعادة تعريف سياسات RLS لجداول: users, customers, suppliers, shipments, chart_of_accounts, journal_entries, payments, employees, expenses.
- تحديث الدوال: get_my_profile.

## Security Implications:
- RLS Status: Enabled and Corrected
- Policy Changes: Yes
- Auth Requirements: All tables are now correctly protected by RLS policies based on user roles and ID.
*/

-- تفعيل RLS على جميع الجداول (احتياطي)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chart_of_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;

-- حذف السياسات القديمة (إذا كانت موجودة) لتجنب التعارض
DROP POLICY IF EXISTS "Allow all for admin" ON public.users;
DROP POLICY IF EXISTS "Allow read for authenticated users" ON public.users;
DROP POLICY IF EXISTS "Users can update their own data" ON public.users;
DROP POLICY IF EXISTS "Allow all for admin and financial" ON public.customers;
DROP POLICY IF EXISTS "Allow read for sales and customer service" ON public.customers;
DROP POLICY IF EXISTS "Allow all for admin and financial" ON public.suppliers;
DROP POLICY IF EXISTS "Allow read for operations" ON public.suppliers;
DROP POLICY IF EXISTS "Allow all for admin" ON public.shipments;
DROP POLICY IF EXISTS "Allow read for all authenticated" ON public.shipments;
DROP POLICY IF EXISTS "Allow modification for relevant roles" ON public.shipments;
DROP POLICY IF EXISTS "Allow all for admin and financial" ON public.chart_of_accounts;
DROP POLICY IF EXISTS "Allow all for admin and financial" ON public.journal_entries;
DROP POLICY IF EXISTS "Allow all for admin and financial" ON public.payments;
DROP POLICY IF EXISTS "Allow all for admin" ON public.employees;
DROP POLICY IF EXISTS "Allow read for financial" ON public.employees;
DROP POLICY IF EXISTS "Allow all for admin and financial" ON public.expenses;

-- دالة للحصول على دور المستخدم من التوكن
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text
LANGUAGE sql
STABLE
AS $$
  SELECT (auth.jwt() ->> 'role')::text;
$$;

-- إعادة تعريف السياسات باستخدام دوال Supabase الرسمية

-- 1. جدول المستخدمين (users)
CREATE POLICY "Allow all for admin" ON public.users
FOR ALL USING (get_my_role() = 'admin');

CREATE POLICY "Allow read for authenticated users" ON public.users
FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Users can update their own data" ON public.users
FOR UPDATE USING (id = auth.uid());

-- 2. جدول العملاء (customers)
CREATE POLICY "Allow all for admin and financial" ON public.customers
FOR ALL USING (get_my_role() IN ('admin', 'financial'));

CREATE POLICY "Allow read for sales and customer service" ON public.customers
FOR SELECT USING (get_my_role() IN ('sales', 'customer_service'));

-- 3. جدول الموردين (suppliers)
CREATE POLICY "Allow all for admin and financial" ON public.suppliers
FOR ALL USING (get_my_role() IN ('admin', 'financial'));

CREATE POLICY "Allow read for operations" ON public.suppliers
FOR SELECT USING (get_my_role() = 'operations');

-- 4. جدول الشحنات (shipments)
CREATE POLICY "Allow all for admin" ON public.shipments
FOR ALL USING (get_my_role() = 'admin');

CREATE POLICY "Allow read for all authenticated" ON public.shipments
FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Allow modification for relevant roles" ON public.shipments
FOR ALL USING (get_my_role() IN ('admin', 'sales', 'operations'));

-- 5. الجداول المالية (chart_of_accounts, journal_entries, payments, expenses)
CREATE POLICY "Allow all for admin and financial" ON public.chart_of_accounts
FOR ALL USING (get_my_role() IN ('admin', 'financial'));

CREATE POLICY "Allow all for admin and financial" ON public.journal_entries
FOR ALL USING (get_my_role() IN ('admin', 'financial'));

CREATE POLICY "Allow all for admin and financial" ON public.payments
FOR ALL USING (get_my_role() IN ('admin', 'financial'));

CREATE POLICY "Allow all for admin and financial" ON public.expenses
FOR ALL USING (get_my_role() IN ('admin', 'financial'));

-- 6. جدول الموظفين (employees)
CREATE POLICY "Allow all for admin" ON public.employees
FOR ALL USING (get_my_role() = 'admin');

CREATE POLICY "Allow read for financial" ON public.employees
FOR SELECT USING (get_my_role() = 'financial');

-- تحديث دالة get_my_profile لاستخدام auth.uid()
CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS public.users
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT *
  FROM public.users
  WHERE id = auth.uid();
$$;

-- منح الصلاحيات للدوال
GRANT EXECUTE ON FUNCTION public.get_my_role TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_profile TO authenticated;
