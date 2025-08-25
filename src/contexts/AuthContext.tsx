import React, { createContext, useContext, useEffect, useState } from 'react'
import { 
  User, 
  signInWithUsername, 
  signOut as authSignOut, 
  getSession, 
  saveSession, 
  clearSession,
  getMyProfile
} from '../lib/supabase'
import { supabase } from '../lib/supabase'

interface AuthContextType {
  user: User | null
  loading: boolean
  signIn: (username: string, password: string) => Promise<User>
  signOut: () => Promise<void>
  refreshUser: () => Promise<void>
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export const useAuth = () => {
  const context = useContext(AuthContext)
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return context
}

interface AuthProviderProps {
  children: React.ReactNode
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    initializeAuth()
  }, [])

  const initializeAuth = async () => {
    try {
      const savedSession = getSession()
      if (savedSession && savedSession.token) {
        await supabase.auth.setSession({
          access_token: savedSession.token,
          refresh_token: savedSession.token,
        })
        
        const currentUser = await getMyProfile()
        if (currentUser) {
          setUser(currentUser)
          saveSession({ user: currentUser, token: savedSession.token })
        } else {
          clearSession()
          await supabase.auth.signOut()
        }
      }
    } catch (error) {
      console.error('Error initializing auth:', error)
      clearSession()
    } finally {
      setLoading(false)
    }
  }

  const signIn = async (username: string, password: string): Promise<User> => {
    try {
      const userData = await signInWithUsername(username, password)
      setUser(userData)
      return userData
    } catch (error) {
      throw error
    }
  }

  const signOut = async () => {
    try {
      await authSignOut()
      setUser(null)
    } catch (error) {
      console.error('Error signing out:', error)
      setUser(null)
      clearSession()
    }
  }

  const refreshUser = async () => {
    try {
      const currentUser = await getMyProfile()
      if (currentUser) {
        const session = getSession()
        setUser(currentUser)
        if (session) {
          saveSession({ user: currentUser, token: session.token })
        }
      } else {
        await signOut()
      }
    } catch (error) {
      console.error('Error refreshing user:', error)
      await signOut()
    }
  }

  const value = {
    user,
    loading,
    signIn,
    signOut,
    refreshUser
  }

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  )
}
