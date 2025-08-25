/*
# إنشاء التقارير المالية (قائمة الدخل والميزانية العمومية)
إنشاء دوال متقدمة في قاعدة البيانات لحساب وعرض التقارير المالية الأساسية، مع تطبيق إصلاحات أمنية.

## Query Description:
هذا الملف سيقوم بإنشاء دالتين رئيسيتين:
1.  `get_income_statement`: لحساب قائمة الدخل لفترة محددة.
2.  `get_balance_sheet`: لحساب الميزانية العمومية في تاريخ محدد.
كما يقوم بإصلاح ثغرة أمنية عن طريق تحديد مسار البحث للدوال.

## Metadata:
- Schema-Category: "Safe"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Security Implications:
- RLS Status: Enabled
- Policy Changes: No
- Auth Requirements: تعتمد على صلاحيات الوصول الحالية.
- Security Fix: يعالج تحذير "Function Search Path Mutable".

## Performance Impact:
- Indexes: لا تغييرات.
- Triggers: لا تغييرات.
- Estimated Impact: أداء جيد لحساب التقارير.
*/

-- Fix for security advisory: Function Search Path Mutable
ALTER FUNCTION public.create_journal_entry(p_entry_date date, p_description text, p_details jsonb) SET search_path = public;

-- Function to get Income Statement data
CREATE OR REPLACE FUNCTION get_income_statement(start_date date, end_date date)
RETURNS TABLE(category text, account_name text, amount numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    WITH account_balances AS (
        SELECT
            ca.id,
            ca.account_name,
            ca.account_type,
            COALESCE(SUM(jed.debit_amount), 0) as total_debit,
            COALESCE(SUM(jed.credit_amount), 0) as total_credit
        FROM
            public.chart_of_accounts ca
        JOIN
            public.journal_entry_details jed ON ca.id = jed.account_id
        JOIN
            public.journal_entries je ON jed.journal_entry_id = je.id
        WHERE
            je.entry_date BETWEEN start_date AND end_date
            AND je.is_approved = true
            AND ca.account_type IN ('revenue', 'expense')
        GROUP BY
            ca.id, ca.account_name, ca.account_type
    )
    SELECT
        CASE
            WHEN ab.account_type = 'revenue' THEN 'الإيرادات'
            ELSE 'المصاريف'
        END AS category,
        ab.account_name,
        -- For revenues, credit is positive. For expenses, debit is positive.
        CASE
            WHEN ab.account_type = 'revenue' THEN ab.total_credit - ab.total_debit
            ELSE ab.total_debit - ab.total_credit
        END AS amount
    FROM
        account_balances ab
    WHERE
        (ab.total_debit - ab.total_credit) != 0;
END;
$$;

-- Function to get Balance Sheet data
CREATE OR REPLACE FUNCTION get_balance_sheet(as_of_date date)
RETURNS TABLE(category text, sub_category text, account_name text, balance numeric)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    RETURN QUERY
    WITH balances AS (
        SELECT
            ca.id,
            ca.account_name,
            ca.account_type,
            (SELECT c.account_name FROM public.chart_of_accounts c WHERE c.id = ca.parent_account_id) as parent_name,
            COALESCE(SUM(jed.debit_amount) - SUM(jed.credit_amount), 0) as final_balance
        FROM
            public.chart_of_accounts ca
        LEFT JOIN
            public.journal_entry_details jed ON ca.id = jed.account_id
        LEFT JOIN
            public.journal_entries je ON jed.journal_entry_id = je.id
        WHERE
            je.entry_date <= as_of_date
            AND je.is_approved = true
            AND ca.account_type IN ('asset', 'liability', 'equity')
        GROUP BY
            ca.id, ca.account_name, ca.account_type, ca.parent_account_id
    )
    SELECT
        CASE
            WHEN b.account_type = 'asset' THEN 'الأصول'
            WHEN b.account_type = 'liability' THEN 'الخصوم'
            ELSE 'حقوق الملكية'
        END as category,
        b.parent_name as sub_category,
        b.account_name,
        CASE
            WHEN b.account_type IN ('liability', 'equity') THEN b.final_balance * -1
            ELSE b.final_balance
        END as balance
    FROM
        balances b
    WHERE
        b.final_balance != 0;
END;
$$;
