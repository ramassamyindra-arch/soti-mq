// Supabase Edge Function: send-push
// Envoie une notification push à chaque nouveau message ou nouvelle sortie.
// Appelée par un Database Webhook Postgres sur INSERT dans "messages" et "activities".
// Secrets requis (à définir dans Project Settings > Edge Functions > Secrets) :
//   VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT (mailto:ton-email@exemple.com)
// SUPABASE_URL et SUPABASE_SERVICE_ROLE_KEY sont fournis automatiquement par Supabase.

import webpush from "npm:web-push@3.6.7";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const VAPID_PUBLIC_KEY = Deno.env.get("VAPID_PUBLIC_KEY")!;
const VAPID_PRIVATE_KEY = Deno.env.get("VAPID_PRIVATE_KEY")!;
const VAPID_SUBJECT = Deno.env.get("VAPID_SUBJECT") || "mailto:contact@example.com";
const APP_URL = "https://ramassamyindra-arch.github.io/soti-mq/index.html";

webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);

async function sb(path: string, opts: RequestInit = {}) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...opts,
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      ...(opts.headers || {}),
    },
  });
  if (!res.ok && res.status !== 404) {
    console.error("supabase rest error", path, res.status, await res.text());
  }
  return res;
}

async function getSubscriptionsFor(userIds: string[]) {
  if (userIds.length === 0) return [];
  const filter = `user_id=in.(${userIds.join(",")})`;
  const res = await sb(`push_subscriptions?select=*&${filter}`);
  return res.ok ? await res.json() : [];
}

async function sendToSubscriptions(subs: any[], payload: Record<string, string>) {
  await Promise.all(subs.map(async (sub) => {
    const subscription = {
      endpoint: sub.endpoint,
      keys: { p256dh: sub.p256dh, auth: sub.auth },
    };
    try {
      await webpush.sendNotification(subscription, JSON.stringify(payload));
    } catch (err: any) {
      if (err.statusCode === 404 || err.statusCode === 410) {
        await sb(`push_subscriptions?id=eq.${sub.id}`, { method: "DELETE" });
      } else {
        console.error("push send error", sub.id, err.statusCode, err.body);
      }
    }
  }));
}

Deno.serve(async (req) => {
  try {
    const { type, table, record } = await req.json();
    if (type !== "INSERT" || !record) return new Response("ignored", { status: 200 });

    if (table === "messages") {
      const [actRes, authorRes, partsRes] = await Promise.all([
        sb(`activities?id=eq.${record.activity_id}&select=titre,organisateur_id`),
        sb(`profiles?id=eq.${record.author_id}&select=prenom`),
        sb(`participations?activity_id=eq.${record.activity_id}&statut=eq.inscrit&select=user_id`),
      ]);
      const [activity] = actRes.ok ? await actRes.json() : [];
      const [author] = authorRes.ok ? await authorRes.json() : [];
      const parts = partsRes.ok ? await partsRes.json() : [];
      if (!activity) return new Response("ok", { status: 200 });

      const recipientIds = new Set<string>(parts.map((p: any) => p.user_id));
      recipientIds.add(activity.organisateur_id);
      recipientIds.delete(record.author_id);
      if (recipientIds.size === 0) return new Response("ok", { status: 200 });

      const subs = await getSubscriptionsFor([...recipientIds]);
      const preview = record.content.length > 80 ? record.content.slice(0, 80) + "…" : record.content;
      await sendToSubscriptions(subs, {
        title: `💬 ${activity.titre}`,
        body: `${author?.prenom || "Quelqu'un"} : ${preview}`,
        url: `${APP_URL}#messages`,
      });
    }

    if (table === "activities") {
      const [organizerRes, activeRes] = await Promise.all([
        sb(`profiles?id=eq.${record.organisateur_id}&select=prenom`),
        sb(`profiles?statut=eq.actif&select=id`),
      ]);
      const [organizer] = organizerRes.ok ? await organizerRes.json() : [];
      const active = activeRes.ok ? await activeRes.json() : [];
      const recipientIds = active.map((p: any) => p.id).filter((id: string) => id !== record.organisateur_id);
      if (recipientIds.length === 0) return new Response("ok", { status: 200 });

      const subs = await getSubscriptionsFor(recipientIds);
      await sendToSubscriptions(subs, {
        title: "🌴 Nouvelle sortie",
        body: `${organizer?.prenom || "Quelqu'un"} propose : ${record.titre}`,
        url: `${APP_URL}#fil`,
      });
    }

    return new Response("ok", { status: 200 });
  } catch (e) {
    console.error("send-push error", e);
    return new Response("error", { status: 500 });
  }
});
