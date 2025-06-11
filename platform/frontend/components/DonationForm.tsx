import { useState } from 'react'
import { useForm } from 'react-hook-form'
import toast from 'react-hot-toast'
import { donationApi } from '@/lib/api'
import { formatCurrency } from '@/lib/utils'

interface DonationFormData {
  name: string
  phone: string
  email: string
  amount: number
  type: 'fitrah' | 'maal'
  program_id: string
  referral_code?: string
}

export default function DonationForm() {
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [donationResult, setDonationResult] = useState<any>(null)
  
  const {
    register,
    handleSubmit,
    watch,
    reset,
    formState: { errors }
  } = useForm<DonationFormData>()

  const watchAmount = watch('amount')
  const watchType = watch('type')

  const programs = [
    { id: 'PROG-FITRAH-2024', name: 'Zakat Fitrah 2024' },
    { id: 'PROG-MAAL-2024', name: 'Zakat Maal 2024' },
    { id: 'PROG-PENDIDIKAN-2024', name: 'Bantuan Pendidikan 2024' },
  ]

  const predefinedAmounts = {
    fitrah: [35000, 40000, 45000, 50000],
    maal: [100000, 250000, 500000, 1000000]
  }

  const onSubmit = async (data: DonationFormData) => {
    setIsSubmitting(true)
    
    try {
      const result = await donationApi.create(data)
      setDonationResult(result)
      toast.success('Donasi berhasil dibuat! Silakan lakukan pembayaran.')
      reset()
    } catch (error: any) {
      toast.error(error.message || 'Gagal membuat donasi')
    } finally {
      setIsSubmitting(false)
    }
  }

  if (donationResult) {
    return (
      <div className="card max-w-2xl mx-auto">
        <div className="text-center">
          <div className="w-16 h-16 bg-islamic-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg className="w-8 h-8 text-islamic-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
          </div>
          <h3 className="text-2xl font-bold text-gray-900 mb-2">Donasi Berhasil Dibuat!</h3>
          <p className="text-gray-600 mb-6">ID Donasi: {donationResult.donation.id}</p>
          
          <div className="bg-islamic-gold-50 border border-islamic-gold-200 rounded-lg p-6 mb-6">
            <h4 className="font-semibold text-islamic-gold-800 mb-3">Instruksi Pembayaran (Mock)</h4>
            <p className="text-islamic-gold-700 text-sm">
              Untuk MVP Phase 1, pembayaran akan otomatis tervalidasi dalam 30 detik. 
              Di Phase 3, Anda akan mendapat instruksi pembayaran melalui gateway payment.
            </p>
            <div className="mt-4 text-sm text-islamic-gold-600">
              <p>Jumlah: {formatCurrency(donationResult.donation.amount)}</p>
              <p>Status: {donationResult.donation.blockchain_status}</p>
            </div>
          </div>
          
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <button
              onClick={() => setDonationResult(null)}
              className="btn-primary"
            >
              Donasi Lagi
            </button>
            <button
              onClick={() => {
                navigator.clipboard.writeText(donationResult.donation.id)
                toast.success('ID donasi disalin!')
              }}
              className="btn-outline"
            >
              Salin ID Donasi
            </button>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="card max-w-2xl mx-auto">
      <div className="text-center mb-8">
        <h2 className="text-3xl font-bold text-gray-900 mb-2">Form Donasi Zakat</h2>
        <p className="text-gray-600">
          Salurkan zakat Anda dengan transparansi blockchain technology
        </p>
      </div>

      <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
        {/* Personal Information */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label className="label">Nama Lengkap *</label>
            <input
              type="text"
              className="input-field"
              placeholder="Masukkan nama lengkap"
              {...register('name', { required: 'Nama lengkap wajib diisi' })}
            />
            {errors.name && <p className="error">{errors.name.message}</p>}
          </div>
          
          <div>
            <label className="label">Nomor HP *</label>
            <input
              type="tel"
              className="input-field"
              placeholder="08xxxxxxxxxx"
              {...register('phone', { 
                required: 'Nomor HP wajib diisi',
                pattern: { value: /^08\d{8,11}$/, message: 'Format nomor HP tidak valid' }
              })}
            />
            {errors.phone && <p className="error">{errors.phone.message}</p>}
          </div>
        </div>

        <div>
          <label className="label">Email (Opsional)</label>
          <input
            type="email"
            className="input-field"
            placeholder="email@contoh.com"
            {...register('email', {
              pattern: { value: /^\S+@\S+\.\S+$/, message: 'Format email tidak valid' }
            })}
          />
          {errors.email && <p className="error">{errors.email.message}</p>}
        </div>

        {/* Zakat Type */}
        <div>
          <label className="label">Jenis Zakat *</label>
          <div className="grid grid-cols-2 gap-4">
            <label className="flex items-center space-x-3 cursor-pointer">
              <input
                type="radio"
                value="fitrah"
                className="w-4 h-4 text-islamic-green-600"
                {...register('type', { required: 'Pilih jenis zakat' })}
              />
              <div>
                <span className="font-medium">Zakat Fitrah</span>
                <p className="text-sm text-gray-500">Wajib bagi setiap Muslim</p>
              </div>
            </label>
            <label className="flex items-center space-x-3 cursor-pointer">
              <input
                type="radio"
                value="maal"
                className="w-4 h-4 text-islamic-green-600"
                {...register('type', { required: 'Pilih jenis zakat' })}
              />
              <div>
                <span className="font-medium">Zakat Maal</span>
                <p className="text-sm text-gray-500">Zakat harta/penghasilan</p>
              </div>
            </label>
          </div>
          {errors.type && <p className="error">{errors.type.message}</p>}
        </div>

        {/* Amount Selection */}
        {watchType && (
          <div>
            <label className="label">Nominal Donasi *</label>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 mb-4">
              {predefinedAmounts[watchType].map((amount) => (
                <button
                  key={amount}
                  type="button"
                  onClick={() => {
                    const event = { target: { value: amount.toString() } }
                    register('amount').onChange(event)
                  }}
                  className={`p-3 rounded-lg border-2 text-sm font-medium transition-all duration-200 ${
                    watchAmount === amount
                      ? 'border-islamic-green-500 bg-islamic-green-50 text-islamic-green-700'
                      : 'border-gray-200 hover:border-islamic-green-300'
                  }`}
                >
                  {formatCurrency(amount)}
                </button>
              ))}
            </div>
            <input
              type="number"
              className="input-field"
              placeholder="Atau masukkan nominal lain"
              min="1000"
              {...register('amount', { 
                required: 'Nominal donasi wajib diisi',
                min: { value: 1000, message: 'Minimal donasi Rp 1.000' }
              })}
            />
            {errors.amount && <p className="error">{errors.amount.message}</p>}
          </div>
        )}

        {/* Program Selection */}
        <div>
          <label className="label">Program (Opsional)</label>
          <select className="input-field" {...register('program_id')}>
            <option value="">Pilih program (opsional)</option>
            {programs.map((program) => (
              <option key={program.id} value={program.id}>
                {program.name}
              </option>
            ))}
          </select>
        </div>

        {/* Referral Code */}
        <div>
          <label className="label">Kode Referral (Opsional)</label>
          <input
            type="text"
            className="input-field"
            placeholder="Masukkan kode referral jika ada"
            {...register('referral_code')}
          />
        </div>

        {/* Summary */}
        {watchAmount && (
          <div className="bg-islamic-green-50 border border-islamic-green-200 rounded-lg p-4">
            <h4 className="font-semibold text-islamic-green-800 mb-2">Ringkasan Donasi</h4>
            <div className="text-sm text-islamic-green-700 space-y-1">
              <p>Jenis: {watchType === 'fitrah' ? 'Zakat Fitrah' : 'Zakat Maal'}</p>
              <p>Nominal: {formatCurrency(watchAmount)}</p>
              <p className="font-medium">Total: {formatCurrency(watchAmount)}</p>
            </div>
          </div>
        )}

        {/* Submit Button */}
        <button
          type="submit"
          disabled={isSubmitting}
          className="btn-primary w-full py-4 text-lg"
        >
          {isSubmitting ? (
            <div className="flex items-center justify-center space-x-2">
              <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white"></div>
              <span>Memproses...</span>
            </div>
          ) : (
            '💝 Donasi Sekarang'
          )}
        </button>

        <p className="text-xs text-gray-500 text-center">
          Dengan mendonasi, Anda menyetujui syarat dan ketentuan yang berlaku. 
          Donasi akan diproses menggunakan teknologi blockchain untuk transparansi penuh.
        </p>
      </form>
    </div>
  )
}
