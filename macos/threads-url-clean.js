// Watch the clipboard; strip xmt / slof tracking params from Threads URLs.
// Run with: /usr/bin/osascript -l JavaScript threads-url-clean.js
//
// macOS has no clipboard-change notification, so this polls
// NSPasteboard.changeCount (a cheap integer) every 0.5s and only reads the
// clipboard text when that counter moves.
ObjC.import('AppKit');

const app = Application.currentApplication();
app.includeStandardAdditions = true;

const pb = $.NSPasteboard.generalPasteboard;
const SHARE_RE = /https?:\/\/(?:www\.)?threads\.(?:net|com)\/share\/[\w-]+\/?/gi;
// The query is limited to ASCII key=value pairs, so text glued right after the
// URL (common in CJK, e.g. "...?xmt=abc<full-width comma>lol" or "(...?xmt=abc)") is kept.
const PARAM = '[\\w.-]+(?:=[\\w~%+-]*)?';
const URL_RE = new RegExp(
  '(https?://(?:www\\.)?threads\\.(?:net|com)/[^\\s?#]*)\\?(' + PARAM + '(?:&' + PARAM + ')*)', 'gi');
const DROP_RE = /^(xmt|slof)(=|$)/i;

// /share/<code>/ short links 302 to the real post URL (with xmt); resolve them.
function resolveRedirect(url) {
  try {
    const loc = app.doShellScript(
      "/usr/bin/curl -s -o /dev/null -m 3 -A 'Mozilla/5.0' -w '%{redirect_url}' '" + url + "'");
    return loc || url;
  } catch (e) {
    return url;
  }
}

function cleanThreads(s) {
  return s.replace(URL_RE, (all, base, query) => {
    const kept = query.split('&').filter((kv) => kv && !DROP_RE.test(kv));
    return kept.length ? base + '?' + kept.join('&') : base;
  });
}

function readText() {
  const s = pb.stringForType($.NSPasteboardTypeString);
  return s.isNil() ? '' : ObjC.unwrap(s);
}

function run() {
  let last = pb.changeCount;
  for (;;) {
    delay(0.5);
    const count = pb.changeCount;
    if (count === last) continue;
    last = count;

    const s = readText();
    if (s.indexOf('threads.') < 0) continue;
    // SHARE_RE only matches [\w-] codes, so the URL is safe to single-quote.
    const t = cleanThreads(s.replace(SHARE_RE, resolveRedirect));
    if (t === s) continue;

    pb.clearContents;
    pb.setStringForType($(t), $.NSPasteboardTypeString);
    last = pb.changeCount;
  }
}
