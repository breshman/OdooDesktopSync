import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'
import { Toaster } from '@/components/ui/sonner'

// Force dark mode
document.documentElement.classList.add('dark')

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
    <Toaster richColors position="bottom-right" />
  </StrictMode>,
)
