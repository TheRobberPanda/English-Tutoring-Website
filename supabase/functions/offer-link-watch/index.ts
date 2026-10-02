// Supabase Edge Function: offer-link-watch
// Keeps an eye on the welcome-offer link (first 3 credits for 30€), which is a
// Wise payment request. Those are SINGLE_USE and expire, so Paulo has to paste
// a new one into admin whenever the current one is spent. This tells him when.
//
// Runs hourly from pg_cron (x-cron-secret), and on demand from admin.html
// right after a new link is pasted (admin's JWT), so the expiry and reference
// show up immediately.
//
// For the live link it reads the Wise page's embedded JSON (__NEXT_DATA__):
//   - requestDetails present  -> store amount, reference and expiry;
//   - requestDetails missing  -> Wise no longer offers it (paid or expired):
//                                close it and ping Paulo;
//   - expiring within 3 days  -> ping Paulo once.
// A link used by an imported payment is already 'used' (wise-payments pinged
// Paulo then), so it is not checked again.
//
// A fetch that fails, or a page without __NEXT_DATA__, changes nothing: a Wise
// outage or redesign must not take the offer down.
//
// Required secrets: CRON_SECRET, TELEGRAM_BOT_TOKEN, ADMIN_TELEGRAM_CHAT_ID

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CRON_SECRET = Deno.env.get('CRON_SECRET')!;
const TELEGRAM_BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')!;
const ADMIN_TELEGRAM_CHAT_ID = Deno.env.get('ADMIN_TELEGRAM_CHAT_ID');
const ADMIN_URL = 'https://www.inglesconpaulo.org/admin.html';
const WARN_BEFORE_MS = 3 * 24 * 60 * 60 * 1000;

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};

const sb = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });
}

async function notifyPaulo(text: string) {
  if (!ADMIN_TELEGRAM_CHAT_ID) return;
  const res = await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: ADMIN_TELEGRAM_CHAT_ID, text, parse_mode: 'HTML', disable_web_page_preview: true })
  });
  if (!res.ok) console.error('Telegram send failed:', res.status, await res.text());
}

async function callerIsAdmin(req: Request): Promise<boolean> {
  const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) return false;
  const { data } = await sb.auth.getUser(token);
  if (!data?.user) return false;
  const { data: p } = await sb.from('profiles').select('is_admin').eq('id', data.user.id).single();
  return !!p?.is_admin;
}

type Details = { amount: number; currency: string; reference: string | null; expiresAt: string | null };

// null = Wise no longer offers this request; undefined = couldn't tell.
async function readWiseRequest(url: string): Promise<Details | null | undefined> {
  let res: Response;
  try {
    res = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0 (inglesconpaulo.org offer-link-watch)' } });
  } catch (e) {
    console.error('Wise fetch failed:', e);
    return undefined;
  }
  if (res.status === 404 || res.status === 410) return null;
  if (!res.ok) { console.error('Wise page status', res.status); return undefined; }

  const html = await res.text();
  const m = html.match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);
  if (!m) { console.error('No __NEXT_DATA__ on the Wise page'); return undefined; }
  let data: any;
  try { data = JSON.parse(m[1]); } catch { return undefined; }

  const page = data?.props?.pageProps ?? data?.props;
  const d = page?.data?.response?.requestDetails;
  if (!d) return null;
  const status = String(d.status ?? '');
  if (/PAID|COMPLETE|CLOSED|EXPIRED|CANCEL|INACTIVE/i.test(status)) return null;
  if (d.expiryAt && new Date(d.expiryAt).getTime() <= Date.now()) return null;
  return {
    amount: Number(d.amount?.value),
    currency: String(d.amount?.currency ?? ''),
    reference: d.reference ?? null,
    expiresAt: d.expiryAt ?? null
  };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });

  const fromCron = req.headers.get('x-cron-secret') === CRON_SECRET;
  if (!fromCron && !(await callerIsAdmin(req))) return json({ error: 'Unauthorized' }, 401);

  const { data: link, error } = await sb.from('offer_links').select('*').eq('status', 'active').maybeSingle();
  if (error) return json({ error: error.message }, 500);
  if (!link) return json({ link: null });

  const details = await readWiseRequest(link.url);
  const now = new Date().toISOString();

  if (details === undefined) {
    return json({ link: link.url, checked: false });
  }

  if (details === null) {
    await sb.from('offer_links').update({ status: 'closed', closed_at: now, checked_at: now }).eq('id', link.id);
    await notifyPaulo(
      `🔗 <b>El enlace de la oferta (3 clases) ya no está activo</b>\n` +
      `Wise ya no lo muestra: se ha pagado o ha caducado.\n\n` +
      `1. Crea una nueva solicitud de pago en Wise: ${link.amount_eur}€, un solo uso.\n` +
      `2. Pégala en ${ADMIN_URL} → Alumnos → Enlace de la oferta.\n\n` +
      `Si alguien lo ha pagado, el pago aparecerá en admin → Pagos de Wise.`);
    return json({ link: link.url, closed: true });
  }

  const update: Record<string, unknown> = { checked_at: now, expires_at: details.expiresAt, wise_reference: details.reference };
  if (details.currency === 'EUR' && details.amount > 0) update.amount_eur = details.amount;
  await sb.from('offer_links').update(update).eq('id', link.id);

  if (details.currency !== 'EUR') {
    await notifyPaulo(`⚠️ El enlace de la oferta pide ${details.amount} ${details.currency}, no euros. Los pagos solo se acreditan solos en EUR: crea uno en euros.`);
  }

  let warned = false;
  if (details.expiresAt && !link.expiry_warned_at
      && new Date(details.expiresAt).getTime() - Date.now() < WARN_BEFORE_MS) {
    const when = new Date(details.expiresAt).toLocaleString('es-ES', {
      timeZone: 'Europe/Warsaw', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit'
    });
    await notifyPaulo(
      `⏳ <b>El enlace de la oferta (3 clases) caduca el ${when}</b>\n` +
      `Crea una nueva solicitud de pago en Wise (${update.amount_eur ?? link.amount_eur}€, un solo uso) y pégala en ${ADMIN_URL} → Alumnos → Enlace de la oferta.`);
    await sb.from('offer_links').update({ expiry_warned_at: now }).eq('id', link.id);
    warned = true;
  }

  return json({ link: link.url, ...details, warned });
});
