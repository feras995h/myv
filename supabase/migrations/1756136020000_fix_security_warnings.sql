/*
# إصلاح التحذيرات الأمنية
تحديث دوال قاعدة البيانات لمعالجة التحذيرات الأمنية المتعلقة بمسار البحث (search_path).
## Query Description: 
سيقوم هذا الملف بتعيين search_path بشكل صريح لجميع الدوال المعرفة من قبل المستخدم. هذا الإجراء يمنع هجمات الاستيلاء على مسار البحث (search path hijacking) ويعتبر من أفضل الممارسات الأمنية في PostgreSQL.
## Metadata:
- Schema-Category: "Security"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true
## Security Implications:
- RLS Status: No change
- Policy Changes: No
- Auth Requirements: No change
- Details: يعالج هذا الملف ثغرة "Function Search Path Mutable" عن طريق تقييد مسار البحث للدوال.
*/

-- تعيين مسار البحث لدالة المصادقة
ALTER FUNCTION public.authenticate_user(p_username text, p_password text)
SET search_path = public, extensions;

-- تعيين مسار البحث لدالة إنشاء مستخدم جديد
ALTER FUNCTION public.create_new_user(p_username text, p_password text, p_full_name text, p_role public.user_role, p_email text, p_phone text)
SET search_path = public, extensions;

-- تعيين مسار البحث لدالة جلب ملف المستخدم
ALTER FUNCTION public.get_my_profile()
SET search_path = public, extensions;

-- تعيين مسار البحث لدالة جلب claim
ALTER FUNCTION public.get_my_claim(claim text)
SET search_path = public, extensions;

-- تعيين مسar البحث لدالة جلب دور المستخدم
ALTER FUNCTION public.get_my_role()
SET search_path = public, extensions;
