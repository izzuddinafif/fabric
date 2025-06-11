import { useState } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/router'
import { Bars3Icon, XMarkIcon } from '@heroicons/react/24/outline'

export default function Header() {
  const [isMenuOpen, setIsMenuOpen] = useState(false)
  const router = useRouter()

  const navigation = [
    { name: 'Beranda', href: '/' },
    { name: 'Tentang', href: '/about' },
    { name: 'Program', href: '/programs' },
    { name: 'Kontak', href: '/contact' },
  ]

  return (
    <header className="bg-white shadow-sm border-b border-gray-200">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          {/* Logo */}
          <div className="flex items-center">
            <Link href="/" className="flex items-center space-x-3">
              <div className="w-10 h-10 bg-islamic-green-600 rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-lg">Z</span>
              </div>
              <div>
                <h1 className="text-xl font-bold text-gray-900">Zakat Platform</h1>
                <p className="text-xs text-gray-500">YDSF Malang</p>
              </div>
            </Link>
          </div>

          {/* Desktop Navigation */}
          <nav className="hidden md:flex space-x-8">
            {navigation.map((item) => (
              <Link
                key={item.name}
                href={item.href}
                className={`text-sm font-medium transition-colors duration-200 ${
                  router.pathname === item.href
                    ? 'text-islamic-green-600 border-b-2 border-islamic-green-600 pb-1'
                    : 'text-gray-700 hover:text-islamic-green-600'
                }`}
              >
                {item.name}
              </Link>
            ))}
          </nav>

          {/* Admin Login Button */}
          <div className="hidden md:flex items-center space-x-4">
            <Link
              href="/admin/login"
              className="bg-islamic-green-600 hover:bg-islamic-green-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors duration-200"
            >
              Admin Login
            </Link>
          </div>

          {/* Mobile menu button */}
          <div className="md:hidden">
            <button
              onClick={() => setIsMenuOpen(!isMenuOpen)}
              className="text-gray-700 hover:text-islamic-green-600 p-2"
            >
              {isMenuOpen ? (
                <XMarkIcon className="h-6 w-6" />
              ) : (
                <Bars3Icon className="h-6 w-6" />
              )}
            </button>
          </div>
        </div>

        {/* Mobile Navigation */}
        {isMenuOpen && (
          <div className="md:hidden border-t border-gray-200 pt-4 pb-4">
            <nav className="flex flex-col space-y-4">
              {navigation.map((item) => (
                <Link
                  key={item.name}
                  href={item.href}
                  className={`text-sm font-medium transition-colors duration-200 ${
                    router.pathname === item.href
                      ? 'text-islamic-green-600 pl-4 border-l-4 border-islamic-green-600'
                      : 'text-gray-700 hover:text-islamic-green-600 pl-4'
                  }`}
                  onClick={() => setIsMenuOpen(false)}
                >
                  {item.name}
                </Link>
              ))}
              <Link
                href="/admin/login"
                className="bg-islamic-green-600 hover:bg-islamic-green-700 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors duration-200 ml-4 mr-4 text-center"
                onClick={() => setIsMenuOpen(false)}
              >
                Admin Login
              </Link>
            </nav>
          </div>
        )}
      </div>
    </header>
  )
}
