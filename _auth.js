// تحقق مشترك: خادم أو أدمن مفعّل فقط (ملفات تبدأ بـ _ لا تُعتبر مسارًا)
const SB_URL = 'https://wsfokyryygdejepjvhym.supabase.co';
const SB_KEY = 'sb_publishable_j60iHnmTvv-evZdlERVpIA_DoYnY_Fs';

export async function requireStaff(req, res) {
  try {
    const token = (req.headers.authorization || '').replace('Bearer ', '');
    const headers = { apikey: SB_KEY, Authorization: `Bearer ${token}` };
    const u = await fetch(`${SB_URL}/auth/v1/user`, { headers });
    if (!u.ok) { res.status(401).json({ error: 'سجّل الدخول الأول' }); return false; }
    const authUser = await u.json();
    const r = await fetch(`${SB_URL}/rest/v1/users?id=eq.${authUser.id}&select=role,status`, { headers });
    const rows = await r.json();
    const me = Array.isArray(rows) ? rows[0] : null;
    if (!me || me.status !== 'active' || !['servant', 'admin'].includes(me.role)) {
      res.status(403).json({ error: 'غير مسموح' });
      return false;
    }
    return true;
  } catch {
    res.status(500).json({ error: 'حصل خطأ في السيرفر' });
    return false;
  }
}

// حد يومي لكل خادم (الدالة على السيرفر بتحسب وتقرر)
export async function consumeQuota(req, res, cost = 1) {
  try {
    const token = (req.headers.authorization || '').replace('Bearer ', '');
    const r = await fetch(`${SB_URL}/rest/v1/rpc/consume_ai_quota`, {
      method: 'POST',
      headers: { apikey: SB_KEY, Authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      body: JSON.stringify({ p_cost: cost }),
    });
    const ok = r.ok ? await r.json() : null;
    if (ok === true) return true;
    // لو الدالة لسه ماتشغّلتش على القاعدة (404) منعطّلش الميزة
    if (r.status === 404) return true;
    res.status(429).json({ error: 'وصلت للحد اليومي لاستخدام الذكاء الاصطناعي. جرّب بكرة.' });
    return false;
  } catch {
    return true;
  }
}
