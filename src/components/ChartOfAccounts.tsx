import React, { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import { BookOpen, ChevronDown, ChevronLeft } from 'lucide-react'
import { ChartAccount, getChartOfAccounts } from '../lib/supabase'

const ChartOfAccounts: React.FC = () => {
  const [accounts, setAccounts] = useState<ChartAccount[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [expanded, setExpanded] = useState<Set<string>>(new Set())

  useEffect(() => {
    fetchAccounts()
  }, [])

  const fetchAccounts = async () => {
    try {
      setLoading(true)
      const data = await getChartOfAccounts()
      setAccounts(data)
      // Expand first level by default
      const defaultExpanded = new Set(data.filter(acc => acc.level === 1).map(acc => acc.id))
      setExpanded(defaultExpanded)
    } catch (err: any) {
      setError('فشل تحميل دليل الحسابات: ' + err.message)
    } finally {
      setLoading(false)
    }
  }
  
  const toggleNode = (id: string) => {
    setExpanded(prev => {
      const newSet = new Set(prev)
      if (newSet.has(id)) {
        newSet.delete(id)
      } else {
        newSet.add(id)
      }
      return newSet
    })
  }

  const accountTypeLabels: { [key: string]: string } = {
    asset: 'أصل',
    liability: 'خصم',
    equity: 'حقوق ملكية',
    revenue: 'إيراد',
    expense: 'مصروف',
  }
  
  const accountTypeColors: { [key: string]: string } = {
    asset: 'bg-blue-100 text-blue-800',
    liability: 'bg-red-100 text-red-800',
    equity: 'bg-green-100 text-green-800',
    revenue: 'bg-purple-100 text-purple-800',
    expense: 'bg-orange-100 text-orange-800',
  }

  const renderTree = (parentId: string | null = null): JSX.Element[] => {
    return accounts
      .filter(account => account.parent_account_id === parentId)
      .map(account => {
        const children = accounts.filter(child => child.parent_account_id === account.id)
        const isExpanded = expanded.has(account.id)
        
        return (
          <React.Fragment key={account.id}>
            <tr className="hover:bg-gray-50">
              <td className="px-6 py-3">
                <div className="flex items-center" style={{ paddingRight: `${(account.level - 1) * 2}rem` }}>
                  {children.length > 0 && (
                    <button onClick={() => toggleNode(account.id)} className="p-1 rounded-md hover:bg-gray-200">
                      {isExpanded ? <ChevronDown className="w-4 h-4" /> : <ChevronLeft className="w-4 h-4" />}
                    </button>
                  )}
                  <span className="font-medium text-gray-900 mr-2">{account.account_name}</span>
                </div>
              </td>
              <td className="px-6 py-3 text-gray-600">{account.account_code}</td>
              <td className="px-6 py-3">
                <span className={`px-2 py-1 rounded-full text-xs font-medium ${accountTypeColors[account.account_type]}`}>
                  {accountTypeLabels[account.account_type]}
                </span>
              </td>
              <td className="px-6 py-3 text-gray-900 font-mono">{account.balance.toLocaleString('ar-LY', { style: 'currency', currency: 'LYD' })}</td>
            </tr>
            {isExpanded && children.length > 0 && renderTree(account.id)}
          </React.Fragment>
        )
      })
  }


  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-amber-500"></div>
      </div>
    )
  }

  if (error) {
    return <div className="text-red-500 text-center p-6">{error}</div>
  }

  return (
    <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
      <div className="p-4 border-b border-gray-200 flex justify-between items-center">
        <div className="flex items-center space-x-3 space-x-reverse">
          <BookOpen className="w-6 h-6 text-amber-600" />
          <h2 className="text-lg font-bold text-gray-900">دليل الحسابات</h2>
        </div>
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-right font-medium text-gray-600">اسم الحساب</th>
              <th className="px-6 py-3 text-right font-medium text-gray-600">رقم الحساب</th>
              <th className="px-6 py-3 text-right font-medium text-gray-600">نوع الحساب</th>
              <th className="px-6 py-3 text-right font-medium text-gray-600">الرصيد الحالي</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {renderTree()}
          </tbody>
        </table>
      </div>
    </div>
  )
}

export default ChartOfAccounts
