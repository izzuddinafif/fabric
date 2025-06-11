import { useState } from 'react'
import { useForm } from 'react-hook-form'
import toast from 'react-hot-toast'
import { donationApi } from '@/lib/api'
import { formatCurrency, formatDate } from '@/lib/utils'

interface TrackFormData {
  donationId: string
}

export default function DonationTracker() {
  const [isLoading, setIsLoading] = useState(false)
  const [donation, setDonation] = useState<any>(null)
  
  const {
    register,
    handleSubmit,
    formState: { errors }
  } = useForm<TrackFormData>()

  const onSubmit = async (data: TrackFormData) => {
    setIsLoading(true)
    
    try {
      const result = await donationApi.getById(data.donationId)
      setDonation(result)
    } catch (error: any) {
      toast.error(error.message || 'Donasi tidak ditemukan')
      setDonation(null)
    } finally {
      setIsLoading(false)
    }
  }

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'pending':
        return 'bg-yellow-100 text-yellow-800 border-yellow-200'
      case 'collected':
        return 'bg-islamic-green-100 text-islamic-green-800 border-islamic-green-200'
      case 'distributed':
        return 'bg-blue-100 text-blue-800 border-blue-200'
      default:
        return 'bg-gray-100 text-gray-800 border-gray-200'
    }
  }

  const getStatusText = (status: string) => {
    switch (status) {
      case 'pending':
        return 'Menunggu Pembayaran'
      case 'collected':
        return 'Terkumpul'
      case 'distributed':
        return 'Telah Disalurkan'
      default:
        return status
    }
  }

  const getSyncStatusColor = (status: string) => {
    switch (status) {
      case 'synced':
        return 'bg-islamic-green-100 text-islamic-green-800'
      case 'pending_sync':
        return 'bg-yellow-100 text-yellow-800'
      case 'error':
        return 'bg-red-100 text-red-800'
      default:
        return 'bg-gray-100 text-gray-800'
    }
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="card mb-8">
        <div className="text-center mb-8">
          <h2 className="text-3xl font-bold text-gray-900 mb-2">Lacak Donasi Anda</h2>
          <p className="text-gray-600">
            Masukkan ID donasi untuk melihat status dan transparansi blockchain
          </p>
        </div>

        <form onSubmit={handleSubmit(onSubmit)} className="max-w-md mx-auto">
          <div className="flex space-x-4">
            <div className="flex-1">
              <input
                type="text"
                className="input-field"
                placeholder="ZKT-YDSF-MLG-202406-0001"
                {...register('donationId', { 
                  required: 'ID donasi wajib diisi',
                  pattern: { 
                    value: /^ZKT-YDSF-MLG-\d{6}-\d{4}$/, 
                    message: 'Format ID donasi tidak valid' 
                  }
                })}
              />
              {errors.donationId && <p className="error">{errors.donationId.message}</p>}
            </div>
            <button
              type="submit"
              disabled={isLoading}
              className="btn-primary px-6"
            >
              {isLoading ? (
                <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
              ) : (
                '🔍 Lacak'
              )}
            </button>
          </div>
        </form>
      </div>

      {donation && (
        <div className="space-y-6">
          {/* Main Info Card */}
          <div className="card">
            <div className="flex flex-col md:flex-row justify-between items-start md:items-center mb-6">
              <div>
                <h3 className="text-2xl font-bold text-gray-900 mb-2">
                  Donasi {donation.type === 'fitrah' ? 'Zakat Fitrah' : 'Zakat Maal'}
                </h3>
                <p className="text-gray-600">ID: {donation.id}</p>
              </div>
              <div className="mt-4 md:mt-0 text-right">
                <div className="text-3xl font-bold text-islamic-green-600 mb-2">
                  {formatCurrency(donation.amount)}
                </div>
                <span className={`inline-block px-3 py-1 rounded-full text-sm font-medium border ${getStatusColor(donation.blockchain_status)}`}>
                  {getStatusText(donation.blockchain_status)}
                </span>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <h4 className="font-semibold text-gray-900 mb-3">Informasi Donatur</h4>
                <div className="space-y-2 text-sm">
                  <p><span className="text-gray-500">Nama:</span> {donation.donor_name}</p>
                  <p><span className="text-gray-500">Telepon:</span> {donation.donor_phone}</p>
                  {donation.donor_email && (
                    <p><span className="text-gray-500">Email:</span> {donation.donor_email}</p>
                  )}
                </div>
              </div>

              <div>
                <h4 className="font-semibold text-gray-900 mb-3">Informasi Blockchain</h4>
                <div className="space-y-2 text-sm">
                  <p>
                    <span className="text-gray-500">Status Blockchain:</span>
                    <span className={`ml-2 px-2 py-1 rounded text-xs ${getSyncStatusColor(donation.sync_status)}`}>
                      {donation.sync_status}
                    </span>
                  </p>
                  {donation.blockchain_tx_id && (
                    <p className="break-all">
                      <span className="text-gray-500">TX ID:</span> {donation.blockchain_tx_id}
                    </p>
                  )}
                  {donation.payment_reference && (
                    <p>
                      <span className="text-gray-500">Ref Pembayaran:</span> {donation.payment_reference}
                    </p>
                  )}
                </div>
              </div>
            </div>
          </div>

          {/* Timeline */}
          <div className="card">
            <h4 className="font-semibold text-gray-900 mb-6">Timeline Donasi</h4>
            <div className="space-y-4">
              {/* Created */}
              <div className="flex items-start space-x-4">
                <div className="w-8 h-8 bg-islamic-green-600 rounded-full flex items-center justify-center flex-shrink-0">
                  <svg className="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                  </svg>
                </div>
                <div className="flex-1">
                  <div className="flex justify-between items-center">
                    <h5 className="font-medium text-gray-900">Donasi Dibuat</h5>
                    <span className="text-sm text-gray-500">{formatDate(donation.created_at)}</span>
                  </div>
                  <p className="text-sm text-gray-600">Donasi berhasil dibuat dan dicatat di blockchain</p>
                </div>
              </div>

              {/* Validated */}
              {donation.validated_at && (
                <div className="flex items-start space-x-4">
                  <div className="w-8 h-8 bg-islamic-green-600 rounded-full flex items-center justify-center flex-shrink-0">
                    <svg className="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                    </svg>
                  </div>
                  <div className="flex-1">
                    <div className="flex justify-between items-center">
                      <h5 className="font-medium text-gray-900">Pembayaran Tervalidasi</h5>
                      <span className="text-sm text-gray-500">{formatDate(donation.validated_at)}</span>
                    </div>
                    <p className="text-sm text-gray-600">
                      Pembayaran berhasil divalidasi oleh {donation.validated_by || 'sistem'}
                    </p>
                  </div>
                </div>
              )}

              {/* Distributed */}
              {donation.distributed_at ? (
                <div className="flex items-start space-x-4">
                  <div className="w-8 h-8 bg-blue-600 rounded-full flex items-center justify-center flex-shrink-0">
                    <svg className="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                    </svg>
                  </div>
                  <div className="flex-1">
                    <div className="flex justify-between items-center">
                      <h5 className="font-medium text-gray-900">Zakat Disalurkan</h5>
                      <span className="text-sm text-gray-500">{formatDate(donation.distributed_at)}</span>
                    </div>
                    <p className="text-sm text-gray-600">
                      Zakat telah disalurkan oleh {donation.distributed_by}
                    </p>
                  </div>
                </div>
              ) : donation.blockchain_status === 'collected' && (
                <div className="flex items-start space-x-4">
                  <div className="w-8 h-8 bg-yellow-400 rounded-full flex items-center justify-center flex-shrink-0">
                    <svg className="w-4 h-4 text-white" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-12a1 1 0 10-2 0v4a1 1 0 00.293.707l2.828 2.829a1 1 0 101.415-1.415L11 9.586V6z" clipRule="evenodd" />
                    </svg>
                  </div>
                  <div className="flex-1">
                    <h5 className="font-medium text-gray-900">Menunggu Penyaluran</h5>
                    <p className="text-sm text-gray-600">
                      Zakat sedang dalam proses penyaluran kepada penerima yang berhak
                    </p>
                  </div>
                </div>
              )}
            </div>
          </div>

          {/* Blockchain Info */}
          {donation.blockchain_tx_id && (
            <div className="card bg-gray-50">
              <h4 className="font-semibold text-gray-900 mb-4">Verifikasi Blockchain</h4>
              <div className="bg-white rounded-lg p-4 border">
                <div className="flex items-center space-x-3 mb-3">
                  <div className="w-10 h-10 bg-islamic-green-100 rounded-full flex items-center justify-center">
                    <svg className="w-5 h-5 text-islamic-green-600" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M6.267 3.455a3.066 3.066 0 001.745-.723 3.066 3.066 0 013.976 0 3.066 3.066 0 001.745.723 3.066 3.066 0 012.812 2.812c.051.643.304 1.254.723 1.745a3.066 3.066 0 010 3.976 3.066 3.066 0 00-.723 1.745 3.066 3.066 0 01-2.812 2.812 3.066 3.066 0 00-1.745.723 3.066 3.066 0 01-3.976 0 3.066 3.066 0 00-1.745-.723 3.066 3.066 0 01-2.812-2.812 3.066 3.066 0 00-.723-1.745 3.066 3.066 0 010-3.976 3.066 3.066 0 00.723-1.745 3.066 3.066 0 012.812-2.812zm7.44 5.252a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                    </svg>
                  </div>
                  <div>
                    <h5 className="font-medium text-gray-900">Terverifikasi Blockchain</h5>
                    <p className="text-sm text-gray-600">Donasi tercatat secara permanen di Hyperledger Fabric</p>
                  </div>
                </div>
                <div className="text-xs text-gray-500 font-mono break-all bg-gray-100 p-2 rounded">
                  Transaction ID: {donation.blockchain_tx_id}
                </div>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
