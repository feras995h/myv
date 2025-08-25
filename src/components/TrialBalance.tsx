import React, { useState, useEffect, useMemo } from 'react'
import { motion } from 'framer-motion'
import { Scale, AlertCircle } from 'lucide-react'
import { TrialBalanceItem, getTrialBalance } from '../lib/supabase'

const TrialBalance: React.FC = () => {
  const [data, setData] = useState<TrialBalanceItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  useEffect(() => {
    fetchData()
  }, [])

  const fetchData = async () => {
    try {
      setLoading(true)
      const trialBalanceData = await getTrialBalance()
      setData(trialBalanceData)
    } catch (err: any) {
      setError('فشل تحميل ميزان المراجعة: ' + err.message)
    } finally {
      setLoading(false)
    }
  }

  const { grandTotalDebit, grandTotalCredit, isBalanced } = useMemo(() => {
    const totals = data.reduce((acc, item) => {
      acc.debit += Number(item.total_debit) || 0
      acc.credit += Number(item.total_credit) || 0
      return acc
    }, { debit: 0, credit: 0 })
    
    const epsilon = 0.001;
    return {
      grandTotalDebit: totals.debit,
      grandTotalCredit: totals.credit,
      isBalanced: Math.abs(totals.debit - totals.credit) < epsilon
    }
  }, [data])

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-amber-500"></div>
      </div>
    )
  }

  if (error) {
    return (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4 flex items-center space-x-2 space-x-reverse">
            <AlertCircle className="w-5 h-5 text-red-500" />
            <p className="text-red-700">{error}</p>
        </div>
    )
  }

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
      <div className="p-4 border-b border-gray-200 flex justify-between items-center">
        <div className="flex items-center space-x-3 space-x-reverse">
          <Scale className="w-6 h-6 text-amber-600" />
          <h2 className="text-lg font-bold text-gray-900">ميزان المراجعة</h2>
        </div>
        <div className={`px-3 py-1 rounded-full text-sm font-medium ${isBalanced ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
          {isBalanced ? 'متوازن' : 'غير متوازن'}
        </div>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-right font-medium text-gray-600">رقم الحساب</th>
              <th className="px-6 py-3 text-right font-medium text-gray-600">اسم الحساب</th>
              <th className="px-6 py-3 text-right font-medium text-gray-600">مدين</th>
              <th className="px-6 py-3 text-right font-medium text-gray-600">دائن</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {data.map((item) => (
              <tr key={item.account_id} className="hover:bg-gray-50">
                <td className="px-6 py-3 text-gray-600">{item.account_code}</td>
                <td className="px-6 py-3 font-medium text-gray-900">{item.account_name}</td>
                <td className="px-6 py-3 text-blue-600 font-mono">{item.total_debit.toLocaleString('ar-LY')}</td>
                <td className="px-6 py-3 text-red-600 font-mono">{item.total_credit.toLocaleString('ar-LY')}</td>
              </tr>
            ))}
          </tbody>
          <tfoot className="bg-gray-100">
            <tr>
              <th colSpan={2} className="px-6 py-4 text-right font-bold text-gray-900">الإجمالي</th>
              <th className="px-6 py-4 text-right font-bold text-blue-700 font-mono">{grandTotalDebit.toLocaleString('ar-LY', { style: 'currency', currency: 'LYD' })}</th>
              <th className="px-6 py-4 text-right font-bold text-red-700 font-mono">{grandTotalCredit.toLocaleString('ar-LY', { style: 'currency', currency: 'LYD' })}</th>
            </tr>
          </tfoot>
        </table>
      </div>
    </div>
  )
}

export default TrialBalance
