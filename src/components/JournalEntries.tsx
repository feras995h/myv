import React, { useState, useEffect, useMemo } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { 
  Plus, 
  Trash2, 
  BookOpen, 
  AlertCircle, 
  CheckCircle, 
  Eye,
  X
} from 'lucide-react'
import { 
  JournalEntry, 
  ChartAccount,
  getJournalEntries, 
  createJournalEntry, 
  getChartOfAccounts,
  JournalEntryDetailPayload
} from '../lib/supabase'
import { useAuth } from '../contexts/AuthContext'
import { format } from 'date-fns'

const JournalEntries: React.FC = () => {
  const { user } = useAuth()
  const [entries, setEntries] = useState<JournalEntry[]>([])
  const [accounts, setAccounts] = useState<ChartAccount[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const [showModal, setShowModal] = useState(false)

  const initialEntryData = {
    entry_date: format(new Date(), 'yyyy-MM-dd'),
    description: '',
    details: [
      { account_id: '', debit_amount: 0, credit_amount: 0, description: '' },
      { account_id: '', debit_amount: 0, credit_amount: 0, description: '' },
    ] as JournalEntryDetailPayload[]
  }
  const [newEntry, setNewEntry] = useState(initialEntryData)

  useEffect(() => {
    fetchData()
  }, [])

  const fetchData = async () => {
    try {
      setLoading(true)
      const [entriesData, accountsData] = await Promise.all([
        getJournalEntries(),
        getChartOfAccounts()
      ])
      setEntries(entriesData)
      setAccounts(accountsData.filter(acc => !accounts.some(child => child.parent_account_id === acc.id)))
    } catch (err: any) {
      setError('فشل تحميل البيانات: ' + err.message)
    } finally {
      setLoading(false)
    }
  }

  const handleDetailChange = (index: number, field: keyof JournalEntryDetailPayload, value: any) => {
    const updatedDetails = [...newEntry.details]
    updatedDetails[index] = { ...updatedDetails[index], [field]: value }

    // Ensure only one of debit/credit has a value
    if (field === 'debit_amount' && value > 0) {
      updatedDetails[index].credit_amount = 0
    } else if (field === 'credit_amount' && value > 0) {
      updatedDetails[index].debit_amount = 0
    }

    setNewEntry({ ...newEntry, details: updatedDetails })
  }

  const addDetailRow = () => {
    setNewEntry({
      ...newEntry,
      details: [...newEntry.details, { account_id: '', debit_amount: 0, credit_amount: 0, description: '' }]
    })
  }

  const removeDetailRow = (index: number) => {
    if (newEntry.details.length <= 2) {
      setError('يجب أن يحتوي القيد على طرفين على الأقل')
      return
    }
    const updatedDetails = newEntry.details.filter((_, i) => i !== index)
    setNewEntry({ ...newEntry, details: updatedDetails })
  }

  const { totalDebit, totalCredit, isBalanced } = useMemo(() => {
    const totals = newEntry.details.reduce((acc, detail) => {
      acc.debit += Number(detail.debit_amount) || 0
      acc.credit += Number(detail.credit_amount) || 0
      return acc
    }, { debit: 0, credit: 0 })
    return {
      totalDebit: totals.debit,
      totalCredit: totals.credit,
      isBalanced: totals.debit === totals.credit && totals.debit > 0
    }
  }, [newEntry.details])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setSuccess('')

    if (!isBalanced) {
      setError('القيد غير متوازن. يجب أن يتساوى إجمالي المدين مع إجمالي الدائن.')
      return
    }

    if (newEntry.details.some(d => !d.account_id)) {
        setError('يرجى اختيار حساب لكل سطر في القيد.')
        return
    }

    try {
      await createJournalEntry({
        entry_date: newEntry.entry_date,
        description: newEntry.description,
        details: newEntry.details
      })
      setSuccess('تم إنشاء قيد اليومية بنجاح')
      setShowModal(false)
      setNewEntry(initialEntryData)
      fetchData()
    } catch (err: any) {
      setError(err.message || 'حدث خطأ ما')
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
      <div className="flex justify-between items-center">
        <h2 className="text-xl font-bold text-gray-900">قيود اليومية</h2>
        <motion.button
          whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.98 }}
          onClick={() => setShowModal(true)}
          className="bg-gradient-to-r from-amber-500 to-orange-500 text-white px-4 py-2 rounded-lg font-medium shadow-lg flex items-center space-x-2 space-x-reverse"
        >
          <Plus className="w-5 h-5" />
          <span>قيد يومية جديد</span>
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

      {/* Journal Entries Table */}
      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-6 py-3 text-right text-sm font-medium text-gray-600">رقم القيد</th>
                <th className="px-6 py-3 text-right text-sm font-medium text-gray-600">التاريخ</th>
                <th className="px-6 py-3 text-right text-sm font-medium text-gray-600">الوصف</th>
                <th className="px-6 py-3 text-right text-sm font-medium text-gray-600">المبلغ</th>
                <th className="px-6 py-3 text-right text-sm font-medium text-gray-600">الحالة</th>
                <th className="px-6 py-3 text-right text-sm font-medium text-gray-600">الإجراءات</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200">
              {entries.map((entry) => (
                <motion.tr key={entry.id} initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="hover:bg-gray-50">
                  <td className="px-6 py-4 font-medium text-gray-900">{entry.entry_number}</td>
                  <td className="px-6 py-4 text-gray-600">{format(new Date(entry.entry_date), 'dd/MM/yyyy')}</td>
                  <td className="px-6 py-4 text-gray-600 truncate max-w-sm">{entry.description}</td>
                  <td className="px-6 py-4 text-gray-900 font-mono">{entry.total_debit.toLocaleString('ar-LY')} د.ل</td>
                  <td className="px-6 py-4">
                    <span className={`px-2 py-1 rounded-full text-xs font-medium ${entry.is_approved ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800'}`}>
                      {entry.is_approved ? 'معتمد' : 'غير معتمد'}
                    </span>
                  </td>
                  <td className="px-6 py-4">
                    <button className="p-2 text-gray-500 hover:bg-gray-100 rounded-lg" title="عرض التفاصيل">
                      <Eye className="w-4 h-4" />
                    </button>
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
              className="bg-white rounded-xl p-6 w-full max-w-4xl max-h-[90vh] flex flex-col"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="flex justify-between items-center mb-6">
                <h2 className="text-xl font-bold text-gray-900">إضافة قيد يومية جديد</h2>
                <button onClick={() => setShowModal(false)} className="p-2 rounded-full hover:bg-gray-100">
                  <X className="w-5 h-5 text-gray-600" />
                </button>
              </div>
              
              <form onSubmit={handleSubmit} className="flex-grow overflow-y-auto space-y-4 pr-2">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700 mb-1">تاريخ القيد</label>
                    <input type="date" value={newEntry.entry_date} onChange={e => setNewEntry({...newEntry, entry_date: e.target.value})} className="w-full px-3 py-2 border border-gray-300 rounded-lg" required />
                  </div>
                  <div className="md:col-span-2">
                    <label className="block text-sm font-medium text-gray-700 mb-1">الوصف العام للقيد</label>
                    <input type="text" value={newEntry.description} onChange={e => setNewEntry({...newEntry, description: e.target.value})} className="w-full px-3 py-2 border border-gray-300 rounded-lg" placeholder="مثال: إثبات فاتورة مبيعات" required />
                  </div>
                </div>

                <div className="space-y-2">
                  {newEntry.details.map((detail, index) => (
                    <div key={index} className="grid grid-cols-12 gap-2 items-center">
                      <div className="col-span-4">
                        <select value={detail.account_id} onChange={e => handleDetailChange(index, 'account_id', e.target.value)} className="w-full px-2 py-2 border border-gray-300 rounded-lg text-sm" required>
                          <option value="">اختر الحساب</option>
                          {accounts.map(acc => <option key={acc.id} value={acc.id}>{acc.account_code} - {acc.account_name}</option>)}
                        </select>
                      </div>
                      <div className="col-span-2">
                        <input type="number" placeholder="مدين" value={detail.debit_amount || ''} onChange={e => handleDetailChange(index, 'debit_amount', e.target.value)} className="w-full px-2 py-2 border border-gray-300 rounded-lg text-sm" />
                      </div>
                      <div className="col-span-2">
                        <input type="number" placeholder="دائن" value={detail.credit_amount || ''} onChange={e => handleDetailChange(index, 'credit_amount', e.target.value)} className="w-full px-2 py-2 border border-gray-300 rounded-lg text-sm" />
                      </div>
                      <div className="col-span-3">
                        <input type="text" placeholder="وصف السطر" value={detail.description} onChange={e => handleDetailChange(index, 'description', e.target.value)} className="w-full px-2 py-2 border border-gray-300 rounded-lg text-sm" />
                      </div>
                      <div className="col-span-1">
                        <button type="button" onClick={() => removeDetailRow(index)} className="p-2 text-red-500 hover:bg-red-50 rounded-full">
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
                <button type="button" onClick={addDetailRow} className="text-sm text-amber-600 hover:underline">+ إضافة سطر جديد</button>
              </form>

              <div className="border-t mt-6 pt-4">
                <div className="flex justify-between items-center mb-4">
                  <div className="text-lg font-bold">الإجمالي</div>
                  <div className={`px-3 py-1 rounded-full text-sm font-medium ${isBalanced ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
                    {isBalanced ? 'متوازن' : 'غير متوازن'}
                  </div>
                </div>
                <div className="flex justify-around bg-gray-50 p-4 rounded-lg">
                  <div className="text-center">
                    <p className="text-sm text-gray-600">إجمالي المدين</p>
                    <p className="text-xl font-bold font-mono text-blue-600">{totalDebit.toLocaleString('ar-LY')} د.ل</p>
                  </div>
                  <div className="text-center">
                    <p className="text-sm text-gray-600">إجمالي الدائن</p>
                    <p className="text-xl font-bold font-mono text-red-600">{totalCredit.toLocaleString('ar-LY')} د.ل</p>
                  </div>
                </div>
              </div>

              <div className="flex space-x-3 space-x-reverse pt-6">
                <button type="submit" form="journal-entry-form" onClick={handleSubmit} disabled={!isBalanced} className="flex-1 bg-gradient-to-r from-amber-500 to-orange-500 text-white py-2 px-4 rounded-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed">
                  حفظ القيد
                </button>
                <button type="button" onClick={() => setShowModal(false)} className="flex-1 bg-gray-100 text-gray-700 py-2 px-4 rounded-lg font-medium hover:bg-gray-200">
                  إلغاء
                </button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  )
}

export default JournalEntries
