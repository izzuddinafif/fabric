// Utility functions for formatting and validation

// Format currency to Indonesian Rupiah
export const formatCurrency = (amount: number): string => {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount)
}

// Format date to Indonesian format
export const formatDate = (date: string | Date): string => {
  const dateObj = typeof date === 'string' ? new Date(date) : date
  return new Intl.DateTimeFormat('id-ID', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(dateObj)
}

// Format date to short format
export const formatDateShort = (date: string | Date): string => {
  const dateObj = typeof date === 'string' ? new Date(date) : date
  return new Intl.DateTimeFormat('id-ID', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  }).format(dateObj)
}

// Validate Indonesian phone number
export const validatePhoneNumber = (phone: string): boolean => {
  const phoneRegex = /^08\d{8,11}$/
  return phoneRegex.test(phone)
}

// Validate email
export const validateEmail = (email: string): boolean => {
  const emailRegex = /^\S+@\S+\.\S+$/
  return emailRegex.test(email)
}

// Generate donation ID (for reference)
export const generateDonationId = (): string => {
  const now = new Date()
  const year = now.getFullYear()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const timestamp = now.getTime().toString().slice(-4)
  return `ZKT-YDSF-MLG-${year}${month}-${timestamp}`
}

// Truncate text
export const truncateText = (text: string, maxLength: number): string => {
  if (text.length <= maxLength) return text
  return text.substring(0, maxLength) + '...'
}

// Capitalize first letter
export const capitalize = (text: string): string => {
  return text.charAt(0).toUpperCase() + text.slice(1)
}

// Convert blockchain status to readable text
export const getReadableStatus = (status: string): string => {
  const statusMap: Record<string, string> = {
    pending: 'Menunggu Pembayaran',
    collected: 'Terkumpul',
    distributed: 'Telah Disalurkan',
    synced: 'Tersinkron',
    pending_sync: 'Menunggu Sinkronisasi',
    error: 'Error'
  }
  return statusMap[status] || status
}

// Get status color class
export const getStatusColorClass = (status: string): string => {
  const colorMap: Record<string, string> = {
    pending: 'bg-yellow-100 text-yellow-800 border-yellow-200',
    collected: 'bg-green-100 text-green-800 border-green-200',
    distributed: 'bg-blue-100 text-blue-800 border-blue-200',
    synced: 'bg-green-100 text-green-800',
    pending_sync: 'bg-yellow-100 text-yellow-800',
    error: 'bg-red-100 text-red-800'
  }
  return colorMap[status] || 'bg-gray-100 text-gray-800'
}

// Calculate zakat fitrah amount (sample calculation)
export const calculateZakatFitrah = (ricePrice: number = 40000): number => {
  // 2.5 kg rice equivalent
  return Math.round(2.5 * ricePrice)
}

// Calculate zakat maal (2.5% of wealth)
export const calculateZakatMaal = (wealth: number): number => {
  return Math.round(wealth * 0.025)
}

// Check if zakat maal is required (nisab threshold)
export const isZakatMaalRequired = (wealth: number, goldPrice: number = 1000000): boolean => {
  const nisab = 85 * goldPrice / 1000 // 85 grams of gold equivalent
  return wealth >= nisab
}

// Format large numbers
export const formatLargeNumber = (num: number): string => {
  if (num >= 1000000000) {
    return (num / 1000000000).toFixed(1) + 'M'
  }
  if (num >= 1000000) {
    return (num / 1000000).toFixed(1) + 'jt'
  }
  if (num >= 1000) {
    return (num / 1000).toFixed(1) + 'rb'
  }
  return num.toString()
}
