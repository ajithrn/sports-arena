/// Blocked ad/tracking domains.
///
/// These domains are blocked at the proxy level (502 response) to prevent
/// ad overlays from loading and covering the video player.
///
/// When the DNS bypass proxy is active, DoH resolves ALL domains — including
/// ad networks that the ISP's DNS normally blocks. This list restores that
/// blocking behavior for known bad domains.
///
/// To add new domains: check proxy logs for domains that cause overlay issues.
/// Look for: `CONNECT proxy: tunnel request for suspicious-domain.com:443`
class BlockedDomains {
  BlockedDomains._();

  static const Set<String> all = {
    // ─── Ad Networks ───────────────────────────────
    'tanktds.com',
    'adclickad.com',
    'adexchangerapid.com',
    'offertomynewbid.com',
    'ad-maven.com',
    'ad-delivery.net',
    'adtng.com',
    'bidgear.com',
    'richads.com',
    'a-ads.com',
    'monetag.com',
    'profitablegatecpm.com',
    'onclickmax.com',
    'galaksion.com',
    'evadav.com',
    'pushground.com',

    // ─── Tracking / Redirects ──────────────────────
    'usrpubtrk.com',
    'wnouncillorswhowish.com',
    'ndcertainlywhen.com',
    'find-your-luck.site',
    'video-hyurfi.online',
    'actuallyfamousmako.team',
    'xml-v4.tri.media',
    'trk.nzrzerep.com',
    'syndication.realsrv.com',
    'tsyndicate.com',
    'dolohen.com',
    'adskeeper.co.uk',
    'yieldoptimizer.com',

    // ─── Popup / Malware Networks ──────────────────
    'popads.net',
    'popunder.net',
    'clickadu.com',
    'propellerads.com',
    'trafficjunky.net',
    'exoclick.com',
    'juicyads.com',
    'hilltopads.com',
    'srv.dt.pomxd.com',
    'popcash.net',
    'popmyads.com',
    'poperblocker.com',
    'notification-ede.com',
    'pushame.com',
    'push-notification.com',

    // ─── Streaming-specific ad overlays ────────────
    'betano.com',
    'bet365.com',
    'stake.com',
    '1xbet.com',
    '22bet.com',
    'melbet.com',
    'betwinner.com',
    'linebet.com',
    'mostbet.com',
    'parimatch.com',
    'sportingbet.com',
    'betway.com',
    'streamingadserver.com',
    'livestreamads.net',
  };
}
