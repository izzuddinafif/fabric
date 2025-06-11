import axios from 'axios'

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3002/api'

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Add token to requests if available
apiClient.interceptors.request.use((config) => {
  if (typeof window !== 'undefined') {
    const token = localStorage.getItem('auth_token')
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
  }
  return config
})

// Handle response errors
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      if (typeof window !== 'undefined') {
        localStorage.removeItem('auth_token')
        window.location.href = '/admin/login'
      }
    }
    return Promise.reject(error)
  }
)

// Donation API
export const donationApi = {
  create: async (data: any) => {
    const response = await apiClient.post('/donations', data)
    return response.data
  },
  
  getById: async (id: string) => {
    const response = await apiClient.get(`/donations/${id}`)
    return response.data
  },
  
  getAll: async (params?: any) => {
    const response = await apiClient.get('/admin/donations', { params })
    return response.data
  },
  
  validate: async (id: string) => {
    const response = await apiClient.post(`/admin/donations/${id}/validate`)
    return response.data
  },
  
  distribute: async (id: string) => {
    const response = await apiClient.post(`/admin/donations/${id}/distribute`)
    return response.data
  },
}

// Auth API
export const authApi = {
  adminLogin: async (credentials: { phone: string; password: string }) => {
    const response = await apiClient.post('/auth/admin/login', credentials)
    return response.data
  },
  
  logout: async () => {
    const response = await apiClient.post('/auth/logout')
    return response.data
  },
}

// Admin API
export const adminApi = {
  getDashboard: async () => {
    const response = await apiClient.get('/admin/dashboard')
    return response.data
  },
}

export default apiClient
