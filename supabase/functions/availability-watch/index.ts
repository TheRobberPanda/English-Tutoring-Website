// Supabase Edge Function: availability-watch
// Runs daily on pg_cron. Tells Paulo on Telegram when his published
// availability looks stale, i.e. he has probably forgotten to add more times:
//   - the last slot he has published is less than HORIZON_DAYS away, or
//   - fewer than MIN_OPEN_SOON bookable slots remain in the next 7 days.
//
// Each alert kind is throttled (admin_alert_state) so a problem that stays
// unfixed produces a reminder every THROTTLE_HOURS, not one per run.
//
// Auth: x-cron-secret, same pattern as lesson-reminders.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CRON_SECRET = Deno.env.get('CRON_SECRET')!;
const TELEGRAM_BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')!;
const ADMIN_TELEGRAM_CHAT_ID = Deno.env.get('ADMIN_TELEGRAM_CHAT_ID');
const TELEGRAM_API = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}`;
const SITE_URL = Deno.env.get('SITE_URL') || 'https://www.inglesconpaulo.org';

const HORIZON_DAYS = 14;
const MIN_OPEN_SOON = 4;
const THROTTLE_HOURS = 48;

const sb = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

// Claim the right to send this alert kind. The conditional upsert-by-update
// means two overlapping runs cannot both send.
async function claim(key: string): Promise<boolean> {
  const cutoff = new Date(Date.now() - THROTTLE_HOURS * 3_600_000).toISOString();
  const now = new Date().toISOString();

  const { data: updated } = await sb
    .from('admin_alert_state')
    .update({ last_sent_at: now })
    .eq('key', key).lt('last_sent_at', cutoff)
    .select('key');
  if (updated && updated.length) return true;

  const { error } = await sb.from('admin_alert_state').insert({ key, last_sent_at: now });
  return !error; // unique violation = row exists and is still inside the window
}

async function clear(key: string) {
  await sb.from('admin_alert_state').delete().eq('key', key);
}

async function send(text: string) {
  const res = await fetch(`${TELEGRAM_API}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: ADMIN_TELEGRAM_CHAT_ID, text, parse_mode: 'HTML' })
  });
  if (!res.ok) console.error('Telegram send failed:', res.status, await res.text());
}

const fmt = (iso: string) => new Date(iso).toLocaleDateString('es-ES', {
  weekday: 'long', day: 'numeric', month: 'long', timeZone: 'Europe/Warsaw'
});

Deno.serve(async (req) => {
  if (req.headers.get('x-cron-secret') !== CRON_SECRET) {
    return new Response('Unauthorized', { status: 401 });
  }
  if (!ADMIN_TELEGRAM_CHAT_ID) return new Response('no admin chat id configured');

  const now = new Date();
  const sent: string[] = [];

  // 1. How far ahead has he published anything?
  const { data: last } = await sb
    .from('schedule_slots').select('start_time')
    .order('start_time', { ascending: false }).limit(1);
  const lastStart = last?.[0]?.start_time as string | undefined;
  const horizonOk = !!lastStart &&
    new Date(lastStart).getTime() >= now.getTime() + HORIZON_DAYS * 86_400_000;

  if (horizonOk) {
    await clear('horizon');
  } else if (await claim('horizon')) {
    await send(
      `📅 <b>Tu calendario se está quedando corto</b>\n` +
      (lastStart && new Date(lastStart) > now
        ? `Tu última clase publicada es el ${fmt(lastStart)}.`
        : `No tienes ninguna clase publicada a futuro.`) +
      `\nLos alumnos solo pueden reservar lo que has publicado: añade más semanas.\n\n` +
      `${SITE_URL}/admin.html`
    );
    sent.push('horizon');
  }

  // 2. Is there actually anything bookable this week?
  const in7 = new Date(now.getTime() + 7 * 86_400_000);
  const { count } = await sb
    .from('schedule_slots')
    .select('id', { count: 'exact', head: true })
    .eq('is_booked', false).eq('is_blocked', false).is('reserved_for', null)
    .gt('start_time', now.toISOString()).lte('start_time', in7.toISOString());

  if ((count ?? 0) >= MIN_OPEN_SOON) {
    await clear('open_soon');
  } else if (await claim('open_soon')) {
    await send(
      `⏳ <b>Casi no quedan clases libres esta semana</b>\n` +
      `Solo ${count ?? 0} hueco${count === 1 ? '' : 's'} reservable${count === 1 ? '' : 's'} en los próximos 7 días. ` +
      `Si no es intencionado, revisa tu horario.\n\n${SITE_URL}/admin.html`
    );
    sent.push('open_soon');
  }

  return new Response(JSON.stringify({ sent, open7: count ?? 0, lastStart }), {
    status: 200, headers: { 'Content-Type': 'application/json' }
  });
});
