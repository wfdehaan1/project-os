/*
 * Listing capture snippet — paste into the browser DevTools console on a listing
 * detail page, after the cookie/consent wall has been dismissed.
 *
 * Downloads one JSON bundle per listing into your Downloads folder.
 * Move the downloaded files into spikes/listing-corpus/raw/.
 *
 * Optional (only needed for 2-3 listings, to answer open question #2):
 * run it once in a fresh private window BEFORE dismissing the consent wall and
 * rename the file with a `-preconsent` suffix.
 */
(() => {
  const pick = (sel, fn) => Array.from(document.querySelectorAll(sel)).map(fn);

  const bundle = {
    url: location.href,
    host: location.host,
    title: document.title,
    capturedAt: new Date().toISOString(),
    userAgent: navigator.userAgent,
    // Structured data — the extraction spike cares most about these three.
    jsonLd: pick('script[type="application/ld+json"]', (s) => s.textContent),
    nextData: document.getElementById('__NEXT_DATA__')?.textContent ?? null,
    initialState: (() => {
      for (const k of ['__NUXT__', '__INITIAL_STATE__', '__APOLLO_STATE__']) {
        try { if (window[k]) return JSON.stringify(window[k]); } catch { /* ignore */ }
      }
      return null;
    })(),
    meta: Object.fromEntries(
      pick('meta[property], meta[name]', (m) => [
        m.getAttribute('property') ?? m.getAttribute('name'),
        m.getAttribute('content'),
      ]).filter(([k, v]) => k && v)
    ),
    // Post-hydration DOM: what an on-device WKWebView would actually see.
    outerHtml: document.documentElement.outerHTML,
    // Cheap heuristic for open question #1 (is the plate exposed?).
    plateCandidates: Array.from(
      new Set(
        (document.body.innerText.match(/\b[A-Z0-9]{1,3}-[A-Z0-9]{1,3}-[A-Z0-9]{1,3}\b/g) ?? [])
      )
    ),
  };

  const id =
    (location.host.split('.').slice(-2, -1)[0] || 'site') +
    '_' +
    (location.pathname.match(/(\d{6,})/)?.[1] ??
      location.pathname.split('/').filter(Boolean).pop() ??
      Date.now());

  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([JSON.stringify(bundle, null, 2)], { type: 'application/json' }));
  a.download = id + '.json';
  a.click();
  console.log('captured', id, {
    jsonLd: bundle.jsonLd.length,
    nextData: !!bundle.nextData,
    plateCandidates: bundle.plateCandidates,
  });
})();
