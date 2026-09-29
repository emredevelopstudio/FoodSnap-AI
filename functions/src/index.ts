/**
 * Gemini-Proxy für FoodSnap AI.
 * Der API-Key liegt ausschließlich als Firebase Secret auf dem Server.
 *
 * Setup:
 *   firebase functions:secrets:set GEMINI_KEY
 *   firebase deploy --only functions
 * App-Build:
 *   flutter build appbundle --dart-define=GEMINI_PROXY_URL=https://<region>-<projekt>.cloudfunctions.net/geminiProxy
 */
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions";

const GEMINI_KEY = defineSecret("GEMINI_KEY");
// Modelle serverseitig fixiert – Client kann sie nicht ändern. Bei 503/429/404 → nächstes Modell.
const MODELS = [
  "gemini-3.7-flash",
  "gemini-3.8-flash",
  "gemini-3.5-flash",
  "gemini-3.5-flash-lite",
  "gemini-3.1-flash-lite",
];
const MAX_BODY_BYTES = 4 * 1024 * 1024; // ~1024px-JPEG als Base64 passt locker rein.
const RATE_LIMIT_PER_MIN = 10;

// Einfaches Pro-Instanz-Limit gegen Missbrauch. Für harte Limits: Firestore/Redis + App Check.
const hits = new Map<string, { count: number; windowStart: number }>();

function rateLimited(ip: string): boolean {
  const now = Date.now();
  const entry = hits.get(ip);
  if (!entry || now - entry.windowStart > 60_000) {
    hits.set(ip, { count: 1, windowStart: now });
    return false;
  }
  entry.count++;
  return entry.count > RATE_LIMIT_PER_MIN;
}

export const geminiProxy = onRequest(
  {
    secrets: [GEMINI_KEY],
    region: "europe-west3",
    cors: false, // Nur native App, kein Browser-Zugriff.
    maxInstances: 5, // Kostendeckel.
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "method_not_allowed" });
      return;
    }

    const ip = req.ip ?? "unknown";
    if (rateLimited(ip)) {
      res.status(429).json({ error: "rate_limited" });
      return;
    }

    if ((req.rawBody?.length ?? 0) > MAX_BODY_BYTES) {
      res.status(413).json({ error: "payload_too_large" });
      return;
    }

    // Nur die erwarteten Felder durchreichen (keine tools, systemInstruction o. Ä.).
    const { contents, generationConfig } = req.body ?? {};
    if (!Array.isArray(contents) || contents.length === 0 || contents.length > 2) {
      res.status(400).json({ error: "invalid_request" });
      return;
    }

    const payload = JSON.stringify({
      contents,
      generationConfig: { response_mime_type: "application/json", ...generationConfig },
    });

    try {
      let upstream!: Response;
      for (const [i, model] of MODELS.entries()) {
        upstream = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-goog-api-key": GEMINI_KEY.value(),
            },
            body: payload,
            signal: AbortSignal.timeout(50_000),
          },
        );
        const tryNext = [503, 429, 404].includes(upstream.status);
        if (!tryNext || i === MODELS.length - 1) break;
        logger.warn("Gemini model overloaded, falling back", { model, status: upstream.status });
      }

      const text = await upstream.text();
      if (!upstream.ok) {
        logger.warn("Gemini upstream error", { status: upstream.status });
        // Keine Upstream-Details an den Client leaken, nur den Status.
        const busy = upstream.status === 429 || upstream.status === 503;
        res.status(busy ? upstream.status : 502).json({ error: "upstream_error" });
        return;
      }
      res.status(200).type("application/json").send(text);
    } catch (err) {
      logger.error("Gemini proxy failure", err);
      res.status(502).json({ error: "upstream_unreachable" });
    }
  },
);
