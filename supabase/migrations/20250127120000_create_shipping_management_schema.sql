/*
# إنشاء نظام إدارة شركة الشحن المتكامل
نظام شامل لإدارة شركة شحن من الصين إلى ليبيا مع نظام مالي محاسبي متكامل

## Query Description: 
إنشاء قاعدة بيانات شاملة لنظام إدارة الشحن والمحاسبة - يتضمن إنشاء جميع الجداول والعلاقات 
المطلوبة للنظام المالي والمحاسبي وإدارة الشحنات. النظام آمن ومحمي بسياسات RLS.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "High"
- Requires-Backup: false
- Reversible: true

## Structure Details:
- جداول المستخدمين والأدوار
- دليل الحسابات المحاسبي
- قيود اليومية والمعاملات المالية
- إدارة العملاء والموردين
- إدارة الموظفين والرواتب
- إدارة الشحنات والطلبات
- الأصول الثابتة والمخزون
- التقارير المالية

## Security Implications:
- RLS Status: Enabled
- Policy Changes: Yes
- Auth Requirements: جميع الجداول محمية بسياسات RLS

## Performance Impact:
- Indexes: متعددة لتحسين الأداء
- Triggers: محفزات لتحديث الأرصدة تلقائياً
- Estimated Impact: متوسط - قاعدة بيانات محسنة للأداء
*/

-- تمكين صفوف الأمان
ALTER DATABASE CURRENT SET row_security = on;

-- إنشاء أنواع البيانات المخصصة
CREATE TYPE user_role AS ENUM ('admin', 'financial', 'sales', 'customer_service', 'operations');
CREATE TYPE account_type AS ENUM ('asset', 'liability', 'equity', 'revenue', 'expense');
CREATE TYPE transaction_status AS ENUM ('pending', 'approved', 'rejected');
CREATE TYPE shipment_status AS ENUM ('pending', 'in_transit', 'delivered', 'cancelled');
CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'overdue', 'cancelled');

-- جدول المستخدمين الموسع
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    role user_role NOT NULL DEFAULT 'customer_service',
    phone TEXT,
    avatar_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- دليل الحسابات
CREATE TABLE chart_of_accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    account_code TEXT UNIQUE NOT NULL,
    account_name_ar TEXT NOT NULL,
    account_name_en TEXT,
    account_type account_type NOT NULL,
    parent_id UUID REFERENCES chart_of_accounts(id),
    level INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    balance DECIMAL(15,2) DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- قيود اليومية
CREATE TABLE journal_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    entry_number TEXT UNIQUE NOT NULL,
    entry_date DATE NOT NULL,
    description TEXT NOT NULL,
    reference TEXT,
    total_debit DECIMAL(15,2) NOT NULL DEFAULT 0,
    total_credit DECIMAL(15,2) NOT NULL DEFAULT 0,
    status transaction_status DEFAULT 'pending',
    created_by UUID REFERENCES users(id),
    approved_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    approved_at TIMESTAMP WITH TIME ZONE
);

-- تفاصيل قيود اليومية
CREATE TABLE journal_entry_lines (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    journal_entry_id UUID REFERENCES journal_entries(id) ON DELETE CASCADE,
    account_id UUID REFERENCES chart_of_accounts(id),
    debit_amount DECIMAL(15,2) DEFAULT 0,
    credit_amount DECIMAL(15,2) DEFAULT 0,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- العملاء
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_code TEXT UNIQUE NOT NULL,
    name_ar TEXT NOT NULL,
    name_en TEXT,
    email TEXT,
    phone TEXT,
    whatsapp TEXT,
    address_ar TEXT,
    address_en TEXT,
    city TEXT,
    country TEXT DEFAULT 'Libya',
    tax_number TEXT,
    credit_limit DECIMAL(15,2) DEFAULT 0,
    current_balance DECIMAL(15,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- الموردين
CREATE TABLE suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    supplier_code TEXT UNIQUE NOT NULL,
    name_ar TEXT NOT NULL,
    name_en TEXT,
    email TEXT,
    phone TEXT,
    address_ar TEXT,
    address_en TEXT,
    city TEXT,
    country TEXT DEFAULT 'China',
    tax_number TEXT,
    current_balance DECIMAL(15,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- الموظفين
CREATE TABLE employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_code TEXT UNIQUE NOT NULL,
    name_ar TEXT NOT NULL,
    name_en TEXT,
    email TEXT,
    phone TEXT,
    position_ar TEXT,
    position_en TEXT,
    department TEXT,
    hire_date DATE,
    salary DECIMAL(10,2),
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- الشحنات
CREATE TABLE shipments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shipment_number TEXT UNIQUE NOT NULL,
    customer_id UUID REFERENCES customers(id),
    origin_port TEXT DEFAULT 'Shanghai',
    destination_port TEXT DEFAULT 'Tripoli',
    departure_date DATE,
    estimated_arrival DATE,
    actual_arrival DATE,
    status shipment_status DEFAULT 'pending',
    total_weight DECIMAL(10,2),
    total_volume DECIMAL(10,2),
    total_cost DECIMAL(15,2),
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- تفاصيل الشحنات
CREATE TABLE shipment_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shipment_id UUID REFERENCES shipments(id) ON DELETE CASCADE,
    item_description_ar TEXT NOT NULL,
    item_description_en TEXT,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2),
    total_price DECIMAL(10,2),
    weight DECIMAL(8,2),
    volume DECIMAL(8,2),
    hs_code TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- الفواتير
CREATE TABLE invoices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_number TEXT UNIQUE NOT NULL,
    customer_id UUID REFERENCES customers(id),
    shipment_id UUID REFERENCES shipments(id),
    invoice_date DATE NOT NULL,
    due_date DATE,
    subtotal DECIMAL(15,2) NOT NULL,
    tax_amount DECIMAL(15,2) DEFAULT 0,
    total_amount DECIMAL(15,2) NOT NULL,
    paid_amount DECIMAL(15,2) DEFAULT 0,
    balance DECIMAL(15,2) NOT NULL,
    status payment_status DEFAULT 'pending',
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- تفاصيل الفواتير
CREATE TABLE invoice_lines (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    invoice_id UUID REFERENCES invoices(id) ON DELETE CASCADE,
    description_ar TEXT NOT NULL,
    description_en TEXT,
    quantity DECIMAL(10,2) NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- المدفوعات
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payment_number TEXT UNIQUE NOT NULL,
    customer_id UUID REFERENCES customers(id),
    invoice_id UUID REFERENCES invoices(id),
    payment_date DATE NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    payment_method TEXT,
    reference_number TEXT,
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- الأصول الثابتة
CREATE TABLE fixed_assets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asset_code TEXT UNIQUE NOT NULL,
    asset_name_ar TEXT NOT NULL,
    asset_name_en TEXT,
    category TEXT,
    purchase_date DATE,
    purchase_cost DECIMAL(15,2),
    useful_life_years INTEGER,
    depreciation_method TEXT DEFAULT 'straight_line',
    accumulated_depreciation DECIMAL(15,2) DEFAULT 0,
    book_value DECIMAL(15,2),
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- إنشاء فهارس لتحسين الأداء
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_chart_accounts_code ON chart_of_accounts(account_code);
CREATE INDEX idx_chart_accounts_type ON chart_of_accounts(account_type);
CREATE INDEX idx_journal_entries_date ON journal_entries(entry_date);
CREATE INDEX idx_journal_entries_status ON journal_entries(status);
CREATE INDEX idx_customers_code ON customers(customer_code);
CREATE INDEX idx_shipments_number ON shipments(shipment_number);
CREATE INDEX idx_shipments_status ON shipments(status);
CREATE INDEX idx_invoices_number ON invoices(invoice_number);
CREATE INDEX idx_invoices_status ON invoices(status);

-- تمكين RLS لجميع الجداول
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE chart_of_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entry_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipment_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE fixed_assets ENABLE ROW LEVEL SECURITY;

-- سياسات الأمان للمستخدمين
CREATE POLICY "Users can view their own data" ON users FOR SELECT USING (auth.uid()::text = id::text);
CREATE POLICY "Admins can view all users" ON users FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE id::text = auth.uid()::text AND role = 'admin')
);
CREATE POLICY "Admins can update users" ON users FOR UPDATE USING (
    EXISTS (SELECT 1 FROM users WHERE id::text = auth.uid()::text AND role = 'admin')
);

-- سياسات عامة للجداول الأخرى (يمكن للمستخدمين المسجلين الوصول)
CREATE POLICY "Authenticated users can read" ON chart_of_accounts FOR SELECT TO authenticated USING (true);
CREATE POLICY "Financial users can manage accounts" ON chart_of_accounts FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM users WHERE id::text = auth.uid()::text AND role IN ('admin', 'financial'))
);

CREATE POLICY "Authenticated users can read journal entries" ON journal_entries FOR SELECT TO authenticated USING (true);
CREATE POLICY "Financial users can manage journal entries" ON journal_entries FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM users WHERE id::text = auth.uid()::text AND role IN ('admin', 'financial'))
);

CREATE POLICY "Authenticated users can read customers" ON customers FOR SELECT TO authenticated USING (true);
CREATE POLICY "Sales and admin can manage customers" ON customers FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM users WHERE id::text = auth.uid()::text AND role IN ('admin', 'sales', 'customer_service'))
);

-- سياسات مماثلة لباقي الجداول
CREATE POLICY "Authenticated users can read suppliers" ON suppliers FOR SELECT TO authenticated USING (true);
CREATE POLICY "Operations and admin can manage suppliers" ON suppliers FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM users WHERE id::text = auth.uid()::text AND role IN ('admin', 'operations'))
);

CREATE POLICY "Authenticated users can read employees" ON employees FOR SELECT TO authenticated USING (true);
CREATE POLICY "Admin can manage employees" ON employees FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM users WHERE id::text = auth.uid()::text AND role = 'admin')
);

CREATE POLICY "Authenticated users can read shipments" ON shipments FOR SELECT TO authenticated USING (true);
CREATE POLICY "Operations users can manage shipments" ON shipments FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM users WHERE id::text = auth.uid()::text AND role IN ('admin', 'operations', 'sales'))
);

-- إدراج دليل الحسابات الأساسي
INSERT INTO chart_of_accounts (account_code, account_name_ar, account_name_en, account_type, level) VALUES
-- الأصول
('1000', 'الأصول', 'Assets', 'asset', 0),
('1100', 'الأصول المتداولة', 'Current Assets', 'asset', 1),
('1110', 'النقدية والبنوك', 'Cash and Banks', 'asset', 2),
('1111', 'الصندوق', 'Cash on Hand', 'asset', 3),
('1112', 'البنك الأهلي', 'National Bank', 'asset', 3),
('1113', 'بنك الجمهورية', 'Republic Bank', 'asset', 3),
('1120', 'العملاء', 'Accounts Receivable', 'asset', 2),
('1121', 'عملاء محليون', 'Local Customers', 'asset', 3),
('1122', 'عملاء أجانب', 'Foreign Customers', 'asset', 3),
('1130', 'المخزون', 'Inventory', 'asset', 2),
('1131', 'مخزون البضائع', 'Goods Inventory', 'asset', 3),
('1200', 'الأصول غير المتداولة', 'Non-Current Assets', 'asset', 1),
('1210', 'الأصول الثابتة', 'Fixed Assets', 'asset', 2),
('1211', 'المباني', 'Buildings', 'asset', 3),
('1212', 'السيارات', 'Vehicles', 'asset', 3),
('1213', 'المعدات', 'Equipment', 'asset', 3),

-- الخصوم
('2000', 'الخصوم', 'Liabilities', 'liability', 0),
('2100', 'الخصوم المتداولة', 'Current Liabilities', 'liability', 1),
('2110', 'الموردون', 'Accounts Payable', 'liability', 2),
('2111', 'موردون محليون', 'Local Suppliers', 'liability', 3),
('2112', 'موردون أجانب', 'Foreign Suppliers', 'liability', 3),
('2120', 'المصاريف المستحقة', 'Accrued Expenses', 'liability', 2),
('2121', 'رواتب مستحقة', 'Accrued Salaries', 'liability', 3),
('2200', 'الخصوم غير المتداولة', 'Non-Current Liabilities', 'liability', 1),
('2210', 'القروض طويلة الأجل', 'Long-term Loans', 'liability', 2),

-- حقوق الملكية
('3000', 'حقوق الملكية', 'Equity', 'equity', 0),
('3100', 'رأس المال', 'Capital', 'equity', 1),
('3200', 'الأرباح المحتجزة', 'Retained Earnings', 'equity', 1),

-- الإيرادات
('4000', 'الإيرادات', 'Revenues', 'revenue', 0),
('4100', 'إيرادات الشحن', 'Shipping Revenue', 'revenue', 1),
('4110', 'شحن بحري', 'Sea Freight', 'revenue', 2),
('4120', 'شحن جوي', 'Air Freight', 'revenue', 2),
('4200', 'إيرادات أخرى', 'Other Revenue', 'revenue', 1),

-- المصروفات
('5000', 'المصروفات', 'Expenses', 'expense', 0),
('5100', 'مصاريف التشغيل', 'Operating Expenses', 'expense', 1),
('5110', 'الرواتب والأجور', 'Salaries and Wages', 'expense', 2),
('5120', 'الإيجارات', 'Rent', 'expense', 2),
('5130', 'الكهرباء والماء', 'Utilities', 'expense', 2),
('5140', 'الاتصالات', 'Communications', 'expense', 2),
('5200', 'مصاريف الشحن', 'Shipping Costs', 'expense', 1),
('5210', 'تكاليف النقل', 'Transportation Costs', 'expense', 2),
('5220', 'رسوم جمركية', 'Customs Fees', 'expense', 2);

-- تحديث الأرصدة عند إضافة أو تعديل قيود اليومية
CREATE OR REPLACE FUNCTION update_account_balances()
RETURNS TRIGGER AS $$
BEGIN
    -- تحديث رصيد الحساب المدين
    IF NEW.debit_amount > 0 THEN
        UPDATE chart_of_accounts 
        SET balance = balance + NEW.debit_amount,
            updated_at = NOW()
        WHERE id = NEW.account_id;
    END IF;
    
    -- تحديث رصيد الحساب الدائن
    IF NEW.credit_amount > 0 THEN
        UPDATE chart_of_accounts 
        SET balance = balance - NEW.credit_amount,
            updated_at = NOW()
        WHERE id = NEW.account_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- إنشاء محفز لتحديث الأرصدة
CREATE TRIGGER trigger_update_account_balances
    AFTER INSERT OR UPDATE ON journal_entry_lines
    FOR EACH ROW
    EXECUTE FUNCTION update_account_balances();

-- دالة لإنشاء رقم قيد تلقائي
CREATE OR REPLACE FUNCTION generate_entry_number()
RETURNS TRIGGER AS $$
BEGIN
    NEW.entry_number := 'JE' || TO_CHAR(NOW(), 'YYYY') || '-' || LPAD((SELECT COALESCE(MAX(CAST(SUBSTRING(entry_number FROM 7) AS INTEGER)), 0) + 1 FROM journal_entries WHERE entry_number LIKE 'JE' || TO_CHAR(NOW(), 'YYYY') || '-%')::TEXT, 4, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_generate_entry_number
    BEFORE INSERT ON journal_entries
    FOR EACH ROW
    EXECUTE FUNCTION generate_entry_number();
