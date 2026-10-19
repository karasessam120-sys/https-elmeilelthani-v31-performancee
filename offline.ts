import { useEffect, useState } from 'react';

// طبقة الأوفلاين: كل طلبات Supabase بتعدّي من هنا.
// - القراءة: لو النت فاصل بنرجّع آخر نسخة اتحمّلت قبل كده.
// - الكتابة: لو النت فاصل بتتحفظ في الجهاز وبتتبعت لوحدها لما النت يرجع (بالترتيب).
// - العمليات اللي محتاجة نت (تسجيل الدخول وتغيير اسم المستخدم وكلمة السر) بتفشل برسالة واضحة.

type StoredOp = { id?: number; userId: string; method: string; url: string; headers: Record<string, string>; body: string | null; label: string; created: number };
type FailedOp = { id?: number; label: string; message: string; created: number };
type CacheRow = { key: string; status: number; body: string; contentType: string; contentRange: string; ts: number };
export type OfflineStatus = { online: boolean; pending: number; failed: FailedOp[]; syncing: boolean };

const READ_RPCS = new Set(['get_fares_leaderboard', 'get_leaderboards', 'username_taken']);
const NO_QUEUE_RPCS = new Set(['change_my_username', 'admin_reset_credentials', 'admin_set_password']);
const MAX_CACHE = 400;
const MAX_BODY = 1_500_000;

const nativeFetch: typeof fetch = (...a) => window.fetch(...a);

let dbPromise: Promise<IDBDatabase> | null = null;
const openDb = () => {
  if (!dbPromise) {
    dbPromise = new Promise((resolve, reject) => {
      if (typeof indexedDB === 'undefined') return reject(new Error('no idb'));
      const r = indexedDB.open('elmeil-offline', 1);
      r.onupgradeneeded = () => {
        const db = r.result;
        if (!db.objectStoreNames.contains('queue')) db.createObjectStore('queue', { keyPath: 'id', autoIncrement: true });
        if (!db.objectStoreNames.contains('cache')) db.createObjectStore('cache', { keyPath: 'key' });
        if (!db.objectStoreNames.contains('failed')) db.createObjectStore('failed', { keyPath: 'id', autoIncrement: true });
      };
      r.onsuccess = () => resolve(r.result);
      r.onerror = () => reject(r.error);
    });
  }
  return dbPromise;
};
async function idb<T>(store: string, mode: IDBTransactionMode, fn: (s: IDBObjectStore) => IDBRequest<T>): Promise<T> {
  const db = await openDb();
  return new Promise((resolve, reject) => {
    const rq = fn(db.transaction(store, mode).objectStore(store));
    rq.onsuccess = () => resolve(rq.result);
    rq.onerror = () => reject(rq.error);
  });
}
const safe = async <T,>(p: Promise<T>, fallback: T): Promise<T> => { try { return await p; } catch { return fallback; } };

// ---- الحالة للواجهة
let status: OfflineStatus = { online: typeof navigator === 'undefined' ? true : navigator.onLine, pending: 0, failed: [], syncing: false };
const listeners = new Set<() => void>();
const emit = () => listeners.forEach((l) => l());
const setStatus = (patch: Partial<OfflineStatus>) => { status = { ...status, ...patch }; emit(); };
export const getOfflineStatus = () => status;

async function refreshCounts() {
  const pending = await safe(idb<number>('queue', 'readonly', (s) => s.count()), 0);
  const failed = await safe(idb<FailedOp[]>('failed', 'readonly', (s) => s.getAll()), []);
  setStatus({ pending, failed });
}

export function useOfflineStatus(): OfflineStatus {
  const [s, setS] = useState(status);
  useEffect(() => {
    const l = () => setS(status);
    listeners.add(l);
    l();
    return () => { listeners.delete(l); };
  }, []);
  return s;
}

export const isQueuedResult = (d: unknown) => !!d && typeof d === 'object' && (d as { queued?: boolean }).queued === true;

export async function dismissFailed() {
  await safe(idb('failed', 'readwrite', (s) => s.clear()), undefined);
  await refreshCounts();
}

export async function clearOfflineCache() {
  await safe(idb('cache', 'readwrite', (s) => s.clear()), undefined);
}

// ---- مساعدات
const userIdFromAuth = (auth: string | null) => {
  try {
    const t = (auth || '').replace(/^Bearer\s+/i, '');
    const p = t.split('.')[1];
    if (!p) return 'anon';
    return JSON.parse(atob(p.replace(/-/g, '+').replace(/_/g, '/'))).sub || 'anon';
  } catch { return 'anon'; }
};

const describe = (method: string, url: string) => {
  const u = new URL(url);
  const name = decodeURIComponent(u.pathname.split('/').pop() || '');
  const verb = method === 'POST' ? 'إضافة/تنفيذ' : method === 'PATCH' ? 'تعديل' : method === 'DELETE' ? 'حذف' : method;
  return `${verb}: ${name}`;
};

async function cachePut(key: string, res: Response) {
  try {
    const body = await res.text();
    if (body.length > MAX_BODY) return;
    await idb('cache', 'readwrite', (s) => s.put({ key, status: res.status, body, contentType: res.headers.get('content-type') || 'application/json', contentRange: res.headers.get('content-range') || '', ts: Date.now() } as CacheRow));
    const n = await idb<number>('cache', 'readonly', (s) => s.count());
    if (n > MAX_CACHE) {
      const all = await idb<CacheRow[]>('cache', 'readonly', (s) => s.getAll());
      all.sort((a, b) => a.ts - b.ts).slice(0, n - MAX_CACHE + 40).forEach((r) => { void idb('cache', 'readwrite', (s) => s.delete(r.key)); });
    }
  } catch { /* تجاهل */ }
}

async function cacheGet(key: string): Promise<Response | null> {
  const row = await safe(idb<CacheRow | undefined>('cache', 'readonly', (s) => s.get(key)), undefined);
  if (!row) return null;
  const h: Record<string, string> = { 'Content-Type': row.contentType };
  if (row.contentRange) h['Content-Range'] = row.contentRange;
  return new Response(row.body, { status: row.status, headers: h });
}

function synthetic(method: string, headers: Headers, body: string | null, isRpc: boolean): Response {
  if (isRpc) return new Response(JSON.stringify({ queued: true }), { status: 200, headers: { 'Content-Type': 'application/json' } });
  const prefer = headers.get('prefer') || '';
  const accept = headers.get('accept') || '';
  if (prefer.includes('return=representation')) {
    let parsed: unknown = null;
    try { parsed = body ? JSON.parse(body) : null; } catch { parsed = null; }
    const rows = Array.isArray(parsed) ? parsed : parsed ? [parsed] : [];
    const single = accept.includes('vnd.pgrst.object');
    return new Response(JSON.stringify(single ? rows[0] ?? null : rows), { status: method === 'POST' ? 201 : 200, headers: { 'Content-Type': single ? 'application/vnd.pgrst.object+json' : 'application/json' } });
  }
  return new Response(null, { status: method === 'POST' ? 201 : 204 });
}

export function createOfflineFetch(): typeof fetch {
  return async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
    const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;
    if (!url.includes('/rest/v1/')) return nativeFetch(input, init);

    const method = (init?.method || 'GET').toUpperCase();
    const headers = new Headers(init?.headers as HeadersInit | undefined);
    const body = typeof init?.body === 'string' ? init.body : null;
    const isRpc = url.includes('/rest/v1/rpc/');
    const rpcName = isRpc ? decodeURIComponent(new URL(url).pathname.split('/').pop() || '') : '';
    const isRead = method === 'GET' || method === 'HEAD' || (isRpc && READ_RPCS.has(rpcName));
    const userId = userIdFromAuth(headers.get('authorization'));
    const offlineNow = () => typeof navigator !== 'undefined' && navigator.onLine === false;

    if (isRead) {
      const key = [userId, method, url, headers.get('accept') || '', headers.get('range') || '', body || ''].join('|');
      if (!offlineNow()) {
        try {
          const res = await nativeFetch(input, init);
          if (res.ok) void cachePut(key, res.clone());
          return res;
        } catch (e) {
          const hit = await cacheGet(key);
          if (hit) return hit;
          throw e;
        }
      }
      const hit = await cacheGet(key);
      if (hit) return hit;
      throw new TypeError('Failed to fetch');
    }

    if (isRpc && NO_QUEUE_RPCS.has(rpcName)) return nativeFetch(input, init);

    const queue = async (): Promise<Response> => {
      const keep: Record<string, string> = {};
      headers.forEach((v, k) => { if (k !== 'authorization') keep[k] = v; });
      const op: StoredOp = { userId, method, url, headers: keep, body, label: describe(method, url), created: Date.now() };
      try {
        await idb('queue', 'readwrite', (s) => s.add(op));
      } catch {
        throw new TypeError('Failed to fetch'); // التخزين مش متاح: نرجع الخطأ العادي
      }
      await refreshCounts();
      return synthetic(method, headers, body, isRpc);
    };

    if (offlineNow()) return queue();
    try {
      return await nativeFetch(input, init);
    } catch {
      return queue();
    }
  };
}

// ---- المزامنة
type SessionApi = { getSession: () => Promise<{ data: { session: { user: { id: string }; access_token: string } | null } }>; refreshSession: () => Promise<unknown> };
let sessionApi: SessionApi | null = null;
let flushing = false;

export async function flushQueue() {
  if (flushing || !sessionApi || (typeof navigator !== 'undefined' && !navigator.onLine)) return;
  flushing = true;
  setStatus({ syncing: true });
  try {
    const ops = await safe(idb<StoredOp[]>('queue', 'readonly', (s) => s.getAll()), []);
    if (!ops.length) return;
    let { data } = await sessionApi.getSession();
    if (!data.session) { await sessionApi.refreshSession().catch(() => undefined); data = (await sessionApi.getSession()).data; }
    const session = data.session;
    if (!session) return;
    for (const op of ops) {
      if (op.userId !== session.user.id) continue; // بتاعة حساب تاني: تستنى صاحبها
      let res: Response;
      try {
        res = await nativeFetch(op.url, { method: op.method, headers: { ...op.headers, Authorization: `Bearer ${session.access_token}` }, body: op.body });
      } catch { break; } // لسه مفيش نت
      if (res.status === 401) { await sessionApi.refreshSession().catch(() => undefined); break; }
      if (res.status === 429 || res.status >= 500) break;
      if (!res.ok) {
        let msg = `رفض السيرفر (${res.status})`;
        let code = '';
        try { const j = await res.json(); msg = j.message || msg; code = j.code || ''; } catch { /* تجاهل */ }
        if (!(res.status === 409 && code === '23505')) {
          await safe(idb('failed', 'readwrite', (s) => s.add({ label: op.label, message: msg, created: Date.now() } as FailedOp)), undefined);
        }
      }
      await safe(idb('queue', 'readwrite', (s) => s.delete(op.id as number)), undefined);
      await refreshCounts();
    }
  } finally {
    flushing = false;
    await refreshCounts();
    setStatus({ syncing: false });
  }
}

export function initOfflineSync(api: SessionApi) {
  sessionApi = api;
  void refreshCounts().then(() => flushQueue());
  window.addEventListener('online', () => { setStatus({ online: true }); void flushQueue(); });
  window.addEventListener('offline', () => setStatus({ online: false }));
  window.setInterval(() => { if (status.pending > 0) void flushQueue(); }, 30000);
}
