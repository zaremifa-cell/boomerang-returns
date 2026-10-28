import { useEffect, useState } from 'react'
import { api, ApiError, money, REASON_LABEL, STATUS_LABEL, type OrderView, type ReturnDetail } from './api'

type Selection = Record<number, { quantity: number; reason: string }>

export function CustomerPortal() {
  const [orderNumber, setOrderNumber] = useState('NW-1001')
  const [email, setEmail] = useState('maria@example.com')
  const [order, setOrder] = useState<OrderView | null>(null)
  const [selection, setSelection] = useState<Selection>({})
  const [carrier, setCarrier] = useState('dhl')
  const [errors, setErrors] = useState<string[]>([])
  const [busy, setBusy] = useState(false)
  const [result, setResult] = useState<ReturnDetail | null>(null)
  // One key per confirmation attempt: a double click or a retry after a network error reuses it.
  const [idempotencyKey, setIdempotencyKey] = useState(() => crypto.randomUUID())

  async function lookup(e: React.FormEvent) {
    e.preventDefault()
    setBusy(true)
    setErrors([])
    setResult(null)
    try {
      setOrder(await api.lookup(orderNumber, email))
      setSelection({})
      setIdempotencyKey(crypto.randomUUID())
    } catch (err) {
      setOrder(null)
      setErrors(err instanceof ApiError ? err.errors : ['Something went wrong.'])
    } finally {
      setBusy(false)
    }
  }

  async function submit() {
    if (!order) return
    setBusy(true)
    setErrors([])
    try {
      const created = await api.createReturn(
        {
          order_number: orderNumber,
          email,
          carrier,
          items: Object.entries(selection).map(([id, s]) => ({ order_item_id: Number(id), ...s })),
        },
        idempotencyKey,
      )
      setResult(created)
    } catch (err) {
      setErrors(err instanceof ApiError ? err.errors : ['Something went wrong.'])
    } finally {
      setBusy(false)
    }
  }

  if (result) return <ReturnStatus initial={result} onDone={() => { setResult(null); setOrder(null) }} />

  const toggle = (id: number, on: boolean, reason: string) =>
    setSelection((s) => {
      const next = { ...s }
      if (on) next[id] = { quantity: 1, reason }
      else delete next[id]
      return next
    })

  const selectedCount = Object.keys(selection).length
  const refund = order?.items.reduce((sum, i) => sum + (selection[i.id] ? i.price_cents * selection[i.id].quantity : 0), 0) ?? 0

  return (
    <div className="stack">
      <section className="card">
        <h2>Start a return</h2>
        <p className="muted">Enter the order number and email from your confirmation.</p>
        <form className="row" onSubmit={lookup}>
          <label>Order number<input value={orderNumber} onChange={(e) => setOrderNumber(e.target.value)} required /></label>
          <label>Email<input type="email" value={email} onChange={(e) => setEmail(e.target.value)} required /></label>
          <button disabled={busy}>{busy && !order ? 'Finding…' : 'Find order'}</button>
        </form>
        <p className="hint">Demo orders: NW-1001 maria@example.com · NW-1002 tom@example.com (window closed) · NW-1003 lena@example.com (country) · NW-1004 ivan@example.com (not delivered)</p>
      </section>

      {errors.length > 0 && <div className="alert" role="alert">{errors.map((e) => <p key={e}>{e}</p>)}</div>}

      {order && (
        <section className="card">
          <header className="card-head">
            <div>
              <h2>Order {order.number}</h2>
              <p className="muted">{order.retailer} · {order.return_window_days}-day returns</p>
            </div>
          </header>

          {order.order_errors.length > 0 ? (
            <div className="alert">{order.order_errors.map((e) => <p key={e}>{e}</p>)}</div>
          ) : (
            <>
              <ul className="items">
                {order.items.map((item) => {
                  const sel = selection[item.id]
                  const blocked = item.returnable_quantity === 0
                  return (
                    <li key={item.id} className={blocked ? 'item blocked' : 'item'}>
                      <label className="check">
                        <input type="checkbox" disabled={blocked} checked={!!sel}
                          onChange={(e) => toggle(item.id, e.target.checked, order.reasons[0])} />
                        <span>
                          <strong>{item.name}</strong>
                          <span className="muted"> · {money(item.price_cents)}</span>
                          {blocked && <span className="note">{item.blocked_reason}</span>}
                        </span>
                      </label>
                      {sel && (
                        <div className="row compact">
                          <select aria-label="Quantity" value={sel.quantity}
                            onChange={(e) => setSelection({ ...selection, [item.id]: { ...sel, quantity: Number(e.target.value) } })}>
                            {Array.from({ length: item.returnable_quantity }, (_, i) => i + 1).map((n) => <option key={n}>{n}</option>)}
                          </select>
                          <select aria-label="Reason" value={sel.reason}
                            onChange={(e) => setSelection({ ...selection, [item.id]: { ...sel, reason: e.target.value } })}>
                            {order.reasons.map((r) => <option key={r} value={r}>{REASON_LABEL[r] ?? r}</option>)}
                          </select>
                        </div>
                      )}
                    </li>
                  )
                })}
              </ul>

              <div className="row end">
                <label>Drop off with
                  <select value={carrier} onChange={(e) => setCarrier(e.target.value)}>
                    {order.carriers.map((c) => <option key={c} value={c}>{c.replace('_', ' ').toUpperCase()}</option>)}
                  </select>
                </label>
                <span className="muted">Refund {money(refund)}</span>
                <button disabled={busy || selectedCount === 0} onClick={submit}>
                  {busy ? 'Confirming…' : `Return ${selectedCount || ''} item${selectedCount === 1 ? '' : 's'}`}
                </button>
              </div>
            </>
          )}

          {order.returns.length > 0 && (
            <p className="muted small">Earlier returns: {order.returns.map((r) => `${r.id} (${STATUS_LABEL[r.status]})`).join(', ')}</p>
          )}
        </section>
      )}
    </div>
  )
}

function ReturnStatus({ initial, onDone }: { initial: ReturnDetail; onDone: () => void }) {
  const [ret, setRet] = useState(initial)
  const [scanError, setScanError] = useState<string | null>(null)

  // Label creation runs in a background job; poll until it settles.
  useEffect(() => {
    if (ret.status !== 'label_pending') return
    const t = setTimeout(async () => {
      try { setRet(await api.getReturn(ret.id)) } catch { /* keep polling */ }
    }, 1500)
    return () => clearTimeout(t)
  }, [ret])

  async function scan() {
    setScanError(null)
    try { setRet((await api.scan(ret.id)).return) } catch (err) {
      setScanError(err instanceof ApiError ? err.errors.join(' ') : 'Scan failed.')
    }
  }

  const steps = ['label_pending', 'label_created', 'in_transit', 'delivered_to_warehouse', 'refunded'] as const
  const current = steps.indexOf(ret.status as (typeof steps)[number])

  return (
    <section className="card">
      <header className="card-head">
        <div>
          <h2>Return {ret.id}</h2>
          <p className="muted">Order {ret.order_number} · refund {money(ret.refund_cents)}</p>
        </div>
        <span className={`badge ${ret.status}`}>{STATUS_LABEL[ret.status]}</span>
      </header>

      {ret.status === 'label_failed' ? (
        <div className="alert">
          <p>We couldn't get a label from {ret.carrier.toUpperCase()} after {ret.label_attempts} attempts.</p>
          <p className="small">Our team has been notified and will email you a label. ({ret.last_error})</p>
        </div>
      ) : (
        <ol className="steps">
          {steps.map((s, i) => (
            <li key={s} className={i < current ? 'done' : i === current ? 'now' : ''}>{STATUS_LABEL[s]}</li>
          ))}
        </ol>
      )}

      {ret.status === 'label_pending' && (
        <p className="muted">
          Asking {ret.carrier.toUpperCase()} for a label… attempt {Math.max(ret.label_attempts, 1)}
          {ret.last_error && <span className="note"> Last try: {ret.last_error}. Retrying.</span>}
        </p>
      )}
      {ret.tracking_number && (
        <p>Tracking <code>{ret.tracking_number}</code> · <a href={ret.label_url ?? '#'}>Download label</a></p>
      )}

      <ul className="items">
        {ret.items.map((i) => <li key={i.sku} className="item">{i.quantity} × {i.name} <span className="muted">· {REASON_LABEL[i.reason]}</span></li>)}
      </ul>

      {ret.events.length > 0 && (
        <ul className="timeline">
          {ret.events.map((e) => <li key={e.id}><span>{e.status.replace('_', ' ')}</span> <span className="muted">{new Date(e.occurred_at).toLocaleTimeString()}</span></li>)}
        </ul>
      )}

      <div className="row end">
        {(ret.status === 'label_created' || ret.status === 'in_transit') && (
          <button className="ghost" onClick={scan}>Demo: carrier scans parcel</button>
        )}
        <button className="ghost" onClick={onDone}>Done</button>
      </div>
      {scanError && <p className="note">{scanError}</p>}
    </section>
  )
}
