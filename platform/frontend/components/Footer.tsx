import Link from 'next/link'

export default function Footer() {
  return (
    <footer className="bg-gray-900 text-white">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
          {/* Logo & Description */}
          <div className="col-span-1 md:col-span-2">
            <div className="flex items-center space-x-3 mb-4">
              <div className="w-10 h-10 bg-islamic-green-600 rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-lg">Z</span>
              </div>
              <div>
                <h3 className="text-xl font-bold">Zakat Platform</h3>
                <p className="text-gray-400 text-sm">YDSF Malang</p>
              </div>
            </div>
            <p className="text-gray-400 mb-4 max-w-md">
              Platform donasi zakat berbasis blockchain untuk transparansi dan akuntabilitas yang terjamin. 
              Setiap donasi tercatat secara permanen dan dapat dilacak secara real-time.
            </p>
            <div className="text-sm text-gray-400">
              <p>Alamat: Jl. Raya Tlogomas No. 246, Malang</p>
              <p>Telepon: (0341) 464-318</p>
              <p>Email: info@ydsfmalang.org</p>
            </div>
          </div>

          {/* Quick Links */}
          <div>
            <h4 className="text-lg font-semibold mb-4">Tautan Cepat</h4>
            <ul className="space-y-2 text-gray-400">
              <li>
                <Link href="/" className="hover:text-white transition-colors duration-200">
                  Beranda
                </Link>
              </li>
              <li>
                <Link href="/about" className="hover:text-white transition-colors duration-200">
                  Tentang Kami
                </Link>
              </li>
              <li>
                <Link href="/programs" className="hover:text-white transition-colors duration-200">
                  Program
                </Link>
              </li>
              <li>
                <Link href="/contact" className="hover:text-white transition-colors duration-200">
                  Kontak
                </Link>
              </li>
            </ul>
          </div>

          {/* Islamic Info */}
          <div>
            <h4 className="text-lg font-semibold mb-4">Informasi Zakat</h4>
            <ul className="space-y-2 text-gray-400">
              <li>
                <a href="#" className="hover:text-white transition-colors duration-200">
                  Panduan Zakat
                </a>
              </li>
              <li>
                <a href="#" className="hover:text-white transition-colors duration-200">
                  Kalkulator Zakat
                </a>
              </li>
              <li>
                <a href="#" className="hover:text-white transition-colors duration-200">
                  Fatwa MUI
                </a>
              </li>
              <li>
                <a href="#" className="hover:text-white transition-colors duration-200">
                  Laporan Keuangan
                </a>
              </li>
            </ul>
          </div>
        </div>

        {/* Bottom Bar */}
        <div className="border-t border-gray-800 mt-8 pt-8 flex flex-col md:flex-row justify-between items-center">
          <div className="text-gray-400 text-sm mb-4 md:mb-0">
            © 2024 YDSF Malang. Semua hak dilindungi.
          </div>
          <div className="flex space-x-6 text-sm text-gray-400">
            <a href="#" className="hover:text-white transition-colors duration-200">
              Kebijakan Privasi
            </a>
            <a href="#" className="hover:text-white transition-colors duration-200">
              Syarat & Ketentuan
            </a>
            <a href="/admin/login" className="hover:text-white transition-colors duration-200">
              Admin
            </a>
          </div>
        </div>
      </div>
    </footer>
  )
}
