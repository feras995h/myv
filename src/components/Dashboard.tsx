import React, { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { 
  Users, 
  Package, 
  DollarSign, 
  TrendingUp,
  Ship,
  MapPin,
  Calendar,
  AlertCircle
} from 'lucide-react'
import { supabase, Shipment } from '../lib/supabase'
import { useAuth } from '../contexts/AuthContext'

interface DashboardStats {
  totalCustomers: number
  activeShipments: number
  monthlyRevenue: number
  pendingInvoices: number
  totalShipments: number
  deliveredShipments: number
}

const Dashboard: React.FC = () => {
  const { user } = useAuth()
  const [stats, setStats] = useState<DashboardStats>({
    totalCustomers: 0,
    activeShipments: 0,
    monthlyRevenue: 0,
    pendingInvoices: 0,
    totalShipments: 0,
    deliveredShipments: 0
  })
  const [loading, setLoading] = useState(true)
  const [recentShipments, setRecentShipments] = useState<any[]>([])

  useEffect(() => {
    fetchDashboardData()
  }, [])

  const fetchDashboardData = async () => {
    try {
      // Fetch customers count
      const { count: customersCount } = await supabase
        .from('customers')
        .select('*', { count: 'exact', head: true })
        .eq('is_active', true)

      // Fetch shipments stats
      const { data: shipments } = await supabase
        .from('shipments')
        .select('status, total_amount')

      const activeShipments = shipments?.filter(s => s.status === 'in_transit').length || 0
      const totalShipments = shipments?.length || 0
      const deliveredShipments = shipments?.filter(s => s.status === 'delivered').length || 0

      // Fetch recent shipments
      const { data: recentShipmentsData } = await supabase
        .from('shipments')
        .select(`
          id,
          shipment_number,
          status,
          origin_port,
          destination_port,
          total_amount,
          created_at,
          customers(company_name)
        `)
        .order('created_at', { ascending: false })
        .limit(5)

      // Calculate monthly revenue
      const monthlyRevenue = shipments?.reduce((sum, s) => sum + (s.total_amount || 0), 0) || 0

      setStats({
        totalCustomers: customersCount || 0,
        activeShipments,
        monthlyRevenue,
        pendingInvoices: 5, // Mock data
        totalShipments,
        deliveredShipments
      })

      setRecentShipments(recentShipmentsData || [])
    } catch (error) {
      console.error('Error fetching dashboard data:', error)
    } finally {
      setLoading(false)
    }
  }

  const statCards = [
    {
      title: 'إجمالي العملاء',
      value: stats.totalCustomers,
      icon: Users,
      color: 'from-blue-500 to-blue-600',
      bgColor: 'bg-blue-50',
      textColor: 'text-blue-600'
    },
    {
      title: 'الشحنات النشطة',
      value: stats.activeShipments,
      icon: Package,
      color: 'from-amber-500 to-orange-500',
      bgColor: 'bg-amber-50',
      textColor: 'text-amber-600'
    },
    {
      title: 'الإيرادات الشهرية',
      value: `${stats.monthlyRevenue.toLocaleString()} د.ل`,
      icon: DollarSign,
      color: 'from-green-500 to-green-600',
      bgColor: 'bg-green-50',
      textColor: 'text-green-600'
    },
    {
      title: 'الفواتير المعلقة',
      value: stats.pendingInvoices,
      icon: AlertCircle,
      color: 'from-red-500 to-red-600',
      bgColor: 'bg-red-50',
      textColor: 'text-red-600'
    }
  ]

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'pending': return 'bg-yellow-100 text-yellow-800'
      case 'in_transit': return 'bg-blue-100 text-blue-800'
      case 'delivered': return 'bg-green-100 text-green-800'
      case 'cancelled': return 'bg-red-100 text-red-800'
      default: return 'bg-gray-100 text-gray-800'
    }
  }

  const getStatusText = (status: string) => {
    switch (status) {
      case 'pending': return 'في الانتظار'
      case 'in_transit': return 'في الطريق'
      case 'delivered': return 'تم التسليم'
      case 'cancelled': return 'ملغي'
      default: return status
    }
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
      {/* Welcome Header */}
      <div className="bg-gradient-to-r from-amber-500 to-orange-500 rounded-2xl p-6 text-white">
        <h1 className="text-2xl font-bold mb-2">
          مرحباً، {user?.full_name}
        </h1>
        <p className="text-amber-100">
          مرحباً بك في لوحة تحكم نظام إدارة الشحن
        </p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        {statCards.map((card, index) => {
          const IconComponent = card.icon
          return (
            <motion.div
              key={card.title}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.1 }}
              className="bg-white rounded-xl p-6 shadow-sm border border-gray-100 hover:shadow-md transition-shadow"
            >
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-600 mb-1">
                    {card.title}
                  </p>
                  <p className="text-2xl font-bold text-gray-900">
                    {card.value}
                  </p>
                </div>
                <div className={`${card.bgColor} p-3 rounded-lg`}>
                  <IconComponent className={`w-6 h-6 ${card.textColor}`} />
                </div>
              </div>
            </motion.div>
          )
        })}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Recent Shipments */}
        <motion.div
          initial={{ opacity: 0, x: -20 }}
          animate={{ opacity: 1, x: 0 }}
          className="bg-white rounded-xl p-6 shadow-sm border border-gray-100"
        >
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-900">الشحنات الأخيرة</h2>
            <Ship className="w-5 h-5 text-gray-400" />
          </div>
          
          <div className="space-y-4">
            {recentShipments.map((shipment) => (
              <div key={shipment.id} className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div className="flex-1">
                  <div className="flex items-center space-x-2 space-x-reverse mb-1">
                    <p className="font-medium text-gray-900">{shipment.shipment_number}</p>
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${getStatusColor(shipment.status)}`}>
                      {getStatusText(shipment.status)}
                    </span>
                  </div>
                  <div className="flex items-center space-x-2 space-x-reverse text-sm text-gray-600">
                    <MapPin className="w-4 h-4" />
                    <span>{shipment.origin_port} ← {shipment.destination_port}</span>
                  </div>
                  <p className="text-xs text-gray-500 mt-1">
                    العميل: {shipment.customers?.company_name || 'غير محدد'}
                  </p>
                </div>
                <div className="text-left">
                  <p className="text-sm font-medium text-gray-900">
                    {shipment.total_amount?.toLocaleString() || '0'} د.ل
                  </p>
                </div>
              </div>
            ))}
          </div>
        </motion.div>

        {/* Quick Stats */}
        <motion.div
          initial={{ opacity: 0, x: 20 }}
          animate={{ opacity: 1, x: 0 }}
          className="bg-white rounded-xl p-6 shadow-sm border border-gray-100"
        >
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-900">إحصائيات سريعة</h2>
            <TrendingUp className="w-5 h-5 text-gray-400" />
          </div>
          
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-gray-600">إجمالي الشحنات</span>
              <span className="font-semibold text-gray-900">{stats.totalShipments}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-600">تم التسليم</span>
              <span className="font-semibold text-green-600">{stats.deliveredShipments}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-600">في الطريق</span>
              <span className="font-semibold text-blue-600">{stats.activeShipments}</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-gray-600">معدل التسليم</span>
              <span className="font-semibold text-gray-900">
                {stats.totalShipments > 0 ? Math.round((stats.deliveredShipments / stats.totalShipments) * 100) : 0}%
              </span>
            </div>
          </div>

          {/* Progress bar */}
          <div className="mt-4">
            <div className="flex justify-between text-sm text-gray-600 mb-1">
              <span>معدل إنجاز الشحنات</span>
              <span>{stats.totalShipments > 0 ? Math.round((stats.deliveredShipments / stats.totalShipments) * 100) : 0}%</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div 
                className="bg-gradient-to-r from-green-400 to-green-500 h-2 rounded-full transition-all duration-300"
                style={{ width: `${stats.totalShipments > 0 ? (stats.deliveredShipments / stats.totalShipments) * 100 : 0}%` }}
              ></div>
            </div>
          </div>
        </motion.div>
      </div>

      {/* Recent Activity */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="bg-white rounded-xl p-6 shadow-sm border border-gray-100"
      >
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold text-gray-900">النشاط الأخير</h2>
          <Calendar className="w-5 h-5 text-gray-400" />
        </div>
        
        <div className="space-y-3">
          <div className="flex items-start space-x-3 space-x-reverse">
            <div className="w-2 h-2 bg-green-500 rounded-full mt-2"></div>
            <div className="flex-1">
              <p className="text-sm text-gray-900">تم تسليم الشحنة SH-2024-001</p>
              <p className="text-xs text-gray-500">منذ ساعتين</p>
            </div>
          </div>
          <div className="flex items-start space-x-3 space-x-reverse">
            <div className="w-2 h-2 bg-blue-500 rounded-full mt-2"></div>
            <div className="flex-1">
              <p className="text-sm text-gray-900">شحنة جديدة في الطريق - SH-2024-002</p>
              <p className="text-xs text-gray-500">منذ 4 ساعات</p>
            </div>
          </div>
          <div className="flex items-start space-x-3 space-x-reverse">
            <div className="w-2 h-2 bg-amber-500 rounded-full mt-2"></div>
            <div className="flex-1">
              <p className="text-sm text-gray-900">عميل جديد مسجل - شركة النور</p>
              <p className="text-xs text-gray-500">أمس</p>
            </div>
          </div>
        </div>
      </motion.div>
    </div>
  )
}

export default Dashboard
