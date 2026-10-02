// Supabase Edge Function: wise-payments
// Runs on pg_cron every 10 minutes. Turns Wise "you received money" emails into
// credits, at each student's own price (profiles.price_per_credit).
//
// WHY EMAIL AND NOT THE WISE API:
// Paulo's Wise account is personal, and Wise gives EU personal accounts no API
// or webhook access (PSD2). The notification email is the only machine-readable
// signal, so this reads it from Gmail.
//
// TRUST: anyone can send an email that *claims* to be from wise.com. Only
// messages Gmail has DKIM-verified as signed by wise.com are considered.
//
// MATCHING, in order:
//   1. the sender's name (as Wise shows it) equal to exactly one student's
//      full_name, ignoring case and accents;
//   2. otherwise the student's code (referral_code) found in the email, for
//      students whose Wise name differs from their account name.
// Anything else is stored as 'unmatched' and Paulo assigns it in admin.
//
// On a match the student gets a thank-you email, sent from Paulo's own Gmail
// (same token, gmail.send scope) so it arrives as a normal personal email.
//
// IDEMPOTENCY: payments.gmail_message_id is unique, so re-reading the same
// email on the next run is a no-op.
//
// Required secrets:
//   CRON_SECRET
//   GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET
//   GMAIL_REFRESH_TOKEN  - token with gmail.readonly + gmail.send scopes (separate from the
//                          Calendar token so minting it can't break Calendar)
//   TELEGRAM_BOT_TOKEN, ADMIN_TELEGRAM_CHAT_ID

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const CRON_SECRET = Deno.env.get('CRON_SECRET')!;
const GOOGLE_CLIENT_ID = Deno.env.get('GOOGLE_CLIENT_ID')!;
const GOOGLE_CLIENT_SECRET = Deno.env.get('GOOGLE_CLIENT_SECRET')!;
const GMAIL_REFRESH_TOKEN = Deno.env.get('GMAIL_REFRESH_TOKEN');
const TELEGRAM_BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN')!;
const ADMIN_TELEGRAM_CHAT_ID = Deno.env.get('ADMIN_TELEGRAM_CHAT_ID');
const TELEGRAM_API = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}`;

const GMAIL_QUERY = 'from:wise.com newer_than:7d';

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
}

function esc(s: string) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

async function getGmailAccessToken(): Promise<string> {
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: GOOGLE_CLIENT_ID,
      client_secret: GOOGLE_CLIENT_SECRET,
      refresh_token: GMAIL_REFRESH_TOKEN!,
      grant_type: 'refresh_token'
    })
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error_description || 'Gmail token refresh failed');
  return data.access_token;
}

async function gmail(token: string, path: string) {
  const res = await fetch(`https://gmail.googleapis.com/gmail/v1/users/me/${path}`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error?.message || `Gmail ${path} failed`);
  return data;
}

function b64url(s: string) {
  const bin = atob(s.replace(/-/g, '+').replace(/_/g, '/'));
  return new TextDecoder().decode(Uint8Array.from(bin, c => c.charCodeAt(0)));
}

// Flatten a MIME tree into plain text (HTML stripped as a fallback).
function bodyText(part: any): string {
  if (!part) return '';
  if (part.parts) return part.parts.map(bodyText).join('\n');
  if (!part.body?.data) return '';
  const raw = b64url(part.body.data);
  if (part.mimeType === 'text/html') {
    return raw.replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<br\s*\/?>|<\/(p|div|tr|td|h\d)>/gi, '\n')
      .replace(/<[^>]+>/g, ' ')
      .replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&').replace(/&euro;/g, '€');
  }
  return raw;
}

function header(msg: any, name: string): string {
  return msg.payload?.headers?.find((h: any) => h.name.toLowerCase() === name.toLowerCase())?.value || '';
}

// "1,234.56" / "1.234,56" / "45,00" / "45" -> number
function parseAmount(s: string): number | null {
  let t = s.replace(/[\s ]/g, '');
  const lastSep = Math.max(t.lastIndexOf(','), t.lastIndexOf('.'));
  if (lastSep !== -1 && t.length - lastSep - 1 === 2) {
    t = t.slice(0, lastSep).replace(/[.,]/g, '') + '.' + t.slice(lastSep + 1);
  } else {
    t = t.replace(/[.,]/g, '');
  }
  const n = Number(t);
  return Number.isFinite(n) && n > 0 ? n : null;
}

const INCOMING = /receiv|recib|otrzyma|sent you|te ha enviado|te envió|przesłał|wysłał\(a\)? ci|wysłał ci/i;
const OUTGOING = /you sent|you've sent|has enviado|enviaste|wysłałeś|wysłałaś|your transfer|tu transferencia|twój przelew/i;

function parseWiseEmail(subject: string, text: string) {
  if (!INCOMING.test(subject) || OUTGOING.test(subject)) return null;

  const hay = `${subject}\n${text}`;
  const m = hay.match(/(?:€\s?([\d.,\s ]+\d)|([\d.,\s ]*\d)\s?(?:EUR|€))/);
  if (!m) return null;
  const amount = parseAmount(m[1] || m[2]);
  if (!amount) return null;
  // Other currencies are not auto-credited.
  if (/\b(PLN|USD|GBP)\b/.test(subject)) return null;

  // Take the first "from/de/od" after the amount, so "María de la Cruz" survives.
  const sender = (subject.match(/^(.+?)\s+(?:has sent you|sent you|te ha enviado|te envió|przesłał|wysłał)/i)
    || subject.match(/(?:EUR|€)[^\n]*?\b(?:from|de|od)\s+(.+?)\s*$/i)
    || subject.match(/\b(?:from|de|od)\s+(.+?)\s*$/i))?.[1]?.trim() || null;
  const reference = text.match(/(?:reference|referencia|tytuł|tytul)[^\n:]*[:\n]\s*([^\n]{1,80})/i)?.[1]?.trim() || null;
  return { amount, sender, reference };
}

function norm(s: string) {
  return s.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase().replace(/\s+/g, ' ').trim();
}

const T: Record<string, (credits: string, amount: string) => string> = {
  es: (c, a) => `💶 <b>Pago recibido</b>\nHemos recibido ${a}€ por Wise y se han añadido <b>${c}</b> créditos a tu cuenta. ¡Gracias!`,
  pl: (c, a) => `💶 <b>Płatność otrzymana</b>\nOtrzymaliśmy ${a}€ przez Wise i do Twojego konta dodano <b>${c}</b> kredytów. Dziękuję!`,
  en: (c, a) => `💶 <b>Payment received</b>\nWe received €${a} via Wise and added <b>${c}</b> credits to your account. Thank you!`
};

const MAIL: Record<string, (name: string, credits: string, amount: string) => { subject: string; body: string }> = {
  es: (n, c, a) => ({
    subject: '¡Gracias por tu compra! 🎉',
    body: `¡Hola${n ? ' ' + n : ''}!\n\n` +
      `¡Enhorabuena por tu compra! He recibido tu pago de ${a}€ por Wise y ya tienes ${c} ${c === '1' ? 'clase añadida' : 'clases añadidas'} en tu cuenta.\n\n` +
      `Puedes reservar cuando quieras en https://www.inglesconpaulo.org/cuenta.html\n\n` +
      `¡Nos vemos en clase!\nPaulo`
  }),
  pl: (n, c, a) => ({
    subject: 'Dziękuję za zakup! 🎉',
    body: `Cześć${n ? ' ' + n : ''}!\n\n` +
      `Gratuluję zakupu! Otrzymałem Twoją płatność ${a}€ przez Wise i dodałem lekcje do Twojego konta (liczba lekcji: ${c}).\n\n` +
      `Możesz zarezerwować termin kiedy chcesz na https://www.inglesconpaulo.org/cuenta.html\n\n` +
      `Do zobaczenia na lekcji!\nPaulo`
  }),
  en: (n, c, a) => ({
    subject: 'Thank you for your purchase! 🎉',
    body: `Hi${n ? ' ' + n : ''}!\n\n` +
      `Congratulations on your purchase! I've received your payment of €${a} via Wise, and ${c} ${c === '1' ? 'lesson has' : 'lessons have'} been added to your account.\n\n` +
      `You can book whenever you like at https://www.inglesconpaulo.org/cuenta.html\n\n` +
      `See you in class!\nPaulo`
  })
};

function b64urlEncode(s: string) {
  const bytes = new TextEncoder().encode(s);
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function sendEmail(token: string, to: string, subject: string, body: string) {
  // Header values must stay ASCII: the subject is RFC 2047 encoded.
  const encodedSubject = `=?UTF-8?B?${btoa(String.fromCharCode(...new TextEncoder().encode(subject)))}?=`;
  const mime = [
    `To: ${to.replace(/[\r\n]/g, '')}`,
    `Subject: ${encodedSubject}`,
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=UTF-8',
    'Content-Transfer-Encoding: 8bit',
    '',
    body
  ].join('\r\n');
  const res = await fetch('https://gmail.googleapis.com/gmail/v1/users/me/messages/send', {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ raw: b64urlEncode(mime) })
  });
  if (!res.ok) throw new Error(`Gmail send failed: ${res.status} ${await res.text()}`);
}

Deno.serve(async (req) => {
  if (req.headers.get('x-cron-secret') !== CRON_SECRET) {
    return new Response('Unauthorized', { status: 401 });
  }
  if (!GMAIL_REFRESH_TOKEN) {
    return new Response(JSON.stringify({ skipped: 'GMAIL_REFRESH_TOKEN not set' }), { status: 200 });
  }

  try {
    const token = await getGmailAccessToken();
    const list = await gmail(token, `messages?maxResults=50&q=${encodeURIComponent(GMAIL_QUERY)}`);
    const ids: string[] = (list.messages || []).map((m: any) => m.id);
    if (!ids.length) return new Response(JSON.stringify({ processed: 0 }), { status: 200 });

    const { data: seen } = await sb.from('payments').select('gmail_message_id').in('gmail_message_id', ids);
    const seenIds = new Set((seen || []).map(r => r.gmail_message_id));

    const { data: students } = await sb.from('profiles')
      .select('id, full_name, email, referral_code, telegram_chat_id, language')
      .eq('is_admin', false);

    let credited = 0, unmatched = 0;

    for (const id of ids) {
      if (seenIds.has(id)) continue;
      const msg = await gmail(token, `messages/${id}?format=full`);

      const auth = header(msg, 'Authentication-Results');
      if (!/dkim=pass[^;]*header\.(?:i|d)=@?(?:[\w-]+\.)*wise\.com\b/i.test(auth)) {
        console.warn('Skipping email not DKIM-signed by wise.com:', id);
        continue;
      }

      const subject = header(msg, 'Subject');
      const text = bodyText(msg.payload);
      const parsed = parseWiseEmail(subject, text);
      if (!parsed) continue; // not an incoming EUR payment

      let matches: any[] = [];
      if (parsed.sender) {
        const n = norm(parsed.sender);
        matches = (students || []).filter(s => s.full_name && norm(s.full_name) === n);
      }
      if (matches.length !== 1) {
        const upper = `${subject}\n${text}`.toUpperCase();
        matches = (students || []).filter(s =>
          s.referral_code && new RegExp(`\\b${s.referral_code.toUpperCase()}\\b`).test(upper));
      }
      const student = matches.length === 1 ? matches[0] : null;

      const { data: row, error } = await sb.rpc('apply_wise_payment', {
        _gmail_message_id: id,
        _received_at: new Date(Number(msg.internalDate)).toISOString(),
        _amount_eur: parsed.amount,
        _sender_name: parsed.sender,
        _reference: parsed.reference,
        _student_id: student?.id ?? null
      });
      if (error) { console.error('apply_wise_payment failed:', id, error); continue; }
      if (!row?.id) continue; // raced with another run

      const amountStr = Number(row.amount_eur).toFixed(2);
      if (row.status === 'credited' && student) {
        credited++;
        const creditsStr = String(Number(row.credits_granted));
        if (ADMIN_TELEGRAM_CHAT_ID) {
          await sendMessage(ADMIN_TELEGRAM_CHAT_ID,
            `💶 <b>Pago Wise acreditado</b>\n👤 ${esc(student.full_name || 'Alumno/a')}\n` +
            `${amountStr}€ ÷ ${row.price_per_credit}€ = <b>${creditsStr}</b> créditos\n` +
            (student.email ? `✉️ Email de agradecimiento enviado a ${esc(student.email)}\n` : '') +
            `Si no es correcto, puedes deshacerlo en admin → Pagos.`);
        }
        const lang = student.language === 'pl' ? 'pl' : (student.language === 'en' ? 'en' : 'es');
        if (student.email) {
          try {
            const firstName = student.full_name?.trim().split(/\s+/)[0] || '';
            const mail = MAIL[lang](firstName, creditsStr, amountStr);
            await sendEmail(token, student.email, mail.subject, mail.body);
          } catch (e) {
            console.error('Thank-you email failed:', student.id, e);
          }
        }
        if (student.telegram_chat_id) {
          await sendMessage(student.telegram_chat_id, T[lang](creditsStr, amountStr));
        }
      } else {
        unmatched++;
        if (ADMIN_TELEGRAM_CHAT_ID) {
          await sendMessage(ADMIN_TELEGRAM_CHAT_ID,
            `⚠️ <b>Pago Wise sin asignar</b>\n${amountStr}€ de ${esc(parsed.sender || 'remitente desconocido')}\n` +
            (parsed.reference ? `Referencia: ${esc(parsed.reference)}\n` : '') +
            `No sé de qué alumno es. Asígnalo en admin → Pagos.`);
        }
      }
    }

    console.log(`wise-payments: credited ${credited}, unmatched ${unmatched}`);
    return new Response(JSON.stringify({ credited, unmatched }), { status: 200 });
  } catch (err) {
    console.error('wise-payments error:', err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
