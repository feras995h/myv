import React, { useState, useEffect, useMemo } from 'react'
import { motion } from 'framer-motion'
import { BarChart2, AlertCircle } from 'lucide-react'
import { BalanceSheetItem, getBalanceSheet } from '../lib/supabase'
import { format } from 'date-fns'

const BalanceSheet: React.FC = () => {
  const [data, setData] = useState<BalanceSheetItem[]>([])
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [asOfDate, setAsOfDate] = useState(format(new Date(), 'yyyy-MM-dd'))

  useEffect(() => {
    fetchData()
  }, [])

  const fetchData = async () => {
    try {
      setLoading(true)
      setError('')
      const reportData = await getBalanceSheet(asOfDate)
      setData(reportData)
    } catch (err: any) {
      setError('فشل تحميل الميزانية العمومية: ' + err.message)
    } finally {
      setLoading(false)
    }
  }

  const { assets, liabilities, equity, totalAssets, totalLiabilities, totalEquity, totalLiabilitiesAndEquity, isBalanced } = useMemo(() => {
    const assets = data.filter(item => item.category === 'الأصول')
    const liabilities = data.filter(item => item.category === 'الخصوم')
    const equity = data.filter(item => item.category === 'حقوق الملكية')

    const totalAssets = assets.reduce((sum, item) => sum + item.balance, 0)
    const totalLiabilities = liabilities.reduce((sum, item) => sum + item.balance, 0)
    const totalEquity = equity.reduce((sum, item) => sum + item.balance, 0)
    const totalLiabilitiesAndEquity = totalLiabilities + totalEquity
    
    const epsilon = 0.001;
    const isBalanced = Math.abs(totalAssets - totalLiabilitiesAndEquity) < epsilon;

    return { assets, liabilities, equity, totalAssets, totalLiabilities, totalEquity, totalLiabilitiesAndEquity, isBalanced }
  }, [data])

  const renderSection = (title: string, items: BalanceSheetItem[]) => (
    <div>
      <h3 className="text-lg font-semibold text-gray-800 mb-2 p-2 bg-gray-100 rounded-md">{title}</h3>
      <div className="divide-y divide-gray-100 pl-4">
        {items.map((item, i) => (
          <div key={`${title}-${i}`} className="flex justify-between py-2">
            <span className="text-gray-600">{item.account_name}</span>
            <span className="font-mono">{item.balance.toLocaleString('ar-LY')}</span>
          </div>
        ))}
      </div>
    </div>
  )

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
      <div className="p-4 border-b border-gray-200">
        <div className="flex flex-wrap justify-between items-center gap-4">
          <div className="flex items-center space-x-3 space-x-reverse">
            <BarChart2 className="w-6 h-6 text-amber-600" />
            <h2 className="text-lg font-bold text-gray-900">الميزانية العمومية</h2>
          </div>
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2">
              <label htmlFor="as-of-date" className="text-sm font-medium text-gray-700">في تاريخ:</label>
              <input type="date" name="asOfDate" id="as-of-date" value={asOfDate} onChange={e => setAsOfDate(e.target.value)} className="border-gray-300 rounded-md shadow-sm text-sm"/>
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
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-x-8 p-6">
          {/* Assets */}
          <div className="space-y-4">
            {renderSection('الأصول', assets)}
            <div className="flex justify-between py-2 mt-2 border-t-2 border-gray-200">
              <span className="font-semibold text-gray-900 text-lg">إجمالي الأصول</span>
              <span className="font-semibold font-mono text-lg text-blue-600">{totalAssets.toLocaleString('ar-LY', { style: 'currency', currency: 'LYD' })}</span>
            </div>
          </div>

          {/* Liabilities & Equity */}
          <div className="space-y-4">
            {renderSection('الخصوم', liabilities)}
            <div className="flex justify-between py-2 mt-2 border-t border-gray-200">
              <span className="font-semibold text-gray-900">إجمالي الخصوم</span>
              <span className="font-semibold font-mono text-red-600">{totalLiabilities.toLocaleString('ar-LY')}</span>
            </div>
            
            <div className="mt-4">
              {renderSection('حقوق الملكية', equity)}
              <div className="flex justify-between py-2 mt-2 border-t border-gray-200">
                <span className="font-semibold text-gray-900">إجمالي حقوق الملكية</span>
                <span className="font-semibold font-mono text-green-600">{totalEquity.toLocaleString('ar-LY')}</span>
              </div>
            </div>

            <div className="flex justify-between py-2 mt-2 border-t-2 border-gray-200">
              <span className="font-semibold text-gray-900 text-lg">إجمالي الخصوم وحقوق الملكية</span>
              <span className="font-semibold font-mono text-lg text-blue-600">{totalLiabilitiesAndEquity.toLocaleString('ar-LY', { style: 'currency', currency: 'LYD' })}</span>
            </div>
          </div>
          
          <div className={`lg:col-span-2 mt-6 p-4 rounded-lg text-center ${isBalanced ? 'bg-green-50 text-green-800' : 'bg-red-50 text-red-800'}`}>
            <p className="font-bold">{isBalanced ? 'المعادلة المحاسبية متوازنة' : 'المعادلة المحاسبية غير متوازنة'}</p>
          </div>
        </div>
      )}
    </div>
  )
}

export default BalanceSheet
