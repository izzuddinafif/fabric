import { useState } from 'react'
import Head from 'next/head'
import Layout from '@/components/Layout'
import DonationForm from '@/components/DonationForm'
import DonationTracker from '@/components/DonationTracker'
import { MosqueIcon, HeartIcon, ShieldCheckIcon, GlobeAltIcon } from '@heroicons/react/24/outline'

export default function Home() {
  const [activeTab, setActiveTab] = useState<'donate' | 'track'>('donate')

  return (
    <>
      <Head>
        <title>Zakat Platform - YDSF Malang</title>
        <meta name="description" content="Platform donasi zakat berbasis blockchain untuk transparansi dan akuntabilitas yang terjamin" />
      </Head>

      <Layout>
        {/* Hero Section */}
        <section className="relative bg-gradient-to-br from-islamic-green-600 to-islamic-green-800 text-white overflow-hidden">
          <div className="absolute inset-0 islamic-pattern"></div>
          <div className="relative max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
            <div className="text-center">
              <h1 className="text-4xl md:text-6xl font-bold mb-6">
                <span className="block">بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيم</span>
                <span className="block text-2xl md:text-3xl mt-4 font-normal">
                  Platform Zakat Berbasis Blockchain
                </span>
              </h1>
              <p className="text-xl md:text-2xl mb-8 text-islamic-green-100 max-w-3xl mx-auto">
                Salurkan zakat Anda dengan transparansi penuh melalui teknologi blockchain. 
                Setiap donasi tercatat secara permanen dan dapat dilacak secara real-time.
              </p>
              <div className="flex flex-col sm:flex-row gap-4 justify-center">
                <button
                  onClick={() => setActiveTab('donate')}
                  className={`px-8 py-4 rounded-lg font-semibold text-lg transition-all duration-200 ${
                    activeTab === 'donate'
                      ? 'bg-white text-islamic-green-700 shadow-lg'
                      : 'bg-islamic-green-700/50 hover:bg-islamic-green-700 text-white'
                  }`}
                >
                  💝 Donasi Sekarang
                </button>
                <button
                  onClick={() => setActiveTab('track')}
                  className={`px-8 py-4 rounded-lg font-semibold text-lg transition-all duration-200 ${
                    activeTab === 'track'
                      ? 'bg-white text-islamic-green-700 shadow-lg'
                      : 'bg-islamic-green-700/50 hover:bg-islamic-green-700 text-white'
                  }`}
                >
                  🔍 Lacak Donasi
                </button>
              </div>
            </div>
          </div>
        </section>

        {/* Features Section */}
        <section className="py-16 bg-white">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="text-center mb-12">
              <h2 className="text-3xl font-bold text-gray-900 mb-4">
                Mengapa Memilih Platform Kami?
              </h2>
              <p className="text-lg text-gray-600 max-w-2xl mx-auto">
                Teknologi blockchain memastikan transparansi dan akuntabilitas dalam penyaluran zakat
              </p>
            </div>
            
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8">
              <div className="text-center">
                <div className="bg-islamic-green-100 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
                  <ShieldCheckIcon className="h-8 w-8 text-islamic-green-600" />
                </div>
                <h3 className="text-xl font-semibold mb-2">Transparansi Penuh</h3>
                <p className="text-gray-600">
                  Setiap transaksi tercatat di blockchain dan dapat dilacak oleh siapa saja
                </p>
              </div>
              
              <div className="text-center">
                <div className="bg-islamic-gold-100 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
                  <MosqueIcon className="h-8 w-8 text-islamic-gold-600" />
                </div>
                <h3 className="text-xl font-semibold mb-2">Sesuai Syariah</h3>
                <p className="text-gray-600">
                  Diawasi oleh dewan syariah dan mengikuti kaidah-kaidah zakat yang benar
                </p>
              </div>
              
              <div className="text-center">
                <div className="bg-islamic-green-100 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
                  <HeartIcon className="h-8 w-8 text-islamic-green-600" />
                </div>
                <h3 className="text-xl font-semibold mb-2">Mudah & Aman</h3>
                <p className="text-gray-600">
                  Proses donasi yang simpel dengan keamanan tingkat enterprise
                </p>
              </div>
              
              <div className="text-center">
                <div className="bg-islamic-gold-100 w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4">
                  <GlobeAltIcon className="h-8 w-8 text-islamic-gold-600" />
                </div>
                <h3 className="text-xl font-semibold mb-2">Real-time Tracking</h3>
                <p className="text-gray-600">
                  Lacak status donasi Anda secara real-time dari penerimaan hingga penyaluran
                </p>
              </div>
            </div>
          </div>
        </section>

        {/* Main Content */}
        <section className="py-16 bg-gray-50">
          <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
            {activeTab === 'donate' ? (
              <DonationForm />
            ) : (
              <DonationTracker />
            )}
          </div>
        </section>

        {/* Stats Section */}
        <section className="py-16 bg-islamic-green-600 text-white">
          <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
            <div className="grid grid-cols-1 md:grid-cols-3 gap-8 text-center">
              <div>
                <div className="text-4xl font-bold mb-2">Rp 25.000.000</div>
                <div className="text-islamic-green-100">Total Terkumpul</div>
              </div>
              <div>
                <div className="text-4xl font-bold mb-2">150+</div>
                <div className="text-islamic-green-100">Donatur</div>
              </div>
              <div>
                <div className="text-4xl font-bold mb-2">100%</div>
                <div className="text-islamic-green-100">Transparansi</div>
              </div>
            </div>
          </div>
        </section>
      </Layout>
    </>
  )
}
