// Supabase Edge Function: lesson-reminders
// Runs on pg_cron every 5 minutes. Sends a Telegram nudge ~20 minutes before
// each booked lesson — to the student (in their language, with the Meet link)
// and to Paulo.
//
// WHY A SENT-FLAG AND NOT JUST A TIME WINDOW:
// A cron that fires every 5 minutes will see the same lesson in several
// consecutive runs, and a window narrow enough to avoid that would silently
// skip lessons whenever a run is late or retried. Instead the window is
// generous (anything starting within the next 20 minutes) and
// schedule_slots.reminder_sent_at makes each lesson claimable exactly once.
//
// Booking requires 12h notice, so a lesson can never be booked after its own
// reminder window has already passed.
//
// Auth: x-cron-secret, same pattern as check-calendar-conflicts.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CRON_SECRET = Deno.env.get('CRON_SECRET')!;
const TELEGRAM_BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')!;
const ADMIN_TELEGRAM_CHAT_ID = Deno.env.get('ADMIN_TELEGRAM_CHAT_ID');
const TELEGRAM_API = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}`;

const LEAD_MINUTES = 20;

const sb = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
);

async function sendMessage(chatId: string | number, text: string) {
  const res = await fetch(`${TELEGRAM_API}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text, parse_mode: 'HTML' })
  });
  if (!res.ok) console.error('Telegram send failed:', res.status, await res.text());
  return res.ok;
}

function timeLabel(startISO: string, lang: string) {
  const locale = lang === 'pl' ? 'pl-PL' : (lang === 'en' ? 'en-GB' : 'es-ES');
  return new Date(startISO).toLocaleTimeString(locale, {
    hour: '2-digit', minute: '2-digit', hour12: false, timeZone: 'Europe/Madrid'
  });
}

const T: Record<string, any> = {
  es: {
    greeting: (n: string) => `¡Hola${n ? ' ' + n : ''}! 👋`,
    title: (m: number) => `⏰ <b>Tu clase empieza en ${m} minutos</b>`,
    at: (t: string) => `🕒 A las ${t}`,
    join: (l: string) => `\n🔗 Entra aquí: ${l}`,
    noLink: '\nEl enlace está en tu cuenta de la web.',
    footer: 'Nos vemos en un momento.'
  },
  pl: {
    greeting: (n: string) => `Cześć${n ? ' ' + n : ''}! 👋`,
    title: (m: number) => `⏰ <b>Twoja lekcja zaczyna się za ${m} minut</b>`,
    at: (t: string) => `🕒 O godzinie ${t}`,
    join: (l: string) => `\n🔗 Dołącz tutaj: ${l}`,
    noLink: '\nLink znajdziesz na swoim koncie na stronie.',
    footer: 'Do zobaczenia za chwilę.'
  },
  en: {
    greeting: (n: string) => `Hi${n ? ' ' + n : ''}! 👋`,
    title: (m: number) => `⏰ <b>Your lesson starts in ${m} minutes</b>`,
    at: (t: string) => `🕒 At ${t}`,
    join: (l: string) => `\n🔗 Join here: ${l}`,
    noLink: '\nThe link is in your account on the site.',
    footer: 'See you shortly.'
  }
};

Deno.serve(async (req) => {
  if (req.headers.get('x-cron-secret') !== CRON_SECRET) {
    return new Response('Unauthorized', { status: 401 });
  }

  const now = new Date();
  const horizon = new Date(now.getTime() + LEAD_MINUTES * 60_000);

  const { data: slots, error } = await sb
    .from('schedule_slots')
    .select('id, start_time, end_time, student_id, google_meet_link')
    .eq('is_booked', true)
    .is('reminder_sent_at', null)
    .gt('start_time', now.toISOString())
    .lte('start_time', horizon.toISOString())
    .order('start_time');

  if (error) {
    console.error('lesson-reminders query failed:', error);
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }
  if (!slots || slots.length === 0) {
    return new Response(JSON.stringify({ reminded: 0 }), {
      status: 200, headers: { 'Content-Type': 'application/json' }
    });
  }

  let reminded = 0;

  for (const slot of slots) {
    // Claim the slot before sending. If this update matches nothing, another
    // overlapping run already took it, so we must not send a second time.
    const { data: claimed, error: claimErr } = await sb
      .from('schedule_slots')
      .update({ reminder_sent_at: new Date().toISOString() })
      .eq('id', slot.id)
      .is('reminder_sent_at', null)
      .select('id');

    if (claimErr) { console.error('claim failed:', claimErr); continue; }
    if (!claimed || claimed.length === 0) continue;

    const { data: student } = await sb
      .from('profiles')
      .select('full_name, email, telegram_chat_id, telegram_first_name, language')
      .eq('id', slot.student_id)
      .maybeSingle();

    const lang = student?.language === 'pl' ? 'pl' : (student?.language === 'en' ? 'en' : 'es');
    const tr = T[lang];
    const minutesLeft = Math.max(1, Math.round((new Date(slot.start_time).getTime() - Date.now()) / 60_000));
    const firstName = student?.full_name?.trim().split(/\s+/)[0] || student?.telegram_first_name || '';
    const linkLine = slot.google_meet_link ? tr.join(slot.google_meet_link) : tr.noLink;

    if (student?.telegram_chat_id) {
      await sendMessage(student.telegram_chat_id,
        `${tr.greeting(firstName)}\n\n` +
        `${tr.title(minutesLeft)}\n` +
        `${tr.at(timeLabel(slot.start_time, lang))}${linkLine}\n\n` +
        tr.footer);
    } else {
      console.log(`Student ${slot.student_id} has no Telegram linked — skipped.`);
    }

    if (ADMIN_TELEGRAM_CHAT_ID) {
      const who = student?.full_name || student?.telegram_first_name || student?.email || 'Alumno/a';
      await sendMessage(ADMIN_TELEGRAM_CHAT_ID,
        `Hola Paulo 👋\n\n` +
        `⏰ <b>Clase en ${minutesLeft} minutos</b>\n` +
        `👤 ${who}\n` +
        `🕒 A las ${timeLabel(slot.start_time, 'es')}` +
        (slot.google_meet_link ? `\n🔗 ${slot.google_meet_link}` : '\nSin enlace de Meet todavía.'));
    }

    reminded++;
  }

  console.log(`lesson-reminders: ${reminded} reminder(s) sent.`);
  return new Response(JSON.stringify({ reminded }), {
    status: 200, headers: { 'Content-Type': 'application/json' }
  });
});
