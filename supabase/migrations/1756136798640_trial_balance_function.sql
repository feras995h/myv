/*
# [Function] get_trial_balance
Creates a function to calculate the trial balance from journal entries.

## Query Description:
This function generates a trial balance by aggregating debits and credits for each account from the approved journal entries. It is a safe, read-only operation and essential for financial reporting.

## Metadata:
- Schema-Category: "Safe"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- Creates a new composite type `public.trial_balance_item`.
- Creates a new RPC function `public.get_trial_balance`.

## Security Implications:
- RLS Status: Not applicable (Function)
- Policy Changes: No
- Auth Requirements: The function is accessible to authenticated users.

## Performance Impact:
- Indexes: Utilizes existing indexes on foreign keys.
- Triggers: None
- Estimated Impact: Low, efficient calculation on the database side.
*/

-- Drop existing function and type if they exist for idempotency
DROP FUNCTION IF EXISTS public.get_trial_balance();
DROP TYPE IF EXISTS public.trial_balance_item;

-- Create a composite type to define the structure of the returned rows
CREATE TYPE public.trial_balance_item AS (
    account_id UUID,
    account_code TEXT,
    account_name TEXT,
    total_debit NUMERIC,
    total_credit NUMERIC
);

-- Create the function to calculate and return the trial balance
CREATE OR REPLACE FUNCTION public.get_trial_balance()
RETURNS SETOF public.trial_balance_item
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
    -- Set a secure search path
    SET search_path = public;

    RETURN QUERY
    SELECT
        coa.id AS account_id,
        coa.account_code,
        coa.account_name,
        COALESCE(SUM(jed.debit_amount), 0) AS total_debit,
        COALESCE(SUM(jed.credit_amount), 0) AS total_credit
    FROM
        chart_of_accounts coa
    LEFT JOIN
        journal_entry_details jed ON coa.id = jed.account_id
    LEFT JOIN
        journal_entries je ON jed.journal_entry_id = je.id AND je.is_approved = true
    GROUP BY
        coa.id, coa.account_code, coa.account_name
    ORDER BY
        coa.account_code;
END;
$$;

-- Grant execution rights to the authenticated role
GRANT EXECUTE ON FUNCTION public.get_trial_balance() TO authenticated;
