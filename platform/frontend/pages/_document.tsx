import { Html, Head, Main, NextScript } from 'next/document'

export default function Document() {
  return (
    <Html lang="id">
      <Head>
        <meta charSet="UTF-8" />
        <meta name="description" content="Platform donasi zakat berbasis blockchain - YDSF Malang" />
        <meta name="keywords" content="zakat, donasi, blockchain, YDSF, Malang, Islamic" />
        <meta name="author" content="YDSF Malang" />
        <link rel="icon" href="/favicon.ico" />
        
        {/* Islamic font */}
        <link
          href="https://fonts.googleapis.com/css2?family=Amiri:wght@400;700&display=swap"
          rel="stylesheet"
        />
      </Head>
      <body>
        <Main />
        <NextScript />
      </body>
    </Html>
  )
}
