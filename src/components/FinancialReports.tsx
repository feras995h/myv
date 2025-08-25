import React, { useState } from 'react'
import { motion } from 'framer-motion'
import { FileText, BarChart2 } from 'lucide-react'
import IncomeStatement from './IncomeStatement'
import BalanceSheet from './BalanceSheet'

const FinancialReports: React.FC = () => {
  const [activeTab, setActiveTab] = useState('income_statement')

  const tabs = [
    { id: 'income_statement', label: 'قائمة الدخل', icon: FileText },
    { id: 'balance_sheet', label: 'الميزانية العمومية', icon: BarChart2 },
  ]

  const renderContent = () => {
    switch (activeTab) {
      case 'income_statement':
        return <IncomeStatement />
      case 'balance_sheet':
        return <BalanceSheet />
      default:
        return <IncomeStatement />
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">التقارير المالية</h1>
        <p className="text-gray-600">تحليل الأداء والوضع المالي للشركة</p>
      </div>

      {/* Tabs */}
      <div className="border-b border-gray-200">
        <nav className="-mb-px flex space-x-6 space-x-reverse" aria-label="Tabs">
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`${
                activeTab === tab.id
                  ? 'border-amber-500 text-amber-600'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
              } whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center space-x-2 space-x-reverse transition-colors`}
            >
              <tab.icon className="w-5 h-5" />
              <span>{tab.label}</span>
            </button>
          ))}
        </nav>
      </div>
      
      {/* Content */}
      <motion.div
        key={activeTab}
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.3 }}
      >
        {renderContent()}
      </motion.div>
    </div>
  )
}

export default FinancialReports
