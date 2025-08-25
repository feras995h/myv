import React, { useState } from 'react'
import { motion } from 'framer-motion'
import { BookOpen, Scale } from 'lucide-react'
import ChartOfAccounts from './ChartOfAccounts'
import JournalEntries from './JournalEntries'
import TrialBalance from './TrialBalance'

const AccountingDashboard: React.FC = () => {
  const [activeTab, setActiveTab] = useState('journal_entries')

  const tabs = [
    { id: 'journal_entries', label: 'قيود اليومية', icon: BookOpen },
    { id: 'trial_balance', label: 'ميزان المراجعة', icon: Scale },
    { id: 'chart_of_accounts', label: 'دليل الحسابات', icon: BookOpen },
  ]

  const renderContent = () => {
    switch (activeTab) {
      case 'chart_of_accounts':
        return <ChartOfAccounts />
      case 'journal_entries':
        return <JournalEntries />
      case 'trial_balance':
        return <TrialBalance />
      default:
        return <JournalEntries />
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">النظام المالي والمحاسبي</h1>
        <p className="text-gray-600">نظرة شاملة على الوضع المالي للشركة</p>
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
              } whitespace-nowrap py-4 px-1 border-b-2 font-medium text-sm flex items-center space-x-2 space-x-reverse`}
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

export default AccountingDashboard
