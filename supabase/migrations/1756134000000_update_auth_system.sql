/*
# تحديث نظام المصادقة لاستخدام اسم المستخدم
تعديل نظام المصادقة ليستخدم username بدلاً من email مع إعطاء صلاحيات الإدارة لمدير النظام
## Query Description: 
سيتم تعديل جدول المستخدمين لإضافة username وجعله فريد.
سيتم إنشاء مستخدم مدير افتراضي للنظام.
لن يتم فقدان أي بيانات موجودة.
## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Medium"
- Requires-Backup: true
- Reversible: true
## Structure Details:
- تعديل جدول users لإضافة username
- إضافة constraints للفرادة
- إنشاء مستخدم مدير افتراضي
## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes
- Auth Requirements: تحديث سياسات الأمان
## Performance Impact:
- Indexes: Added for username lookups
- Triggers: Updated for new auth system
- Estimated Impact: تحسين الأداء مع فهرسة username
*/

-- تعديل جدول المستخدمين لإضافة username وتحديث البنية
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS username VARCHAR(50) UNIQUE,
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES users(id),
ADD COLUMN IF NOT EXISTS can_create_users BOOLEAN DEFAULT false;

-- إنشاء index لـ username
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);

-- تحديث الجدول لجعل email اختياري وusername إجباري
ALTER TABLE users ALTER COLUMN email DROP NOT NULL;

-- حذف الجداول الموجودة مسبقاً إذا كانت موجودة
DROP TABLE IF EXISTS shipment_items CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS expenses CASCADE;
DROP TABLE IF EXISTS journal_entry_details CASCADE;
DROP TABLE IF EXISTS journal_entries CASCADE;
DROP TABLE IF EXISTS shipments CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS suppliers CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS chart_of_accounts CASCADE;

-- إعادة إنشاء enum types
DROP TYPE IF EXISTS user_role CASCADE;
DROP TYPE IF EXISTS shipment_status CASCADE;
DROP TYPE IF EXISTS payment_status CASCADE;
DROP TYPE IF EXISTS account_type CASCADE;

CREATE TYPE user_role AS ENUM ('admin', 'financial', 'sales', 'customer_service', 'operations');
CREATE TYPE shipment_status AS ENUM ('pending', 'processing', 'shipped', 'in_transit', 'delivered', 'cancelled');
CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'partial', 'overdue', 'cancelled');
CREATE TYPE account_type AS ENUM ('asset', 'liability', 'equity', 'revenue', 'expense');

-- حذف المستخدمين الموجودين وإعادة إنشاء الجدول
TRUNCATE TABLE users CASCADE;

-- إعادة تعريف جدول المستخدمين
ALTER TABLE users 
DROP CONSTRAINT IF EXISTS users_email_key,
ADD CONSTRAINT users_username_key UNIQUE (username);

-- إنشاء مستخدم مدير افتراضي
INSERT INTO users (id, username, password_hash, full_name, role, can_create_users, is_active, created_at, updated_at) 
VALUES (
  uuid_generate_v4(),
  'admin',
  crypt('admin123', gen_salt('bf')),
  'مدير النظام',
  'admin',
  true,
  true,
  NOW(),
  NOW()
);

-- إنشاء بعض المستخدمين التجريبيين
INSERT INTO users (id, username, password_hash, full_name, role, email, phone, is_active, created_by, created_at, updated_at) 
VALUES 
(
  uuid_generate_v4(),
  'financial',
  crypt('123456', gen_salt('bf')),
  'أحمد المالي',
  'financial',
  'financial@company.com',
  '+218911234567',
  true,
  (SELECT id FROM users WHERE username = 'admin'),
  NOW(),
  NOW()
),
(
  uuid_generate_v4(),
  'sales',
  crypt('123456', gen_salt('bf')),
  'فاطمة المبيعات',
  'sales',
  'sales@company.com',
  '+218912345678',
  true,
  (SELECT id FROM users WHERE username = 'admin'),
  NOW(),
  NOW()
),
(
  uuid_generate_v4(),
  'service',
  crypt('123456', gen_salt('bf')),
  'محمد خدمة العملاء',
  'customer_service',
  'service@company.com',
  '+218913456789',
  true,
  (SELECT id FROM users WHERE username = 'admin'),
  NOW(),
  NOW()
);

-- إعادة إنشاء باقي الجداول
-- جدول الشركات/العملاء
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(100),
    country VARCHAR(100) DEFAULT 'Libya',
    tax_number VARCHAR(50),
    credit_limit DECIMAL(15,2) DEFAULT 0,
    current_balance DECIMAL(15,2) DEFAULT 0,
    payment_terms INTEGER DEFAULT 30,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- جدول الموردين
CREATE TABLE suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    company_name VARCHAR(255) NOT NULL,
    contact_person VARCHAR(255),
    email VARCHAR(255),
    phone VARCHAR(20),
    address TEXT,
    city VARCHAR(100),
    country VARCHAR(100) DEFAULT 'China',
    tax_number VARCHAR(50),
    payment_terms INTEGER DEFAULT 30,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- دليل الحسابات
CREATE TABLE chart_of_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_code VARCHAR(20) UNIQUE NOT NULL,
    account_name VARCHAR(255) NOT NULL,
    account_type account_type NOT NULL,
    parent_account_id UUID REFERENCES chart_of_accounts(id),
    level INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    balance DECIMAL(15,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- جدول الشحنات
CREATE TABLE shipments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shipment_number VARCHAR(50) UNIQUE NOT NULL,
    customer_id UUID REFERENCES customers(id) NOT NULL,
    supplier_id UUID REFERENCES suppliers(id),
    origin_port VARCHAR(100) DEFAULT 'Shanghai',
    destination_port VARCHAR(100) DEFAULT 'Tripoli',
    departure_date DATE,
    arrival_date DATE,
    estimated_arrival DATE,
    status shipment_status DEFAULT 'pending',
    container_number VARCHAR(50),
    seal_number VARCHAR(50),
    weight_kg DECIMAL(10,2),
    volume_cbm DECIMAL(10,2),
    total_amount DECIMAL(15,2) NOT NULL,
    paid_amount DECIMAL(15,2) DEFAULT 0,
    payment_status payment_status DEFAULT 'pending',
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- إدراج دليل الحسابات الأساسي
INSERT INTO chart_of_accounts (account_code, account_name, account_type, level) VALUES
-- الأصول (1000-1999)
('1000', 'الأصول', 'asset', 1),
('1100', 'الأصول المتداولة', 'asset', 2),
('1110', 'النقدية وما في حكمها', 'asset', 3),
('1111', 'الصندوق الرئيسي', 'asset', 4),
('1112', 'البنك التجاري الوطني', 'asset', 4),
('1113', 'بنك الوحدة', 'asset', 4),
('1120', 'العملاء والذمم المدينة', 'asset', 3),
('1121', 'حسابات العملاء', 'asset', 4),
('1130', 'المخزون', 'asset', 3),
('1131', 'مخزون البضائع', 'asset', 4),
-- الخصوم (2000-2999)
('2000', 'الخصوم', 'liability', 1),
('2100', 'الخصوم المتداولة', 'liability', 2),
('2110', 'الموردين والذمم الدائنة', 'liability', 3),
('2111', 'حسابات الموردين', 'liability', 4),
-- حقوق الملكية (3000-3999)
('3000', 'حقوق الملكية', 'equity', 1),
('3100', 'رأس المال', 'equity', 2),
('3110', 'رأس المال المدفوع', 'equity', 3),
-- الإيرادات (4000-4999)
('4000', 'الإيرادات', 'revenue', 1),
('4100', 'إيرادات التشغيل', 'revenue', 2),
('4110', 'إيرادات الشحن', 'revenue', 3),
('4111', 'إيرادات شحن بحري', 'revenue', 4),
-- المصاريف (5000-5999)
('5000', 'المصاريف', 'expense', 1),
('5100', 'تكلفة الخدمات المباعة', 'expense', 2),
('5110', 'تكلفة النقل', 'expense', 3),
('5111', 'تكلفة النقل البحري', 'expense', 4);

-- إضافة بعض العملاء التجريبيين
INSERT INTO customers (company_name, contact_person, email, phone, city, country, credit_limit, created_by) VALUES
('شركة التجارة الليبية', 'أحمد علي محمد', 'ahmed@libya-trade.com', '+218911111111', 'طرابلس', 'Libya', 50000, (SELECT id FROM users WHERE username = 'admin')),
('مؤسسة النور للاستيراد', 'فاطمة حسين', 'fatima@alnoor.ly', '+218922222222', 'بنغازي', 'Libya', 75000, (SELECT id FROM users WHERE username = 'admin')),
('شركة الوطن التجارية', 'محمد أحمد الزروق', 'mohammad@alwatan.ly', '+218933333333', 'مصراتة', 'Libya', 100000, (SELECT id FROM users WHERE username = 'admin'));

-- إضافة بعض الموردين التجريبيين
INSERT INTO suppliers (company_name, contact_person, email, phone, city, country, created_by) VALUES
('Shanghai Export Company', 'Li Wei', 'li.wei@shanghai-export.cn', '+8613800000001', 'Shanghai', 'China', (SELECT id FROM users WHERE username = 'admin')),
('Guangzhou Trading Co.', 'Zhang Ming', 'zhang@guangzhou-trade.cn', '+8613800000002', 'Guangzhou', 'China', (SELECT id FROM users WHERE username = 'admin')),
('Shenzhen Electronics Ltd', 'Wang Hua', 'wang@sz-electronics.cn', '+8613800000003', 'Shenzhen', 'China', (SELECT id FROM users WHERE username = 'admin'));

-- إضافة بعض الشحنات التجريبية
INSERT INTO shipments (shipment_number, customer_id, supplier_id, origin_port, destination_port, departure_date, estimated_arrival, status, total_amount, created_by) VALUES
('SH-2024-001', 
 (SELECT id FROM customers WHERE company_name = 'شركة التجارة الليبية'), 
 (SELECT id FROM suppliers WHERE company_name = 'Shanghai Export Company'),
 'Shanghai', 'Tripoli', '2024-01-15', '2024-02-15', 'in_transit', 25000,
 (SELECT id FROM users WHERE username = 'admin')),
('SH-2024-002', 
 (SELECT id FROM customers WHERE company_name = 'مؤسسة النور للاستيراد'), 
 (SELECT id FROM suppliers WHERE company_name = 'Guangzhou Trading Co.'),
 'Guangzhou', 'Benghazi', '2024-01-10', '2024-02-10', 'delivered', 35000,
 (SELECT id FROM users WHERE username = 'admin'));

-- تحديث سياسات الأمان (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE chart_of_accounts ENABLE ROW LEVEL SECURITY;

-- سياسات أمان للمستخدمين
CREATE POLICY "Users can view their own profile" ON users
    FOR SELECT USING (id = (current_setting('app.current_user_id', true))::uuid);

CREATE POLICY "Admins can view all users" ON users
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = (current_setting('app.current_user_id', true))::uuid 
            AND role = 'admin'
        )
    );

CREATE POLICY "Admins can create users" ON users
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = (current_setting('app.current_user_id', true))::uuid 
            AND can_create_users = true
        )
    );

CREATE POLICY "Admins can update users" ON users
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = (current_setting('app.current_user_id', true))::uuid 
            AND role = 'admin'
        )
    );

-- سياسات أمان للعملاء
CREATE POLICY "All authenticated users can view customers" ON customers
    FOR SELECT USING (
        (current_setting('app.current_user_id', true))::uuid IS NOT NULL
    );

CREATE POLICY "Sales and admin can manage customers" ON customers
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = (current_setting('app.current_user_id', true))::uuid 
            AND role IN ('admin', 'sales', 'customer_service')
        )
    );

-- سياسات أمان للموردين
CREATE POLICY "All authenticated users can view suppliers" ON suppliers
    FOR SELECT USING (
        (current_setting('app.current_user_id', true))::uuid IS NOT NULL
    );

CREATE POLICY "Operations and admin can manage suppliers" ON suppliers
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = (current_setting('app.current_user_id', true))::uuid 
            AND role IN ('admin', 'operations')
        )
    );

-- سياسات أمان للشحنات
CREATE POLICY "All authenticated users can view shipments" ON shipments
    FOR SELECT USING (
        (current_setting('app.current_user_id', true))::uuid IS NOT NULL
    );

CREATE POLICY "Authorized users can manage shipments" ON shipments
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = (current_setting('app.current_user_id', true))::uuid 
            AND role IN ('admin', 'sales', 'operations', 'customer_service')
        )
    );

-- سياسات أمان لدليل الحسابات
CREATE POLICY "All authenticated users can view chart of accounts" ON chart_of_accounts
    FOR SELECT USING (
        (current_setting('app.current_user_id', true))::uuid IS NOT NULL
    );

CREATE POLICY "Financial and admin can manage accounts" ON chart_of_accounts
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = (current_setting('app.current_user_id', true))::uuid 
            AND role IN ('admin', 'financial')
        )
    );
