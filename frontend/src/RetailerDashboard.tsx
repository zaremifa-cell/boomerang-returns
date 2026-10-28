import { useCallback, useEffect, useState } from 'react'
import { api, ApiError, money, REASON_LABEL, STATUS_LABEL, type ReturnSummary, type Stats, type Status } from './api'

const FILTERS: (Status | '')[] = ['', 'label_pending', 'label_created', 'in_transit', 'delivered_to_warehouse', 'refunded', 'label_failed']

export function RetailerDashboard() {
  const [token] = useState('demo-retailer-token')
  const [filter, setFilter] = useState<Status | ''>('')
  const [rows, setRows] = useState<ReturnSummary[]>([])
  const [stats, setStats] = useState<Stats | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  const load = useCallback(async () => {
    const client = api.retailer(token)
    try {
      const [list, s] = await Promise.all([client.list(filter || undefined), client.stats()])
      setRows(list)
      setStats(s)
      setError(null)
    } catch (err) {
      setError(err instanceof ApiError ? err.errors.join(' ') : 'Could not load returns.')
    } finally {
      setLoading(false)
    }
  }, [token, filter])

  useEffect(() => {
    load()
    const t = setInterval(load, 4000)
    return () => clearInterval(t)
  }, [load])

  async function act(fn: () => Promise<unknown>) {
    try { await fn(); await load() } catch (err) {
      setError(err instanceof ApiError ? err.errors.join(' ') : 'Action failed.')
    }
  }

  const reasonTotal = stats ? Object.values(stats.by_reason).reduce((a, b) => a + b, 0) : 0

  return (
    <div className="stack">
      <section className="tiles">
        <Tile label="All returns" value={stats?.total ?? 0} />
        <Tile label="Waiting for label" value={stats?.by_status.label_pending ?? 0} />
        <Tile label="At warehouse" value={stats?.by_status.delivered_to_warehouse ?? 0} />
        <Tile label="Label failed" value={stats?.by_status.label_failed ?? 0} alert />
      </section>

      {stats && reasonTotal > 0 && (
        <section className="card">
          <h2>Why customers return</h2>
          <ul className="bars">
            {Object.entries(stats.by_reason).sort((a, b) => b[1] - a[1]).map(([reason, n]) => (
              <li key={reason}>
                <span>{REASON_LABEL[reason] ?? reason}</span>
                <span className="bar"><span style={{ width: `${(n / reasonTotal) * 100}%` }} /></span>
                <span className="muted">{n}</span>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="card">
        <header className="card-head">
          <h2>Returns</h2>
          <select value={filter} onChange={(e) => setFilter(e.target.value as Status | '')} aria-label="Filter by status">
            {FILTERS.map((f) => <option key={f} value={f}>{f ? STATUS_LABEL[f] : 'All statuses'}</option>)}
          </select>
        </header>
        {error && <div className="alert" role="alert"><p>{error}</p></div>}
        {loading ? <p className="muted">Loading…</p> : rows.length === 0 ? (
          <p className="muted">No returns yet. Create one in the customer portal.</p>
        ) : (
          <div className="table-wrap">
            <table>
              <thead><tr><th>Return</th><th>Order</th><th>Status</th><th>Carrier</th><th>Refund</th><th /></tr></thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id}>
                    <td><code>{r.id}</code></td>
                    <td>{r.order_number}<div className="muted small">{r.email}</div></td>
                    <td>
                      <span className={`badge ${r.status}`}>{STATUS_LABEL[r.status]}</span>
                      {r.last_error && <div className="note small">{r.last_error} · {r.label_attempts} attempts</div>}
                    </td>
                    <td>{r.carrier.toUpperCase()}<div className="muted small">{r.tracking_number ?? '—'}</div></td>
                    <td>{money(r.refund_cents)}</td>
                    <td className="actions">
                      {r.status === 'delivered_to_warehouse' && <button onClick={() => act(() => api.retailer(token).refund(r.id))}>Refund</button>}
                      {r.status === 'label_failed' && <button className="ghost" onClick={() => act(() => api.retailer(token).retryLabel(r.id))}>Retry label</button>}
                      {(r.status === 'label_created' || r.status === 'in_transit') && (
                        <button className="ghost" onClick={() => act(() => api.scan(r.id))}>Demo scan</button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  )
}

function Tile({ label, value, alert }: { label: string; value: number; alert?: boolean }) {
  return (
    <div className={`tile ${alert && value > 0 ? 'tile-alert' : ''}`}>
      <span className="muted small">{label}</span>
      <strong>{value}</strong>
    </div>
  )
}
