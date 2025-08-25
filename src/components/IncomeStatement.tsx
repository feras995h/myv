import React, { useState, useEffect, useMemo } from 'react'
import { motion } from 'framer-motion'
import { FileText, AlertCircle, Calendar } from 'lucide-react'
import { IncomeStatementItem, getIncomeStatement } from '../lib/supabase'
import { format, subDays } from 'date-fns'

const IncomeStatement: React.FC = () => {
  const [data, setData] = useState<IncomeStatementItem[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [dateRange, setDateRange] = useState({
    start: format(subDays(new Date(), 30), 'yyyy-MM-dd'),
    end: format(new Date(), 'yyyy-MM-dd'),
  })

  useEffect(() => {
    fetchData()
  }, [])

  const fetchData = async () => {
    if (!dateRange.start || !dateRange.end) {
      setError('يرجى تحديد تاريخ البداية والنهاية')
      return
    }
    try {
      setLoading(true)
      setError('')
      const reportData = await getIncomeStatement(dateRange.start, dateRange.end)
      setData(reportData)
    } catch (err: any) {
      setError('فشل تحميل قائمة الدخل: ' + err.message)
    } finally {
      setLoading(false)
    }
  }

  const handleDateChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    setDateRange({ ...dateRange, [e.target.name]: e.target.value })
  }

  const { revenues, expenses, totalRevenue, totalExpense, netIncome } = useMemo(() => {
    const revenues = data.filter(item => item.category === 'الإيرادات')
    const expenses = data.filter(item => item.category === 'المصاريف')
    const totalRevenue = revenues.reduce((sum, item) => sum + item.amount, 0)
    const totalExpense = expenses.reduce((sum, item) => sum + item.amount, 0)
    const netIncome = totalRevenue - totalExpense
    return { revenues, expenses, totalRevenue, totalExpense, netIncome }
  }, [data])

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
      <div className="p-4 border-b border-gray-200">
        <div className="flex flex-wrap justify-between items-center gap-4">
          <div className="flex items-center space-x-3 space-x-reverse">
            <FileText className="w-6 h-6 text-amber-600" />
            <h2 className="text-lg font-bold text-gray-900">قائمة الدخل</h2>
          </div>
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <label htmlFor="start-date" className="text-sm font-medium text-gray-700">من:</label>
              <input type="date" name="start" id="start-date" value={dateRange.start} onChange={handleDateChange} className="border-gray-300 rounded-md shadow-sm text-sm"/>
            </div>
            <div className="flex items-center gap-2">
              <label htmlFor="end-date" className="text-sm font-medium text-gray-700">إلى:</label>
              <input type="date" name="end" id="end-date" value={dateRange.end} onChange={handleDateChange} className="border-gray-300 rounded-md shadow-sm text-sm"/>
            </div>
            <button onClick={fetchData} disabled={loading} className="bg-amber-500 text-white px-4 py-2 rounded-md text-sm font-medium hover:bg-amber-600 disabled:opacity-50">
              {loading ? 'جاري...' : 'عرض التقرير'}
            </button>
          </div>
        </div>
      </div>

      {loading && (
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-amber-500"></div>
        </div>
      )}

      {!loading && error && (
        <div className="p-6 text-center text-red-500">
            <AlertCircle className="w-8 h-8 mx-auto mb-2" />
            {error}
        </div>
      )}

      {!loading && !error && (
        <div className="p-6">
          <div className="max-w-2xl mx-auto">
            {/* Revenues */}
            <h3 className="text-lg font-semibold text-gray-800 mb-2">الإيرادات</h3>
            <div className="divide-y divide-gray-100">
              {revenues.map((item, i) => (
                <div key={`rev-${i}`} className="flex justify-between py-2">
                  <span className="text-gray-600">{item.account_name}</span>
                  <span className="font-mono">{item.amount.toLocaleString('ar-LY')}</span>
                </div>
              ))}
            </div>
            <div className="flex justify-between py-2 mt-2 border-t-2 border-gray-200">
              <span className="font-semibold text-gray-900">إجمالي الإيرادات</span>
              <span className="font-semibold font-mono text-green-600">{totalRevenue.toLocaleString('ar-LY')}</span>
            </div>

            {/* Expenses */}
            <h3 className="text-lg font-semibold text-gray-800 mt-6 mb-2">المصاريف</h3>
            <div className="divide-y divide-gray-100">
              {expenses.map((item, i) => (
                <div key={`exp-${i}`} className="flex justify-between py-2">
                  <span className="text-gray-600">{item.account_name}</span>
                  <span className="font-mono">({item.amount.toLocaleString('ar-LY')})</span>
                </div>
              ))}
            </div>
            <div className="flex justify-between py-2 mt-2 border-t-2 border-gray-200">
              <span className="font-semibold text-gray-900">إجمالي المصاريف</span>
              <span className="font-semibold font-mono text-red-600">({totalExpense.toLocaleString('ar-LY')})</span>
            </div>

            {/* Net Income */}
            <div className={`flex justify-between p-4 mt-6 rounded-lg ${netIncome >= 0 ? 'bg-green-50' : 'bg-red-50'}`}>
              <span className="text-xl font-bold">{netIncome >= 0 ? 'صافي الربح' : 'صافي الخسارة'}</span>
              <span className={`text-xl font-bold font-mono ${netIncome >= 0 ? 'text-green-700' : 'text-red-700'}`}>
                {netIncome.toLocaleString('ar-LY', { style: 'currency', currency: 'LYD' })}
              </span>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default IncomeStatement
