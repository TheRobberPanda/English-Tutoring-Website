// Supabase Edge Function: time-request-notify
// Fired by a trigger on time_requests when a student taps "request more times".
// Pings Paulo on Telegram with who asked, their time zone, and how much open
// availability he currently has, so he can tell at a glance whether the
// request is "add more" or "this student's zone just doesn't fit".
//
// Auth: x-webhook-secret (same shared secret as chat-notify / booking-notifications).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const WEBHOOK_SHARED_SECRET = Deno.env.get('WEBHOOK_SHARED_SECRET')!;
const TELEGRAM_BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')!;
const ADMIN_TELEGRAM_CHAT_ID = Deno.env.get('ADMIN_TELEGRAM_CHAT_ID');
const TELEGRAM_API = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}`;
const SITE_URL = Deno.env.get('SITE_URL') || 'https://www.inglesconpaulo.org';

const sb = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

function escapeHtml(s: string) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

Deno.serve(async (req) => {
  if (req.headers.get('x-webhook-secret') !== WEBHOOK_SHARED_SECRET) {
    return new Response('Unauthorized', { status: 401 });
  }
  if (!ADMIN_TELEGRAM_CHAT_ID) return new Response('no admin chat id configured');

  const { record } = await req.json();
  if (!record?.student_id) return new Response('ignored');

  const { data: student } = await sb
    .from('profiles')
    .select('full_name, email')
    .eq('id', record.student_id)
    .maybeSingle();
  const who = student?.full_name || student?.email || 'Un alumno';

  const now = new Date();
  const in14 = new Date(now.getTime() + 14 * 86_400_000);
  const { count: open } = await sb
    .from('schedule_slots')
    .select('id', { count: 'exact', head: true })
    .eq('is_booked', false).eq('is_blocked', false).is('reserved_for', null)
    .gt('start_time', now.toISOString())
    .lte('start_time', in14.toISOString());

  // The student's current local time makes a far-away zone obvious at a glance.
  let local = '';
  if (record.timezone) {
    try {
      local = new Date().toLocaleTimeString('es-ES', {
        hour: '2-digit', minute: '2-digit', timeZone: record.timezone
      });
    } catch { /* unknown zone name: skip the local-time line */ }
  }

  const text =
    `🌍 <b>Un alumno pide otros horarios</b>\n` +
    `👤 ${escapeHtml(who)}\n` +
    (record.timezone
      ? `🕒 Zona horaria: ${escapeHtml(record.timezone)}${local ? ` (ahora allí son las ${local})` : ''}\n`
      : '') +
    `📅 Clases libres en los próximos 14 días: ${open ?? 0}\n\n` +
    `Añade horas en ${SITE_URL}/admin.html y responde por el chat.`;

  const res = await fetch(`${TELEGRAM_API}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: ADMIN_TELEGRAM_CHAT_ID, text, parse_mode: 'HTML' })
  });
  if (!res.ok) console.error('Telegram send failed:', res.status, await res.text());
  return new Response('ok');
});
