import React, { useState } from 'react'
import { motion } from 'framer-motion'
import { User, Lock, Shield, AlertCircle } from 'lucide-react'
import { useAuth } from '../contexts/AuthContext'

interface LoginFormProps {
  onSuccess: () => void
}

const LoginForm: React.FC<LoginFormProps> = ({ onSuccess }) => {
  const { signIn } = useAuth()
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')

    try {
      await signIn(username, password)
      onSuccess()
    } catch (err: any) {
      setError(err.message || 'حدث خطأ ما')
    } finally {
      setLoading(false)
    }
  }

  const demoAccounts = [
    { username: 'admin', password: 'admin123', role: 'مدير النظام' },
    { username: 'financial', password: '123456', role: 'القسم المالي' },
    { username: 'sales', password: '123456', role: 'المبيعات' },
    { username: 'service', password: '123456', role: 'خدمة العملاء' }
  ]

  const fillDemoAccount = (account: typeof demoAccounts[0]) => {
    setUsername(account.username)
    setPassword(account.password)
    setError('')
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-amber-50 via-orange-50 to-yellow-50 flex items-center justify-center p-4" dir="rtl">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="bg-white rounded-2xl shadow-2xl p-8 w-full max-w-md border border-amber-100"
      >
        {/* Header */}
        <div className="text-center mb-8">
          <div className="w-20 h-20 bg-gradient-to-br from-amber-400 to-orange-500 rounded-full flex items-center justify-center mx-auto mb-4">
            <Shield className="w-10 h-10 text-white" />
          </div>
          <h1 className="text-2xl font-bold bg-gradient-to-r from-amber-600 to-orange-600 bg-clip-text text-transparent mb-2">
            نظام إدارة الشحن
          </h1>
          <p className="text-gray-600">من الصين إلى ليبيا</p>
        </div>

        {/* Form */}
        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              اسم المستخدم
            </label>
            <div className="relative">
              <User className="absolute right-3 top-3 h-5 w-5 text-gray-400" />
              <input
                type="text"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                className="w-full pr-10 pl-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-amber-500 focus:border-transparent text-lg"
                placeholder="أدخل اسم المستخدم"
                required
                autoComplete="username"
              />
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              كلمة المرور
            </label>
            <div className="relative">
              <Lock className="absolute right-3 top-3 h-5 w-5 text-gray-400" />
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full pr-10 pl-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-amber-500 focus:border-transparent text-lg"
                placeholder="أدخل كلمة المرور"
                required
                autoComplete="current-password"
              />
            </div>
          </div>

          {error && (
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              className="bg-red-50 border border-red-200 rounded-lg p-4 flex items-center space-x-2 space-x-reverse"
            >
              <AlertCircle className="w-5 h-5 text-red-500 flex-shrink-0" />
              <p className="text-red-700 text-sm">{error}</p>
            </motion.div>
          )}

          <motion.button
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            type="submit"
            disabled={loading}
            className="w-full bg-gradient-to-r from-amber-500 to-orange-500 text-white py-3 px-4 rounded-lg font-medium text-lg hover:from-amber-600 hover:to-orange-600 focus:ring-4 focus:ring-amber-300 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-lg"
          >
            {loading ? (
              <div className="flex items-center justify-center space-x-2 space-x-reverse">
                <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
                <span>جاري تسجيل الدخول...</span>
              </div>
            ) : (
              'تسجيل الدخول'
            )}
          </motion.button>
        </form>

        {/* Demo Accounts */}
        <div className="mt-8 p-4 bg-amber-50 rounded-lg border border-amber-200">
          <p className="text-amber-800 text-sm font-medium mb-3 text-center">حسابات تجريبية:</p>
          <div className="space-y-2">
            {demoAccounts.map((account, index) => (
              <motion.button
                key={account.username}
                whileHover={{ scale: 1.02 }}
                whileTap={{ scale: 0.98 }}
                onClick={() => fillDemoAccount(account)}
                className="w-full text-right p-2 rounded-md bg-white border border-amber-200 hover:bg-amber-50 transition-colors"
              >
                <div className="flex justify-between items-center">
                  <span className="text-xs text-amber-600">{account.role}</span>
                  <div className="text-sm">
                    <span className="font-medium text-amber-800">{account.username}</span>
                    <span className="text-amber-600 mx-2">•</span>
                    <span className="text-amber-700">{account.password}</span>
                  </div>
                </div>
              </motion.button>
            ))}
          </div>
          <p className="text-amber-700 text-xs mt-2 text-center">انقر على أي حساب لملء البيانات تلقائياً</p>
        </div>

        {/* Footer */}
        <div className="mt-6 text-center">
          <p className="text-xs text-gray-500">
            تم التطوير بواسطة Dualite Alpha
          </p>
        </div>
      </motion.div>
    </div>
  )
}

export default LoginForm
