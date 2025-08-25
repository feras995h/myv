/*
# Final Authentication and Security Fix
This migration provides a definitive fix for the "jwt malformed" error by making the core security functions more robust. It also ensures the authentication function is correctly configured.

## Query Description:
This script updates the helper functions (`get_my_claim`, `get_my_role`) that our Row Level Security (RLS) policies depend on. The new versions can gracefully handle corrupted or malformed JWTs without crashing, which resolves the error encountered during migration. It also re-confirms the correct implementation of the `authenticate_user` function. This is a critical stability and security update.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (by reverting to previous function definitions)

## Structure Details:
- Modifies: `public.get_my_claim` function
- Modifies: `public.get_my_role` function
- Re-confirms: `public.authenticate_user` function

## Security Implications:
- RLS Status: This change is essential for RLS policies to function reliably.
- Policy Changes: No
- Auth Requirements: This fix ensures the custom authentication and authorization system is stable.

## Performance Impact:
- Indexes: None
- Triggers: None
- Estimated Impact: Negligible impact on performance.
*/

-- Make the get_my_claim function resilient to malformed JWTs
CREATE OR REPLACE FUNCTION public.get_my_claim(claim text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    claims jsonb;
BEGIN
    -- This block will gracefully handle cases where the JWT is malformed or missing
    BEGIN
        claims := current_setting('request.jwt.claims', true)::jsonb;
    EXCEPTION
        WHEN invalid_text_representation THEN
            -- This happens if the JWT claim string is not valid JSON
            RETURN null;
        WHEN OTHERS THEN
            -- Catch any other unexpected errors
            RETURN null;
    END;

    -- Return the specific claim if it exists
    RETURN claims -> claim;
END;
$$;


-- Re-create the get_my_role function to depend on the robust get_my_claim
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS user_role
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
    claim_value jsonb;
BEGIN
    claim_value := public.get_my_claim('user_role');
    
    -- If the claim is null or not a string, return null
    IF claim_value IS NULL OR jsonb_typeof(claim_value) != 'string' THEN
        RETURN NULL;
    END IF;

    -- Safely cast the claim to the user_role enum
    BEGIN
        RETURN trim(both '"' from claim_value::text)::user_role;
    EXCEPTION
        WHEN invalid_text_representation THEN
            -- This happens if the role in the JWT is not a valid user_role enum value
            RETURN NULL;
        WHEN OTHERS THEN
            RETURN NULL;
    END;
END;
$$;

-- Re-confirm the correct implementation of the user authentication function
CREATE OR REPLACE FUNCTION public.authenticate_user(
    p_username text,
    p_password text
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
    user_record public.users;
    token text;
    jwt_secret text;
    payload json;
BEGIN
    -- Correctly fetch the JWT secret from Supabase settings
    SELECT current_setting('app.settings.jwt_secret', true) INTO jwt_secret;

    IF jwt_secret IS NULL THEN
        RAISE EXCEPTION 'JWT secret not found. Please check Supabase project settings.';
    END IF;

    -- Find the user by username
    SELECT * INTO user_record FROM public.users WHERE username = p_username;

    -- If user found, is active, and password is correct
    IF FOUND AND user_record.is_active AND user_record.password_hash = crypt(p_password, user_record.password_hash) THEN
        -- Prepare the JWT payload with standard claims
        payload := json_build_object(
            'sub', user_record.id::text,
            'role', 'authenticated', -- Standard Supabase role for authenticated users
            'aud', 'authenticated',
            'user_role', user_record.role, -- Custom claim for our RLS policies
            'iat', extract(epoch from now())::integer,
            'exp', extract(epoch from now())::integer + 60*60*24 -- Token expires in 24 hours
        );

        -- Sign the token using the fetched secret
        token := sign(payload, jwt_secret);

        -- Return user details and the valid token
        RETURN json_build_object(
            'user', json_build_object(
                'id', user_record.id,
                'username', user_record.username,
                'full_name', user_record.full_name,
                'role', user_record.role,
                'email', user_record.email,
                'phone', user_record.phone,
                'is_active', user_record.is_active,
                'created_at', user_record.created_at,
                'updated_at', user_record.updated_at
            ),
            'token', token
        );
    ELSE
        -- Authentication failed, raise a specific exception
        RAISE EXCEPTION 'Invalid username or password';
    END IF;
END;
$$;
