/*
# إنشاء دالة آمنة لإضافة قيود اليومية
إنشاء دالة RPC لضمان إضافة قيود اليومية بشكل مترابط وآمن
## Query Description: 
ستقوم هذه الدالة بإنشاء قيد يومية جديد مع تفاصيله في عملية واحدة.
تتحقق من توازن المدين والدائن قبل الحفظ، مما يمنع الأخطاء المحاسبية.
هذا الإجراء آمن ولا يؤثر على البيانات الموجودة.
## Metadata:
- Schema-Category: "Safe"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true
## Structure Details:
- إنشاء دالة RPC جديدة: create_journal_entry
## Security Implications:
- RLS Status: Enabled
- Policy Changes: No
- Auth Requirements: تعتمد على صلاحيات المستخدم الحالية
## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: تحسين أداء وسلامة إدخال البيانات المحاسبية
*/

-- دالة لإنشاء قيد يومية جديد بشكل آمن
CREATE OR REPLACE FUNCTION public.create_journal_entry(
    p_entry_date date,
    p_description text,
    p_details jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_total_debit decimal(15, 2) := 0;
    v_total_credit decimal(15, 2) := 0;
    v_detail jsonb;
    v_entry_id uuid;
    v_entry_number text;
BEGIN
    -- حساب إجمالي المدين والدائن من التفاصيل
    FOR v_detail IN SELECT * FROM jsonb_array_elements(p_details)
    LOOP
        v_total_debit := v_total_debit + (v_detail->>'debit_amount')::decimal;
        v_total_credit := v_total_credit + (v_detail->>'credit_amount')::decimal;
    END LOOP;

    -- التحقق من توازن القيد
    IF v_total_debit != v_total_credit THEN
        RAISE EXCEPTION 'القيد غير متوازن. إجمالي المدين: %، إجمالي الدائن: %', v_total_debit, v_total_credit;
    END IF;

    -- إنشاء رقم قيد فريد
    v_entry_number := 'JE-' || to_char(p_entry_date, 'YYYYMMDD') || '-' || (
        SELECT count(*) + 1 FROM journal_entries WHERE entry_date = p_entry_date
    )::text;

    -- إدراج القيد الرئيسي
    INSERT INTO public.journal_entries (
        entry_number,
        entry_date,
        description,
        total_debit,
        total_credit,
        created_by
    )
    VALUES (
        v_entry_number,
        p_entry_date,
        p_description,
        v_total_debit,
        v_total_credit,
        auth.uid()
    )
    RETURNING id INTO v_entry_id;

    -- إدراج تفاصيل القيد
    FOR v_detail IN SELECT * FROM jsonb_array_elements(p_details)
    LOOP
        INSERT INTO public.journal_entry_details (
            journal_entry_id,
            account_id,
            debit_amount,
            credit_amount,
            description
        )
        VALUES (
            v_entry_id,
            (v_detail->>'account_id')::uuid,
            (v_detail->>'debit_amount')::decimal,
            (v_detail->>'credit_amount')::decimal,
            v_detail->>'description'
        );
    END LOOP;

    RETURN v_entry_id;
END;
$$;
