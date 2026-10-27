// Supabase Edge Function: standing-booking-notify
// Fired by a trigger on standing_booking_notices, which the hourly
// _process_standing_bookings() run writes at most once per lesson and kind:
//   needs_credit  the weekly lesson is 7 days away and can't be paid for yet
//   released      24h before it was still unpaid, so this week was given up
// The student hears about it in their language; Paulo only hears about
// releases, since a needs_credit usually sorts itself out with a top-up.
//
// Auth: x-webhook-secret (same shared secret as time-request-notify).

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

async function sendMessage(chatId: string | number, text: string) {
  const res = await fetch(`${TELEGRAM_API}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text, parse_mode: 'HTML' })
  });
  if (!res.ok) console.error('Telegram send failed:', res.status, await res.text());
}

// Lesson times are shown in Polish time, labelled as such: the student's own
// zone isn't stored, and an unlabelled time would be ambiguous.
function when(iso: string, locale: string) {
  return new Date(iso).toLocaleString(locale, {
    weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit',
    hour12: false, timeZone: 'Europe/Warsaw'
  });
}

const T: Record<string, any> = {
  es: {
    locale: 'es-ES', tz: 'hora de Polonia',
    needs: (w: string, d: string) =>
      `💳 <b>Tu clase fija necesita un crédito</b>\n\n` +
      `La clase del ${w} se reserva sola, pero ahora mismo no tienes créditos suficientes.\n` +
      `Recarga antes del ${d} o esa semana quedará libre para otros alumnos (tu hora fija sigue siendo tuya las demás semanas).\n\n` +
      `${SITE_URL}/precios.html`,
    released: (w: string) =>
      `📅 <b>Esta semana se ha liberado tu clase fija</b>\n\n` +
      `La clase del ${w} no se pudo reservar por falta de créditos, así que esa semana ha quedado libre.\n` +
      `Tu hora fija sigue siendo tuya las próximas semanas.`
  },
  pl: {
    locale: 'pl-PL', tz: 'czasu polskiego',
    needs: (w: string, d: string) =>
      `💳 <b>Twoja stała lekcja potrzebuje kredytu</b>\n\n` +
      `Twoja lekcja (${w}) rezerwuje się automatycznie, ale nie masz teraz wystarczająco kredytów.\n` +
      `Doładuj konto przed ${d}, inaczej w tym tygodniu termin zostanie zwolniony dla innych (w pozostałe tygodnie Twoja godzina zostaje Twoja).\n\n` +
      `${SITE_URL}/precios.html`,
    released: (w: string) =>
      `📅 <b>W tym tygodniu Twoja stała lekcja została zwolniona</b>\n\n` +
      `Twojej lekcji (${w}) nie udało się zarezerwować z braku kredytów, więc ten termin jest teraz wolny.\n` +
      `W kolejne tygodnie Twoja godzina nadal jest Twoja.`
  },
  en: {
    locale: 'en-GB', tz: 'Polish time',
    needs: (w: string, d: string) =>
      `💳 <b>Your weekly lesson needs a credit</b>\n\n` +
      `The lesson on ${w} books itself, but right now you don't have enough credits.\n` +
      `Top up before ${d}, or that week goes back to other students (your weekly slot stays yours for the other weeks).\n\n` +
      `${SITE_URL}/precios.html`,
    released: (w: string) =>
      `📅 <b>Your weekly lesson was released this week</b>\n\n` +
      `The lesson on ${w} couldn't be booked because there were no credits, so that week is now open to others.\n` +
      `Your weekly slot is still yours for the coming weeks.`
  }
};

Deno.serve(async (req) => {
  if (req.headers.get('x-webhook-secret') !== WEBHOOK_SHARED_SECRET) {
    return new Response('Unauthorized', { status: 401 });
  }
  const { record } = await req.json();
  if (!record?.student_id || !record?.start_time) return new Response('ignored');

  const { data: student } = await sb
    .from('profiles')
    .select('full_name, email, telegram_chat_id, language')
    .eq('id', record.student_id)
    .maybeSingle();

  const lang = student?.language === 'pl' ? 'pl' : (student?.language === 'en' ? 'en' : 'es');
  const tr = T[lang];
  const lesson = `${when(record.start_time, tr.locale)} (${tr.tz})`;
  const deadline = when(new Date(new Date(record.start_time).getTime() - 24 * 3600_000).toISOString(), tr.locale);

  if (student?.telegram_chat_id) {
    await sendMessage(student.telegram_chat_id,
      record.kind === 'released' ? tr.released(lesson) : tr.needs(lesson, `${deadline} (${tr.tz})`));
  }

  if (record.kind === 'released' && ADMIN_TELEGRAM_CHAT_ID) {
    const who = student?.full_name || student?.email || 'Un alumno';
    await sendMessage(ADMIN_TELEGRAM_CHAT_ID,
      `📅 <b>Clase fija liberada por falta de créditos</b>\n` +
      `👤 ${escapeHtml(who)}\n` +
      `🕒 ${when(record.start_time, 'es-ES')}\n\n` +
      `Esa clase vuelve a estar libre para cualquiera.` +
      (student?.telegram_chat_id ? '' : '\n(No tiene Telegram vinculado: no se ha enterado.)'));
  }

  return new Response('ok');
});
