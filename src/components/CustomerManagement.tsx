import React, { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { 
  Plus, 
  Edit, 
  Trash2, 
  Search,
  Users,
  Building,
  Mail,
  Phone,
  MapPin,
  DollarSign,
  AlertCircle,
  CheckCircle
} from 'lucide-react'
import { 
  Customer, 
  getAllCustomers, 
  createCustomer, 
  updateCustomer, 
  deleteCustomer 
} from '../lib/supabase'
import { useAuth } from '../contexts/AuthContext'

const CustomerManagement: React.FC = () => {
  const { user } = useAuth()
  const [customers, setCustomers] = useState<Customer[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [showModal, setShowModal] = useState(false)
  const [isEditMode, setIsEditMode] = useState(false)
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  const initialFormData = {
    company_name: '',
    contact_person: '',
    email: '',
    phone: '',
    address: '',
    city: 'Tripoli',
    country: 'Libya',
    tax_number: '',
    credit_limit: 0,
    payment_terms: 30,
    is_active: true,
  }

  const [formData, setFormData] = useState(initialFormData)

  useEffect(() => {
    fetchCustomers()
  }, [])

  const fetchCustomers = async () => {
    try {
      setLoading(true)
      const data = await getAllCustomers()
      setCustomers(data)
    } catch (error: any) {
      setError('خطأ في تحميل العملاء: ' + error.message)
    } finally {
      setLoading(false)
    }
  }

  const handleFormChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value, type } = e.target;
    
    if (type === 'checkbox') {
        const { checked } = e.target as HTMLInputElement;
        setFormData(prev => ({ ...prev, [name]: checked }));
    } else {
        setFormData(prev => ({ ...prev, [name]: value }));
    }
  };

  const resetForm = () => {
    setFormData(initialFormData)
    setSelectedCustomer(null)
    setIsEditMode(false)
  }

  const openCreateModal = () => {
    resetForm()
    setShowModal(true)
  }

  const openEditModal = (customer: Customer) => {
    setSelectedCustomer(customer)
    setFormData({
      company_name: customer.company_name,
      contact_person: customer.contact_person || '',
      email: customer.email || '',
      phone: customer.phone || '',
      address: customer.address || '',
      city: customer.city || 'Tripoli',
      country: customer.country,
      tax_number: customer.tax_number || '',
      credit_limit: customer.credit_limit,
      payment_terms: customer.payment_terms,
      is_active: customer.is_active,
    })
    setIsEditMode(true)
    setShowModal(true)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setSuccess('')

    const submissionData = {
        ...formData,
        credit_limit: Number(formData.credit_limit),
        payment_terms: Number(formData.payment_terms),
        created_by: user?.id
    };

    try {
      if (isEditMode && selectedCustomer) {
        await updateCustomer(selectedCustomer.id, submissionData)
        setSuccess('تم تحديث العميل بنجاح')
      } else {
        await createCustomer(submissionData)
        setSuccess('تم إنشاء العميل بنجاح')
      }
      setShowModal(false)
      resetForm()
      fetchCustomers()
    } catch (error: any) {
      setError(error.message || 'حدث خطأ ما')
    }
  }

  const handleDelete = async (customerId: string) => {
    if (!confirm('هل أنت متأكد من حذف هذا العميل؟ لا يمكن التراجع عن هذا الإجراء.')) return

    try {
      setError('')
      setSuccess('')
      await deleteCustomer(customerId)
      setSuccess('تم حذف العميل بنجاح')
      fetchCustomers()
    } catch (error: any) {
      setError(error.message)
    }
  }

  const filteredCustomers = customers.filter(customer =>
    customer.company_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    customer.contact_person?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    customer.email?.toLowerCase().includes(searchTerm.toLowerCase())
  )

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-amber-500"></div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">إدارة العملاء</h1>
          <p className="text-gray-600">إضافة وإدارة عملاء الشركة</p>
        </div>
        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          onClick={openCreateModal}
          className="bg-gradient-to-r from-amber-500 to-orange-500 text-white px-6 py-3 rounded-lg font-medium hover:from-amber-600 hover:to-orange-600 transition-all shadow-lg flex items-center space-x-2 space-x-reverse"
        >
          <Plus className="w-5 h-5" />
          <span>إضافة عميل جديد</span>
        </motion.button>
      </div>

      {/* Alerts */}
      <AnimatePresence>
        {error && (
          <motion.div
            initial={{ opacity: 0, y: -10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -10 }}
            className="bg-red-50 border border-red-200 rounded-lg p-4 flex items-center space-x-2 space-x-reverse"
          >
            <AlertCircle className="w-5 h-5 text-red-500" />
            <p className="text-red-700">{error}</p>
            <button onClick={() => setError('')} className="mr-auto text-red-500 hover:text-red-700">×</button>
          </motion.div>
        )}
        {success && (
          <motion.div
            initial={{ opacity: 0, y: -10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -10 }}
            className="bg-green-50 border border-green-200 rounded-lg p-4 flex items-center space-x-2 space-x-reverse"
          >
            <CheckCircle className="w-5 h-5 text-green-500" />
            <p className="text-green-700">{success}</p>
            <button onClick={() => setSuccess('')} className="mr-auto text-green-500 hover:text-green-700">×</button>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Search */}
      <div className="relative">
        <Search className="absolute right-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
        <input
          type="text"
          placeholder="البحث في العملاء..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="w-full pr-10 pl-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-amber-500 focus:border-transparent"
        />
      </div>

      {/* Customers Table */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-4 text-right text-sm font-medium text-gray-900">العميل</th>
                <th className="px-6 py-4 text-right text-sm font-medium text-gray-900">معلومات الاتصال</th>
                <th className="px-6 py-4 text-right text-sm font-medium text-gray-900">الرصيد</th>
                <th className="px-6 py-4 text-right text-sm font-medium text-gray-900">الحالة</th>
                <th className="px-6 py-4 text-right text-sm font-medium text-gray-900">الإجراءات</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filteredCustomers.map((customer) => (
                <motion.tr key={customer.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="hover:bg-gray-50">
                  <td className="px-6 py-4">
                    <div className="flex items-center space-x-3 space-x-reverse">
                      <div className="w-10 h-10 bg-gradient-to-br from-blue-400 to-blue-500 rounded-full flex items-center justify-center">
                        <Building className="w-5 h-5 text-white" />
                      </div>
                      <div>
                        <p className="font-medium text-gray-900">{customer.company_name}</p>
                        <p className="text-sm text-gray-500">{customer.contact_person}</p>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <div className="space-y-1">
                      {customer.email && (
                        <div className="flex items-center space-x-2 space-x-reverse text-sm text-gray-600">
                          <Mail className="w-4 h-4" />
                          <span>{customer.email}</span>
                        </div>
                      )}
                      {customer.phone && (
                        <div className="flex items-center space-x-2 space-x-reverse text-sm text-gray-600">
                          <Phone className="w-4 h-4" />
                          <span>{customer.phone}</span>
                        </div>
                      )}
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <p className="font-medium text-gray-900">{customer.current_balance.toLocaleString()} د.ل</p>
                    <p className="text-sm text-gray-500">الحد: {customer.credit_limit.toLocaleString()} د.ل</p>
                  </td>
                  <td className="px-6 py-4">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${customer.is_active ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
                      {customer.is_active ? 'نشط' : 'غير نشط'}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex items-center space-x-2 space-x-reverse">
                      <button onClick={() => openEditModal(customer)} className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors" title="تعديل">
                        <Edit className="w-4 h-4" />
                      </button>
                      <button onClick={() => handleDelete(customer.id)} className="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors" title="حذف">
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </td>
                </motion.tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Modal */}
      <AnimatePresence>
        {showModal && (
          <motion.div
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
            onClick={() => setShowModal(false)}
          >
            <motion.div
              initial={{ scale: 0.95, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} exit={{ scale: 0.95, opacity: 0 }}
              className="bg-white rounded-xl p-6 w-full max-w-2xl max-h-[90vh] overflow-y-auto"
              onClick={(e) => e.stopPropagation()}
            >
              <h2 className="text-xl font-bold text-gray-900 mb-6">{isEditMode ? 'تعديل العميل' : 'إضافة عميل جديد'}</h2>
              
              <form onSubmit={handleSubmit} className="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-4">
                {/* Form fields */}
                <div className="md:col-span-2">
                  <label className="block text-sm font-medium text-gray-700 mb-1">اسم الشركة *</label>
                  <input type="text" name="company_name" value={formData.company_name} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" required />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">مسؤول الاتصال</label>
                  <input type="text" name="contact_person" value={formData.contact_person} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">البريد الإلكتروني</label>
                  <input type="email" name="email" value={formData.email} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">رقم الهاتف</label>
                  <input type="tel" name="phone" value={formData.phone} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">الرقم الضريبي</label>
                  <input type="text" name="tax_number" value={formData.tax_number} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
                </div>
                <div className="md:col-span-2">
                  <label className="block text-sm font-medium text-gray-700 mb-1">العنوان</label>
                  <input type="text" name="address" value={formData.address} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">المدينة</label>
                  <input type="text" name="city" value={formData.city} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">الدولة</label>
                  <input type="text" name="country" value={formData.country} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">الحد الائتماني (د.ل)</label>
                  <input type="number" name="credit_limit" value={formData.credit_limit} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">أيام الدفع</label>
                  <input type="number" name="payment_terms" value={formData.payment_terms} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
                </div>
                <div className="md:col-span-2 flex items-center space-x-3 space-x-reverse">
                  <input type="checkbox" id="is_active" name="is_active" checked={formData.is_active} onChange={handleFormChange} className="h-4 w-4 text-amber-600 focus:ring-amber-500 border-gray-300 rounded" />
                  <label htmlFor="is_active" className="text-sm font-medium text-gray-700">عميل نشط</label>
                </div>

                <div className="md:col-span-2 flex space-x-3 space-x-reverse pt-4">
                  <button type="submit" className="flex-1 bg-gradient-to-r from-amber-500 to-orange-500 text-white py-2 px-4 rounded-lg font-medium hover:from-amber-600 hover:to-orange-600 transition-all">
                    {isEditMode ? 'حفظ التغييرات' : 'إنشاء العميل'}
                  </button>
                  <button type="button" onClick={() => setShowModal(false)} className="flex-1 bg-gray-100 text-gray-700 py-2 px-4 rounded-lg font-medium hover:bg-gray-200 transition-all">
                    إلغاء
                  </button>
                </div>
              </form>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

export default CustomerManagement
