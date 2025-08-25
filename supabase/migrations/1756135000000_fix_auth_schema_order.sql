/*
# إصلاح خطأ في ترتيب تنفيذ استعلامات قاعدة البيانات
Fix for "relation public.users does not exist" error during migration.

## Query Description:
This script ensures the `users` table exists before creating the `authenticate_user` function that depends on it. It will first drop the potentially broken function, then create the table if it's missing, and finally recreate the function correctly. This is a non-destructive fix for the table but will replace the function definition.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true
*/

-- Step 1: Drop the function that may have failed to compile.
DROP FUNCTION IF EXISTS public.authenticate_user(p_username text, p_password text);

-- Step 2: Ensure the users table and its dependencies exist.
-- Use IF NOT EXISTS to avoid errors if they are already present.
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pgjwt";

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role') THEN
    CREATE TYPE public.user_role AS ENUM ('admin', 'financial', 'sales', 'customer_service', 'operations');
  END IF;
END$$;

CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role public.user_role NOT NULL DEFAULT 'sales',
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES public.users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 3: Re-create the authentication function correctly.
-- This function uses the project's JWT secret for secure token signing.
CREATE OR REPLACE FUNCTION public.authenticate_user(
  p_username TEXT,
  p_password TEXT
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  user_record public.users;
  token TEXT;
  project_jwt_secret TEXT;
BEGIN
  -- Get the project's JWT secret from Supabase settings
  project_jwt_secret := current_setting('app.settings.jwt_secret', true);
  IF project_jwt_secret IS NULL OR project_jwt_secret = '' THEN
      RAISE EXCEPTION 'Project JWT Secret is not configured in Supabase API settings.';
  END IF;

  SELECT * INTO user_record
  FROM public.users
  WHERE username = p_username AND is_active = true;

  IF NOT FOUND OR user_record.password_hash != crypt(p_password, user_record.password_hash) THEN
    RAISE EXCEPTION 'اسم المستخدم أو كلمة المرور غير صحيحة';
  END IF;

  token := sign(
    json_build_object(
      'sub', user_record.id, -- Standard JWT claim for subject (user ID)
      'role', 'authenticated', -- Standard Supabase role
      'aud', 'authenticated', -- Standard Supabase audience
      'iat', floor(extract(epoch from now())),
      'exp', floor(extract(epoch from now() + interval '24 hours')),
      -- Custom claims for application logic, recognized by Supabase client
      'app_metadata', json_build_object('role', user_record.role),
      'user_metadata', json_build_object('full_name', user_record.full_name)
    ),
    project_jwt_secret
  );

  -- Return user details (without password hash) and the generated token
  RETURN json_build_object(
    'user', json_build_object(
      'id', user_record.id,
      'username', user_record.username,
      'full_name', user_record.full_name,
      'role', user_record.role,
      'email', user_record.email,
      'phone', user_record.phone
    ),
    'token', token
  );
END;
$$;
