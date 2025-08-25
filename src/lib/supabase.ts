import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY
const useLocalAuth = import.meta.env.VITE_USE_LOCAL_AUTH === 'true'

// Use dummy values for local development when Supabase is not configured
const finalUrl = supabaseUrl || 'http://localhost:54321'
const finalKey = supabaseAnonKey || 'dummy-key-for-local-dev'

export const supabase = createClient(finalUrl, finalKey)

// Demo users for local authentication
const DEMO_USERS = [
  { username: 'admin', password: 'admin123', full_name: 'مدير النظام', role: 'admin' as const },
  { username: 'financial', password: '123456', full_name: 'موظف مالي', role: 'financial' as const },
  { username: 'sales', password: '123456', full_name: 'موظف مبيعات', role: 'sales' as const },
  { username: 'service', password: '123456', full_name: 'خدمة العملاء', role: 'customer_service' as const }
]

// User types
export interface User {
  id: string
  username: string
  email?: string
  full_name: string
  role: 'admin' | 'financial' | 'sales' | 'customer_service' | 'operations'
  phone?: string
  is_active: boolean
  created_by?: string
  created_at: string
  updated_at: string
}

// Session data type
interface SessionData {
  user: User;
  token: string;
}

// Account types
export interface ChartAccount {
  id: string
  account_code: string
  account_name: string
  account_type: 'asset' | 'liability' | 'equity' | 'revenue' | 'expense'
  parent_account_id?: string
  level: number
  is_active: boolean
  balance: number
  created_at: string
}

// Customer types
export interface Customer {
  id: string
  company_name: string
  contact_person?: string
  email?: string
  phone?: string
  address?: string
  city?: string
  country: string
  tax_number?: string
  credit_limit: number
  current_balance: number
  payment_terms: number
  is_active: boolean
  created_by?: string
  created_at: string
  updated_at: string
}

// Supplier types
export interface Supplier {
  id: string
  company_name: string
  contact_person?: string
  email?: string
  phone?: string
  address?: string
  city?: string
  country: string
  tax_number?: string
  payment_terms: number
  is_active: boolean
  created_by?: string
  created_at: string
  updated_at: string
}

// Shipment types
export interface Shipment {
  id: string
  shipment_number: string
  customer_id: string
  supplier_id?: string
  origin_port: string
  destination_port: string
  departure_date?: string
  estimated_arrival?: string
  arrival_date?: string
  status: 'pending' | 'processing' | 'shipped' | 'in_transit' | 'delivered' | 'cancelled'
  container_number?: string
  seal_number?: string
  weight_kg?: number
  volume_cbm?: number
  total_amount: number
  paid_amount: number
  payment_status: 'pending' | 'paid' | 'partial' | 'overdue' | 'cancelled'
  notes?: string
  created_by?: string
  created_at: string
  updated_at: string
  customers?: Pick<Customer, 'company_name'> // Optimized to only fetch company_name
  suppliers?: Pick<Supplier, 'company_name'>
}

// Journal Entry types
export interface JournalEntryDetail {
  id: string;
  journal_entry_id: string;
  account_id: string;
  debit_amount: number;
  credit_amount: number;
  description?: string;
  chart_of_accounts?: Pick<ChartAccount, 'account_name' | 'account_code'>;
}

export interface JournalEntry {
  id: string;
  entry_number: string;
  entry_date: string;
  description: string;
  total_debit: number;
  total_credit: number;
  is_approved: boolean;
  approved_by?: string;
  approved_at?: string;
  created_by?: string;
  created_at: string;
  journal_entry_details: JournalEntryDetail[];
}

// Trial Balance types
export interface TrialBalanceItem {
  account_id: string;
  account_code: string;
  account_name: string;
  total_debit: number;
  total_credit: number;
}

// Financial Report types
export interface IncomeStatementItem {
  category: 'الإيرادات' | 'المصاريف';
  account_name: string;
  amount: number;
}

export interface BalanceSheetItem {
  category: 'الأصول' | 'الخصوم' | 'حقوق الملكية';
  sub_category: string;
  account_name: string;
  balance: number;
}


// Auth functions using JWT with fallback for demo
export const signInWithUsername = async (username: string, password: string): Promise<User> => {
  try {
    // If using local auth or Supabase is not properly configured, use demo authentication
    if (useLocalAuth || !supabaseUrl || !supabaseAnonKey) {
      const demoUser = DEMO_USERS.find(user => user.username === username && user.password === password)
      
      if (!demoUser) {
        throw new Error('اسم المستخدم أو كلمة المرور غير صحيحة')
      }
      
      const user: User = {
        id: `demo-${demoUser.username}`,
        username: demoUser.username,
        full_name: demoUser.full_name,
        role: demoUser.role,
        is_active: true,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      }
      
      // Create a simple token for demo purposes
      const token = btoa(JSON.stringify({ user_id: user.id, role: user.role, exp: Date.now() + 86400000 }))
      
      // Save the session
      saveSession({ user, token })
      
      return user
    }
    
    // Try Supabase authentication
    const { data, error } = await supabase.rpc('authenticate_user_improved', {
      p_username: username,
      p_password: password
    })

    if (error) throw error
    if (!data || data.success !== true) throw new Error(data?.error || 'فشل المصادقة')

    const { user, session } = data;

    // Create a simple token from session data
    const token = btoa(JSON.stringify(session))

    // Set the session on the Supabase client (using a dummy token for now)
    await supabase.auth.setSession({
      access_token: token,
      refresh_token: token,
    })

    // Save the session to localStorage
    saveSession({ user, token });

    return user as User
  } catch (error: any) {
    console.error('Authentication error:', error)
    throw new Error(error.message || 'خطأ في تسجيل الدخول')
  }
}

export const signOut = async () => {
  try {
    await supabase.auth.signOut()
    clearSession()
  } catch (error) {
    console.error('Error signing out:', error)
    clearSession()
  }
}

export const getMyProfile = async (): Promise<User | null> => {
  try {
    // If using local auth, get user from session
    if (useLocalAuth || !supabaseUrl || !supabaseAnonKey) {
      const session = getSession()
      return session ? session.user : null
    }
    
    // Try Supabase profile fetch
    const { data, error } = await supabase.rpc('get_my_profile')
    if (error) throw error
    return data && data.length > 0 ? data[0] as User : null
  } catch (error) {
    if (!(error instanceof Error && error.message.includes('Auth session missing'))) {
      console.error('Error getting user profile:', error)
    }
    return null
  }
}

export const createUser = async (userData: {
  username: string
  password: string
  full_name: string
  role: User['role']
  email?: string
  phone?: string
}) => {
  try {
    const { data, error } = await supabase.rpc('create_new_user', {
      p_username: userData.username,
      p_password: userData.password,
      p_full_name: userData.full_name,
      p_role: userData.role,
      p_email: userData.email || null,
      p_phone: userData.phone || null
    })

    if (error) throw error
    return data
  } catch (error: any) {
    throw new Error(error.message || 'خطأ في إنشاء المستخدم')
  }
}

export const getAllUsers = async (): Promise<User[]> => {
  const { data, error } = await supabase
    .from('users')
    .select('*')
    .order('created_at', { ascending: false })

  if (error) throw error
  return data || []
}

export const updateUser = async (userId: string, updates: Partial<User>) => {
  const { data, error } = await supabase
    .from('users')
    .update(updates)
    .eq('id', userId)
    .select()
    .single()

  if (error) throw error
  return data
}

export const deleteUser = async (userId: string) => {
  const { error } = await supabase
    .from('users')
    .delete()
    .eq('id', userId)

  if (error) throw error
}

// Customer functions
export const getAllCustomers = async (): Promise<Customer[]> => {
  const { data, error } = await supabase
    .from('customers')
    .select('*')
    .order('created_at', { ascending: false })

  if (error) {
    console.error('Error fetching customers:', error)
    throw error
  }
  return data || []
}

export const createCustomer = async (customerData: Omit<Customer, 'id' | 'created_at' | 'updated_at' | 'current_balance'>): Promise<Customer> => {
  const { data, error } = await supabase
    .from('customers')
    .insert([customerData])
    .select()
    .single()

  if (error) {
    console.error('Error creating customer:', error)
    throw error
  }
  return data
}

export const updateCustomer = async (customerId: string, updates: Partial<Customer>): Promise<Customer> => {
  const { data, error } = await supabase
    .from('customers')
    .update(updates)
    .eq('id', customerId)
    .select()
    .single()

  if (error) {
    console.error('Error updating customer:', error)
    throw error
  }
  return data
}

export const deleteCustomer = async (customerId: string): Promise<void> => {
  const { error } = await supabase
    .from('customers')
    .delete()
    .eq('id', customerId)

  if (error) {
    console.error('Error deleting customer:', error)
    throw error
  }
}

// Supplier functions
export const getAllSuppliers = async (): Promise<Supplier[]> => {
  const { data, error } = await supabase
    .from('suppliers')
    .select('*')
    .order('created_at', { ascending: false })

  if (error) {
    console.error('Error fetching suppliers:', error)
    throw error
  }
  return data || []
}

// Shipment functions
export const getAllShipments = async (): Promise<Shipment[]> => {
    const { data, error } = await supabase
        .from('shipments')
        .select('*, customers(company_name)')
        .order('created_at', { ascending: false });

    if (error) {
        console.error('Error fetching shipments:', error);
        throw error;
    }
    return data || [];
};

export const createShipment = async (shipmentData: Omit<Shipment, 'id' | 'created_at' | 'updated_at' | 'paid_amount' | 'payment_status' | 'customers' | 'suppliers'>): Promise<Shipment> => {
    const { data, error } = await supabase
        .from('shipments')
        .insert([shipmentData])
        .select()
        .single();

    if (error) {
        console.error('Error creating shipment:', error);
        throw error;
    }
    return data;
};

export const updateShipment = async (shipmentId: string, updates: Partial<Shipment>): Promise<Shipment> => {
    const { data, error } = await supabase
        .from('shipments')
        .update(updates)
        .eq('id', shipmentId)
        .select()
        .single();

    if (error) {
        console.error('Error updating shipment:', error);
        throw error;
    }
    return data;
};

export const deleteShipment = async (shipmentId: string): Promise<void> => {
    const { error } = await supabase
        .from('shipments')
        .delete()
        .eq('id', shipmentId);

    if (error) {
        console.error('Error deleting shipment:', error);
        throw error;
    }
};

// Accounting Functions
export const getChartOfAccounts = async (): Promise<ChartAccount[]> => {
  const { data, error } = await supabase
    .from('chart_of_accounts')
    .select('*')
    .order('account_code', { ascending: true })

  if (error) {
    console.error('Error fetching chart of accounts:', error)
    throw error
  }
  return data || []
}

export const getJournalEntries = async (): Promise<JournalEntry[]> => {
  const { data, error } = await supabase
    .from('journal_entries')
    .select(`
      *,
      journal_entry_details (
        *,
        chart_of_accounts (account_name, account_code)
      )
    `)
    .order('entry_date', { ascending: false })
    .order('created_at', { ascending: false });

  if (error) {
    console.error('Error fetching journal entries:', error);
    throw error;
  }
  return data || [];
};

export type JournalEntryDetailPayload = {
  account_id: string;
  debit_amount: number;
  credit_amount: number;
  description: string;
};

export const createJournalEntry = async (
  entryData: {
    entry_date: string;
    description: string;
    details: JournalEntryDetailPayload[];
  }
): Promise<string> => {
  const { data, error } = await supabase.rpc('create_journal_entry', {
    p_entry_date: entryData.entry_date,
    p_description: entryData.description,
    p_details: entryData.details,
  });

  if (error) {
    console.error('Error creating journal entry:', error);
    throw new Error(error.message || 'فشل إنشاء قيد اليومية');
  }
  return data;
};

export const getTrialBalance = async (): Promise<TrialBalanceItem[]> => {
  const { data, error } = await supabase.rpc('get_trial_balance');

  if (error) {
    console.error('Error fetching trial balance:', error);
    throw new Error(error.message || 'فشل تحميل ميزان المراجعة');
  }
  return data || [];
};

// Financial Reports Functions
export const getIncomeStatement = async (startDate: string, endDate: string): Promise<IncomeStatementItem[]> => {
  const { data, error } = await supabase.rpc('get_income_statement', {
    start_date: startDate,
    end_date: endDate,
  });

  if (error) {
    console.error('Error fetching income statement:', error);
    throw new Error(error.message || 'فشل تحميل قائمة الدخل');
  }
  return data || [];
};

export const getBalanceSheet = async (asOfDate: string): Promise<BalanceSheetItem[]> => {
  const { data, error } = await supabase.rpc('get_balance_sheet', {
    as_of_date: asOfDate,
  });

  if (error) {
    console.error('Error fetching balance sheet:', error);
    throw new Error(error.message || 'فشل تحميل الميزانية العمومية');
  }
  return data || [];
};


// Session storage functions
export const saveSession = (session: SessionData) => {
  localStorage.setItem('session', JSON.stringify(session))
}

export const getSession = (): SessionData | null => {
  try {
    const saved = localStorage.getItem('session')
    return saved ? JSON.parse(saved) : null
  } catch {
    return null
  }
}

export const clearSession = () => {
  localStorage.removeItem('session')
}
