import React, { useState, useEffect } from 'react'
import { AuthProvider, useAuth } from './contexts/AuthContext'
import LoginForm from './components/LoginForm'
import Layout from './components/Layout'
import Dashboard from './components/Dashboard'
import UserManagement from './components/UserManagement'
import CustomerManagement from './components/CustomerManagement'
import ShipmentManagement from './components/ShipmentManagement'
import AccountingDashboard from './components/AccountingDashboard'
import FinancialReports from './components/FinancialReports'

const AppContent: React.FC = () => {
  const { user, loading } = useAuth()
  const [activeTab, setActiveTab] = useState('dashboard')
  const [showLogin, setShowLogin] = useState(false)

  useEffect(() => {
    if (!loading && !user) {
      setShowLogin(true)
    } else if (user) {
      setShowLogin(false)
    }
  }, [user, loading])

  const renderTabContent = () => {
    switch (activeTab) {
      case 'dashboard':
        return <Dashboard />
      case 'customers':
        return <CustomerManagement />
      case 'shipments':
        return <ShipmentManagement />
      case 'accounting':
        return <AccountingDashboard />
      case 'reports':
        return <FinancialReports />
      case 'settings':
        return <UserManagement />
      default:
        return <Dashboard />
    }
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-amber-50 via-orange-50 to-yellow-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-16 w-16 border-b-2 border-amber-500 mx-auto mb-4"></div>
          <p className="text-gray-600">جاري التحميل...</p>
        </div>
      </div>
    )
  }

  if (showLogin || !user) {
    return <LoginForm onSuccess={() => setShowLogin(false)} />
  }

  return (
    <Layout activeTab={activeTab} onTabChange={setActiveTab}>
      {renderTabContent()}
    </Layout>
  )
}

const App: React.FC = () => {
  return (
    <AuthProvider>
      <AppContent />
    </AuthProvider>
  )
}

export default App
