import { useEffect, useState } from 'react'
import { CustomerPortal } from './CustomerPortal'
import { RetailerDashboard } from './RetailerDashboard'

function usePath() {
  const [path, setPath] = useState(window.location.pathname)
  useEffect(() => {
    const onPop = () => setPath(window.location.pathname)
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [])
  const go = (to: string) => {
    window.history.pushState({}, '', to)
    setPath(to)
  }
  return [path, go] as const
}

export default function App() {
  const [path, go] = usePath()
  const retailer = path.startsWith('/retailer')

  return (
    <div className="shell">
      <nav className="nav">
        <span className="brand">Boomerang <span className="muted">returns</span></span>
        <div className="tabs">
          <a href="/" className={!retailer ? 'active' : ''} onClick={(e) => { e.preventDefault(); go('/') }}>Customer portal</a>
          <a href="/retailer" className={retailer ? 'active' : ''} onClick={(e) => { e.preventDefault(); go('/retailer') }}>Retailer dashboard</a>
        </div>
      </nav>
      <main>{retailer ? <RetailerDashboard /> : <CustomerPortal />}</main>
    </div>
  )
}
