export type Status =
  | 'label_pending'
  | 'label_created'
  | 'in_transit'
  | 'delivered_to_warehouse'
  | 'refunded'
  | 'label_failed'
  | 'cancelled'

export interface OrderItem {
  id: number
  sku: string
  name: string
  price_cents: number
  quantity: number
  returnable_quantity: number
  blocked_reason: string | null
}

export interface ReturnSummary {
  id: string
  order_number: string
  email: string
  status: Status
  carrier: string
  tracking_number: string | null
  label_url: string | null
  label_attempts: number
  last_error: string | null
  refund_cents: number
  created_at: string
}

export interface ReturnDetail extends ReturnSummary {
  items: { name: string; sku: string; quantity: number; reason: string }[]
  events: { id: string; status: string; occurred_at: string }[]
}

export interface OrderView {
  number: string
  retailer: string
  delivered_at: string | null
  return_window_days: number
  order_errors: string[]
  carriers: string[]
  reasons: string[]
  items: OrderItem[]
  returns: ReturnSummary[]
}

export interface Stats {
  by_status: Partial<Record<Status, number>>
  by_reason: Record<string, number>
  total: number
}

export class ApiError extends Error {
  errors: string[]
  status: number

  constructor(errors: string[], status: number) {
    super(errors.join(' '))
    this.errors = errors
    this.status = status
  }
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  let response: Response
  try {
    response = await fetch(path, {
      ...init,
      headers: { 'Content-Type': 'application/json', Accept: 'application/json', ...init.headers },
    })
  } catch {
    throw new ApiError(['Network error. Check your connection and try again.'], 0)
  }
  const body = await response.json().catch(() => ({}))
  if (!response.ok) throw new ApiError(body.errors ?? ['Something went wrong.'], response.status)
  return body as T
}

export const api = {
  lookup: (order_number: string, email: string) =>
    request<OrderView>('/api/orders/lookup', { method: 'POST', body: JSON.stringify({ order_number, email }) }),

  createReturn: (
    payload: { order_number: string; email: string; carrier: string; items: { order_item_id: number; quantity: number; reason: string }[] },
    idempotencyKey: string,
  ) =>
    request<ReturnDetail>('/api/returns', {
      method: 'POST',
      body: JSON.stringify(payload),
      headers: { 'Idempotency-Key': idempotencyKey },
    }),

  getReturn: (id: string) => request<ReturnDetail>(`/api/returns/${id}`),

  scan: (id: string) => request<{ outcome: string; return: ReturnDetail }>(`/api/demo/returns/${id}/scan`, { method: 'POST' }),

  retailer: (token: string) => {
    const headers = { Authorization: `Bearer ${token}` }
    return {
      list: (status?: string) =>
        request<ReturnSummary[]>(`/api/retailer/returns${status ? `?status=${status}` : ''}`, { headers }),
      stats: () => request<Stats>('/api/retailer/stats', { headers }),
      refund: (id: string) => request<ReturnSummary>(`/api/retailer/returns/${id}/refund`, { method: 'POST', headers }),
      retryLabel: (id: string) =>
        request<ReturnSummary>(`/api/retailer/returns/${id}/retry_label`, { method: 'POST', headers }),
    }
  },
}

export const money = (cents: number) =>
  new Intl.NumberFormat('en-GB', { style: 'currency', currency: 'EUR' }).format(cents / 100)

export const STATUS_LABEL: Record<Status, string> = {
  label_pending: 'Creating label',
  label_created: 'Label ready',
  in_transit: 'On its way',
  delivered_to_warehouse: 'At warehouse',
  refunded: 'Refunded',
  label_failed: 'Label failed',
  cancelled: 'Cancelled',
}

export const REASON_LABEL: Record<string, string> = {
  too_small: 'Too small',
  too_large: 'Too large',
  not_as_described: 'Not as described',
  damaged: 'Arrived damaged',
  changed_mind: 'Changed my mind',
}
