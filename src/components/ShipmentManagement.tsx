import React, { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { 
  Plus, 
  Edit, 
  Trash2, 
  Search,
  Package,
  Ship,
  User,
  MapPin,
  DollarSign,
  Calendar,
  AlertCircle,
  CheckCircle
} from 'lucide-react'
import { 
  Shipment, 
  Customer,
  getAllShipments, 
  createShipment, 
  updateShipment, 
  deleteShipment,
  getAllCustomers
} from '../lib/supabase'
import { useAuth } from '../contexts/AuthContext'
import { format } from 'date-fns'

const ShipmentManagement: React.FC = () => {
  const { user } = useAuth()
  const [shipments, setShipments] = useState<Shipment[]>([])
  const [customers, setCustomers] = useState<Customer[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [showModal, setShowModal] = useState(false)
  const [isEditMode, setIsEditMode] = useState(false)
  const [selectedShipment, setSelectedShipment] = useState<Shipment | null>(null)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')

  const initialFormData = {
    shipment_number: `SH-${new Date().getFullYear()}-${Math.floor(1000 + Math.random() * 9000)}`,
    customer_id: '',
    origin_port: 'Shanghai',
    destination_port: 'Tripoli',
    departure_date: '',
    estimated_arrival: '',
    status: 'pending' as Shipment['status'],
    container_number: '',
    seal_number: '',
    weight_kg: 0,
    volume_cbm: 0,
    total_amount: 0,
    notes: ''
  }

  const [formData, setFormData] = useState(initialFormData)

  useEffect(() => {
    fetchInitialData()
  }, [])

  const fetchInitialData = async () => {
    try {
      setLoading(true)
      const [shipmentsData, customersData] = await Promise.all([
        getAllShipments(),
        getAllCustomers()
      ])
      setShipments(shipmentsData)
      setCustomers(customersData)
    } catch (error: any) {
      setError('خطأ في تحميل البيانات: ' + error.message)
    } finally {
      setLoading(false)
    }
  }

  const handleFormChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target
    setFormData(prev => ({ ...prev, [name]: value }))
  }

  const resetForm = () => {
    setFormData(initialFormData)
    setSelectedShipment(null)
    setIsEditMode(false)
  }

  const openCreateModal = () => {
    resetForm()
    setShowModal(true)
  }

  const openEditModal = (shipment: Shipment) => {
    setSelectedShipment(shipment)
    setFormData({
      shipment_number: shipment.shipment_number,
      customer_id: shipment.customer_id,
      origin_port: shipment.origin_port,
      destination_port: shipment.destination_port,
      departure_date: shipment.departure_date ? format(new Date(shipment.departure_date), 'yyyy-MM-dd') : '',
      estimated_arrival: shipment.estimated_arrival ? format(new Date(shipment.estimated_arrival), 'yyyy-MM-dd') : '',
      status: shipment.status,
      container_number: shipment.container_number || '',
      seal_number: shipment.seal_number || '',
      weight_kg: shipment.weight_kg || 0,
      volume_cbm: shipment.volume_cbm || 0,
      total_amount: shipment.total_amount || 0,
      notes: shipment.notes || ''
    })
    setIsEditMode(true)
    setShowModal(true)
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setSuccess('')

    if (!formData.customer_id) {
        setError('يرجى اختيار العميل');
        return;
    }

    const submissionData = {
        ...formData,
        weight_kg: Number(formData.weight_kg),
        volume_cbm: Number(formData.volume_cbm),
        total_amount: Number(formData.total_amount),
        departure_date: formData.departure_date || null,
        estimated_arrival: formData.estimated_arrival || null,
        created_by: user?.id
    };

    try {
      if (isEditMode && selectedShipment) {
        await updateShipment(selectedShipment.id, submissionData)
        setSuccess('تم تحديث الشحنة بنجاح')
      } else {
        await createShipment(submissionData)
        setSuccess('تم إنشاء الشحنة بنجاح')
      }
      setShowModal(false)
      resetForm()
      fetchInitialData()
    } catch (error: any) {
      setError(error.message || 'حدث خطأ ما')
    }
  }

  const handleDelete = async (shipmentId: string) => {
    if (!confirm('هل أنت متأكد من حذف هذه الشحنة؟')) return

    try {
      setError('')
      setSuccess('')
      await deleteShipment(shipmentId)
      setSuccess('تم حذف الشحنة بنجاح')
      fetchInitialData()
    } catch (error: any) {
      setError(error.message)
    }
  }

  const filteredShipments = shipments.filter(shipment =>
    shipment.shipment_number.toLowerCase().includes(searchTerm.toLowerCase()) ||
    shipment.customers?.company_name?.toLowerCase().includes(searchTerm.toLowerCase())
  )
  
  const getStatusColor = (status: string) => {
    switch (status) {
      case 'pending': return 'bg-yellow-100 text-yellow-800'
      case 'processing': return 'bg-blue-100 text-blue-800'
      case 'shipped': return 'bg-indigo-100 text-indigo-800'
      case 'in_transit': return 'bg-purple-100 text-purple-800'
      case 'delivered': return 'bg-green-100 text-green-800'
      case 'cancelled': return 'bg-red-100 text-red-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  const getStatusText = (status: string) => {
    const statuses: { [key: string]: string } = {
        pending: 'في الانتظار',
        processing: 'قيد التجهيز',
        shipped: 'تم الشحن',
        in_transit: 'في الطريق',
        delivered: 'تم التسليم',
        cancelled: 'ملغي'
    };
    return statuses[status] || status;
  }

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
          <h1 className="text-2xl font-bold text-gray-900">إدارة الشحنات</h1>
          <p className="text-gray-600">تتبع وإدارة جميع الشحنات</p>
        </div>
        <motion.button
          whileHover={{ scale: 1.02 }}
          whileTap={{ scale: 0.98 }}
          onClick={openCreateModal}
          className="bg-gradient-to-r from-amber-500 to-orange-500 text-white px-6 py-3 rounded-lg font-medium hover:from-amber-600 hover:to-orange-600 transition-all shadow-lg flex items-center space-x-2 space-x-reverse"
        >
          <Plus className="w-5 h-5" />
          <span>إضافة شحنة جديدة</span>
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
          placeholder="البحث برقم الشحنة أو اسم العميل..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="w-full pr-10 pl-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-amber-500 focus:border-transparent"
        />
      </div>

      {/* Shipments Table */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-4 text-right text-sm font-medium text-gray-900">رقم الشحنة</th>
                <th className="px-6 py-4 text-right text-sm font-medium text-gray-900">العميل</th>
                <th className="px-6 py-4 text-right text-sm font-medium text-gray-900">المسار</th>
                <th className="px-6 py-4 text-right text-sm font-medium text-gray-900">الحالة</th>
                <th className="px-6 py-4 text-right text-sm font-medium text-gray-900">التكلفة</th>
                <th className="px-6 py-4 text-right text-sm font-medium text-gray-900">الإجراءات</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {filteredShipments.map((shipment) => (
                <motion.tr key={shipment.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="hover:bg-gray-50">
                  <td className="px-6 py-4">
                    <p className="font-medium text-gray-900">{shipment.shipment_number}</p>
                    <p className="text-sm text-gray-500">
                      {shipment.created_at ? new Date(shipment.created_at).toLocaleDateString('ar-LY') : ''}
                    </p>
                  </td>
                  <td className="px-6 py-4">
                    <p className="text-gray-900">{shipment.customers?.company_name || 'غير محدد'}</p>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex items-center space-x-2 space-x-reverse text-sm text-gray-600">
                        <MapPin className="w-4 h-4" />
                        <span>{shipment.origin_port} ← {shipment.destination_port}</span>
                    </div>
                  </td>
                  <td className="px-6 py-4">
                    <span className={`px-3 py-1 rounded-full text-sm font-medium ${getStatusColor(shipment.status)}`}>
                      {getStatusText(shipment.status)}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <p className="font-medium text-gray-900">{shipment.total_amount.toLocaleString()} د.ل</p>
                  </td>
                  <td className="px-6 py-4">
                    <div className="flex items-center space-x-2 space-x-reverse">
                      <button onClick={() => openEditModal(shipment)} className="p-2 text-blue-600 hover:bg-blue-50 rounded-lg" title="تعديل">
                        <Edit className="w-4 h-4" />
                      </button>
                      <button onClick={() => handleDelete(shipment.id)} className="p-2 text-red-600 hover:bg-red-50 rounded-lg" title="حذف">
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
              className="bg-white rounded-xl p-6 w-full max-w-3xl max-h-[90vh] overflow-y-auto"
              onClick={(e) => e.stopPropagation()}
            >
              <h2 className="text-xl font-bold text-gray-900 mb-6">{isEditMode ? 'تعديل الشحنة' : 'إضافة شحنة جديدة'}</h2>
              
              <form onSubmit={handleSubmit} className="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-4">
                <div className="md:col-span-2">
                  <label className="block text-sm font-medium text-gray-700 mb-1">رقم الشحنة</label>
                  <input type="text" name="shipment_number" value={formData.shipment_number} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg bg-gray-50" readOnly />
                </div>
                
                <div className="md:col-span-2">
                  <label className="block text-sm font-medium text-gray-700 mb-1">العميل *</label>
                  <select name="customer_id" value={formData.customer_id} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" required>
                    <option value="">اختر عميلاً</option>
                    {customers.map(c => (
                      <option key={c.id} value={c.id}>{c.company_name}</option>
                    ))}
                  </select>
                </div>
                
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">ميناء المغادرة</label>
                  <input type="text" name="origin_port" value={formData.origin_port} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">ميناء الوصول</label>
                  <input type="text" name="destination_port" value={formData.destination_port} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">تاريخ المغادرة</label>
                  <input type="date" name="departure_date" value={formData.departure_date} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">تاريخ الوصول المتوقع</label>
                  <input type="date" name="estimated_arrival" value={formData.estimated_arrival} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">الحالة</label>
                  <select name="status" value={formData.status} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg">
                    {Object.entries(getStatusText).map(([key, value]) => (
                        <option key={key} value={key}>{value}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">التكلفة الإجمالية (د.ل)</label>
                  <input type="number" name="total_amount" value={formData.total_amount} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">رقم الحاوية</label>
                  <input type="text" name="container_number" value={formData.container_number} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">رقم الختم</label>
                  <input type="text" name="seal_number" value={formData.seal_number} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">الوزن (كجم)</label>
                  <input type="number" name="weight_kg" value={formData.weight_kg} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">الحجم (م³)</label>
                  <input type="number" name="volume_cbm" value={formData.volume_cbm} onChange={handleFormChange} className="w-full px-3 py-2 border border-gray-300 rounded-lg" />
                </div>
                <div className="md:col-span-2">
                  <label className="block text-sm font-medium text-gray-700 mb-1">ملاحظات</label>
                  <textarea name="notes" value={formData.notes} onChange={handleFormChange} rows={3} className="w-full px-3 py-2 border border-gray-300 rounded-lg"></textarea>
                </div>

                <div className="md:col-span-2 flex space-x-3 space-x-reverse pt-4">
                  <button type="submit" className="flex-1 bg-gradient-to-r from-amber-500 to-orange-500 text-white py-2 px-4 rounded-lg font-medium">
                    {isEditMode ? 'حفظ التغييرات' : 'إنشاء الشحنة'}
                  </button>
                  <button type="button" onClick={() => setShowModal(false)} className="flex-1 bg-gray-100 text-gray-700 py-2 px-4 rounded-lg font-medium">
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

export default ShipmentManagement
