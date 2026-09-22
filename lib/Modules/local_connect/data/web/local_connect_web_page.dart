import 'dart:convert';

String buildLocalConnectWebPage({
  Map<String, String> translations = const {},
  String scriptNonce = '',
}) {
  final i18n = <String, String>{..._localConnectWebFallbacks, ...translations};
  final queueLabel = (i18n['queue'] ?? '').trim().toLowerCase();
  if (!translations.containsKey('expandQueue') && queueLabel == 'cola') {
    i18n['expandQueue'] = 'Expandir';
  }
  if (!translations.containsKey('compactQueue') && queueLabel == 'cola') {
    i18n['compactQueue'] = 'Compactar';
  }
  return '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${_htmlText(i18n, 'title')}</title>
  <style>
    :root {
      --bg: #050807;
      --bg-elevated: #0a100e;
      --surface: #0d1512;
      --surface-2: #111b17;
      --surface-3: #17231e;
      --text: #f2f7f4;
      --muted: #8da198;
      --muted-2: #64766e;
      --accent: #35d8a3;
      --accent-soft: rgba(53, 216, 163, 0.12);
      --accent-border: rgba(53, 216, 163, 0.28);
      --border: rgba(255, 255, 255, 0.075);
      --danger: #ff7777;
      --radius-lg: 24px;
      --radius-md: 16px;
      --radius-sm: 12px;
      --shadow: 0 22px 60px rgba(0, 0, 0, 0.34);
    }

    * { box-sizing: border-box; }

    html { color-scheme: dark; }

    body {
      margin: 0;
      min-height: 100vh;
      color: var(--text);
      font-family: "SF Pro Display", "Inter", "Segoe UI", Roboto, -apple-system, sans-serif;
      background:
        radial-gradient(900px 520px at 14% -10%, rgba(53, 216, 163, 0.12), transparent 58%),
        radial-gradient(760px 480px at 92% 8%, rgba(53, 216, 163, 0.055), transparent 62%),
        linear-gradient(180deg, #070b09 0%, var(--bg) 58%, #030504 100%);
    }

    button, input { font: inherit; }
    [hidden] { display: none !important; }

    .shell {
      width: min(100%, 1680px);
      margin: 0 auto;
      padding: clamp(12px, 2vw, 28px);
      display: grid;
      gap: clamp(12px, 1.6vw, 20px);
    }

    .card {
      border: 1px solid var(--border);
      border-radius: var(--radius-lg);
      background: linear-gradient(180deg, rgba(17, 27, 23, 0.96), rgba(10, 16, 14, 0.98));
      box-shadow: var(--shadow);
    }

    .topbar {
      min-height: 64px;
      padding: 12px 18px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      background: rgba(10, 16, 14, 0.78);
      backdrop-filter: blur(18px);
      -webkit-backdrop-filter: blur(18px);
      position: sticky;
      top: 10px;
      z-index: 20;
    }

    .brand {
      min-width: 0;
      display: flex;
      align-items: center;
      gap: 10px;
      font-weight: 760;
      letter-spacing: -0.2px;
      font-size: 18px;
    }

    .brand-dot {
      width: 11px;
      height: 11px;
      border-radius: 50%;
      flex: 0 0 auto;
      background: var(--accent);
      box-shadow: 0 0 0 5px rgba(53, 216, 163, 0.08), 0 0 24px rgba(53, 216, 163, 0.38);
    }

    .status-pill, .queue-count, .artist-insight-pill, .track-chip, .lyrics-language {
      border: 1px solid var(--border);
      border-radius: 999px;
      color: var(--muted);
      background: rgba(255, 255, 255, 0.025);
    }

    .status-pill {
      padding: 7px 11px;
      font-size: 12px;
      white-space: nowrap;
    }

    .status-pill.paired {
      color: var(--accent);
      border-color: var(--accent-border);
      background: var(--accent-soft);
    }

    .status-pill.unpaired { color: #ffd39a; }

    .pairing {
      width: min(100%, 620px);
      justify-self: center;
      padding: clamp(18px, 3vw, 28px);
      display: grid;
      gap: 10px;
      text-align: center;
      background:
        radial-gradient(500px 180px at 50% 0%, rgba(53, 216, 163, 0.11), transparent 70%),
        linear-gradient(180deg, rgba(17, 27, 23, 0.98), rgba(8, 13, 11, 0.99));
    }

    .pairing-title { font-size: 18px; font-weight: 730; }
    .small { font-size: 12px; color: var(--muted); }

    .btn {
      min-height: 42px;
      border: 1px solid var(--border);
      background: rgba(255, 255, 255, 0.035);
      color: var(--text);
      border-radius: 999px;
      padding: 9px 15px;
      cursor: pointer;
      font-weight: 650;
      letter-spacing: 0.05px;
      transition: transform 120ms ease, background 140ms ease, border-color 140ms ease, filter 140ms ease;
    }

    .btn:hover {
      border-color: rgba(53, 216, 163, 0.34);
      background: rgba(53, 216, 163, 0.075);
    }

    .btn:active { transform: scale(0.98); }

    .btn-primary {
      color: #05110d;
      border-color: transparent;
      background: var(--accent);
      box-shadow: 0 10px 28px rgba(53, 216, 163, 0.16);
    }

    .btn-primary:hover { background: #48e2b0; filter: brightness(1.02); }

    .btn-toggle-active {
      color: var(--accent);
      border-color: var(--accent-border);
      background: var(--accent-soft);
    }

    .main-grid {
      display: grid;
      grid-template-columns: 1fr;
      gap: clamp(14px, 1.7vw, 22px);
      align-items: start;
    }

    .now-panel {
      min-width: 0;
      overflow: hidden;
      padding: clamp(18px, 2.2vw, 30px);
      display: grid;
      gap: clamp(18px, 2vw, 26px);
      position: relative;
      isolation: isolate;
      background:
        radial-gradient(720px 420px at 0% 0%, rgba(53, 216, 163, 0.09), transparent 62%),
        linear-gradient(180deg, rgba(17, 27, 23, 0.98), rgba(8, 13, 11, 0.99));
    }

    .now-panel::before {
      content: "";
      position: absolute;
      inset: -20% auto auto -10%;
      width: 420px;
      height: 420px;
      border-radius: 50%;
      background: rgba(53, 216, 163, 0.055);
      filter: blur(80px);
      pointer-events: none;
      z-index: -1;
    }

    .cover-row {
      min-width: 0;
      display: grid;
      grid-template-columns: clamp(300px, 28vw, 430px) minmax(0, 1fr);
      gap: clamp(24px, 4vw, 58px);
      align-items: center;
    }

    .cover-wrap {
      width: 100%;
      aspect-ratio: 1 / 1;
      border-radius: clamp(18px, 2vw, 28px);
      overflow: hidden;
      border: 1px solid rgba(255, 255, 255, 0.09);
      background: linear-gradient(145deg, #17241f, #09100d);
      box-shadow: 0 28px 58px rgba(0, 0, 0, 0.44);
    }

    .cover {
      width: 100%;
      height: 100%;
      display: block;
      object-fit: cover;
    }

    .meta { min-width: 0; }

    .eyebrow {
      margin-bottom: 10px;
      color: var(--accent);
      font-size: 11px;
      font-weight: 760;
      letter-spacing: 1.1px;
      text-transform: uppercase;
    }

    .meta h1 {
      margin: 0;
      font-size: clamp(30px, 4vw, 54px);
      line-height: 1.02;
      letter-spacing: -1.4px;
      font-weight: 780;
      display: -webkit-box;
      -webkit-line-clamp: 3;
      -webkit-box-orient: vertical;
      overflow: hidden;
    }

    .meta .artist {
      margin: 12px 0 0;
      font-size: clamp(19px, 2.1vw, 28px);
      font-weight: 560;
      color: #cbd8d2;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .meta .album {
      margin: 6px 0 0;
      color: var(--muted);
      font-size: 14px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .meta .state {
      margin-top: 18px;
      display: inline-flex;
      align-items: center;
      min-height: 30px;
      padding: 6px 10px;
      border-radius: 999px;
      border: 1px solid var(--border);
      color: var(--muted);
      background: rgba(255, 255, 255, 0.025);
      font-size: 12px;
    }

    .track-chips {
      margin-top: 10px;
      display: flex;
      flex-wrap: wrap;
      gap: 7px;
    }

    .track-chip {
      max-width: 100%;
      padding: 6px 9px;
      font-size: 11px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .track-chip.strong {
      color: var(--accent);
      border-color: var(--accent-border);
      background: var(--accent-soft);
    }

    .dock {
      display: grid;
      gap: 14px;
      padding-top: 2px;
    }

    .seek-wrap { display: grid; gap: 7px; }

    input[type="range"] {
      width: 100%;
      margin: 0;
      accent-color: var(--accent);
      cursor: pointer;
    }

    #seekBar { height: 6px; }

    .time-row {
      display: flex;
      justify-content: space-between;
      gap: 12px;
      color: var(--muted);
      font-size: 12px;
      font-variant-numeric: tabular-nums;
    }

    .dock-controls {
      display: grid;
      grid-template-columns: auto auto minmax(110px, auto) auto auto auto minmax(150px, 1fr);
      align-items: center;
      justify-content: center;
      gap: 8px;
    }

    #btnPlayPause {
      min-width: 112px;
      min-height: 48px;
      font-size: 15px;
      padding-inline: 22px;
    }

    #btnPrev, #btnNext, #btnSeekBack, #btnSeekFwd, #btnShuffle {
      min-width: 74px;
    }

    .volume-wrap {
      min-width: 145px;
      display: grid;
      grid-template-columns: auto minmax(80px, 1fr);
      align-items: center;
      gap: 9px;
      padding-left: 8px;
    }

    .volume-wrap .small { white-space: nowrap; }

    .queue-column {
      min-width: 0;
      position: static;
    }

    .queue-panel {
      padding: 18px 20px 20px;
      display: grid;
      gap: 14px;
      overflow: hidden;
    }

    .queue-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
    }

    .queue-head h2 {
      margin: 0;
      font-size: 20px;
      letter-spacing: -0.35px;
      font-weight: 740;
    }

    .queue-head-actions {
      display: flex;
      align-items: center;
      gap: 7px;
      margin-left: auto;
    }

    .queue-count { padding: 5px 9px; font-size: 11px; white-space: nowrap; }

    .queue-mobile-toggle {
      display: none;
      align-items: center;
      justify-content: center;
      gap: 6px;
      min-height: 30px;
      padding: 5px 9px;
      border-radius: 999px;
      border: 1px solid var(--border);
      background: rgba(255,255,255,.03);
      color: var(--muted);
      font: inherit;
      font-size: 11px;
      font-weight: 650;
      cursor: pointer;
      transition: color 120ms ease, background 120ms ease, border-color 120ms ease;
    }

    .queue-mobile-toggle:hover {
      color: var(--text);
      border-color: rgba(53,216,163,.25);
      background: rgba(53,216,163,.055);
    }

    .queue-mobile-toggle-icon {
      display: inline-grid;
      place-items: center;
      width: 15px;
      height: 15px;
      font-size: 13px;
      line-height: 1;
      transition: transform 150ms ease;
    }

    .queue-panel.queue-expanded .queue-mobile-toggle-icon { transform: rotate(180deg); }

    .queue-carousel {
      display: grid;
      grid-auto-flow: column;
      grid-auto-columns: clamp(154px, 13vw, 192px);
      gap: 12px;
      overflow-x: auto;
      padding: 3px 1px 9px;
      scroll-snap-type: x mandatory;
      scrollbar-width: thin;
      scrollbar-color: rgba(255,255,255,.15) transparent;
    }

    .queue-carousel::-webkit-scrollbar { height: 5px; }
    .queue-carousel::-webkit-scrollbar-thumb { background: rgba(255,255,255,.14); border-radius: 999px; }

    .queue-cover-item {
      min-width: 0;
      overflow: hidden;
      border-radius: 14px;
      border: 1px solid var(--border);
      background: rgba(255,255,255,.025);
      scroll-snap-align: start;
      cursor: pointer;
      transition: transform 140ms ease, border-color 140ms ease, background 140ms ease;
    }

    .queue-cover-item:hover {
      transform: translateY(-2px);
      border-color: rgba(53,216,163,.3);
      background: rgba(53,216,163,.04);
    }

    .queue-cover-item.active {
      border-color: var(--accent-border);
      box-shadow: inset 0 0 0 1px rgba(53,216,163,.08);
    }

    .queue-cover-wrap { width: 100%; aspect-ratio: 1; overflow: hidden; background: #101915; }
    .queue-cover { width: 100%; height: 100%; object-fit: cover; display: block; }
    .queue-cover-fallback { width:100%; height:100%; display:grid; place-items:center; color:var(--muted-2); font-size:28px; }
    .queue-cover-meta { padding: 9px 10px 10px; display: grid; gap: 3px; }
    .queue-cover-title { font-size: 12px; color: var(--text); font-weight: 650; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .queue-cover-artist { font-size: 11px; color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }

    .queue-list {
      margin: 0;
      padding: 0 2px 0 0;
      list-style: none;
      display: none;
      gap: 5px;
      max-height: min(48vh, 520px);
      overflow: auto;
      scrollbar-width: thin;
      scrollbar-color: rgba(255,255,255,.14) transparent;
    }

    .queue-list::-webkit-scrollbar, .artist-next-list::-webkit-scrollbar { width: 6px; }
    .queue-list::-webkit-scrollbar-thumb, .artist-next-list::-webkit-scrollbar-thumb { background: rgba(255,255,255,.14); border-radius:999px; }

    .queue-item {
      min-width: 0;
      min-height: 54px;
      padding: 8px 9px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 9px;
      border: 1px solid transparent;
      border-radius: 12px;
      color: var(--text);
      background: transparent;
      cursor: pointer;
      transition: background 130ms ease, border-color 130ms ease;
    }

    .queue-item:hover { background: rgba(255,255,255,.035); }
    .queue-item.active { background: var(--accent-soft); border-color: rgba(53,216,163,.12); }

    .queue-item-main { min-width: 0; flex: 1; display: flex; align-items: center; gap: 9px; }
    .queue-item-index { width: 26px; height: 26px; border-radius: 8px; display:grid; place-items:center; flex:0 0 auto; color:var(--muted-2); font-size:10px; font-weight:700; background:rgba(255,255,255,.035); font-variant-numeric:tabular-nums; }
    .queue-item.active .queue-item-index { color: var(--accent); background: rgba(53,216,163,.11); }
    .queue-item-text { min-width: 0; display:grid; gap:2px; }
    .queue-item-title { font-size:13px; font-weight:650; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .queue-item-sub { font-size:11px; color:var(--muted); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .queue-item-time { flex:0 0 auto; color:var(--muted); font-size:11px; font-variant-numeric:tabular-nums; }

    .details-card { overflow: hidden; }

    .details-tabs {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 10px;
      border-bottom: 1px solid var(--border);
      overflow-x: auto;
      scrollbar-width: none;
    }

    .details-tabs::-webkit-scrollbar { display: none; }

    .detail-tab {
      flex: 0 0 auto;
      border: 0;
      border-radius: 999px;
      background: transparent;
      color: var(--muted);
      padding: 9px 13px;
      cursor: pointer;
      font-weight: 660;
      font-size: 13px;
      transition: color 120ms ease, background 120ms ease;
    }

    .detail-tab:hover { color: var(--text); background: rgba(255,255,255,.035); }
    .detail-tab.is-active { color: var(--accent); background: var(--accent-soft); }

    .details-body { padding: clamp(14px, 2vw, 22px); }
    .detail-panel { display: none; }
    .detail-panel.is-active { display: block; }

    .stats {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 10px;
    }

    .stat, .track-history-card, .artist-kpi {
      min-width: 0;
      border-radius: 14px;
      background: rgba(255,255,255,.028);
      border: 1px solid var(--border);
    }

    .stat { min-height: 86px; padding: 14px; display:grid; gap:5px; align-content:center; }
    .stat-label, .track-history-label, .artist-kpi-label { color:var(--muted); font-size:10px; text-transform:uppercase; letter-spacing:.65px; }
    .stat-value { font-size:20px; font-weight:720; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; font-variant-numeric:tabular-nums; }
    .stat-value.accent { color:var(--accent); }

    .track-history, .artist-insights { display:grid; gap:12px; }
    .info-block { margin-top: clamp(28px, 3vw, 38px); }
    .info-block + .info-block { margin-top: clamp(34px, 3.4vw, 44px); }
    .track-history-head, .artist-head { display:flex; align-items:center; justify-content:space-between; gap:10px; margin-bottom:2px; }
    .track-history-head h3, .artist-head h3 { margin:0; font-size:17px; }
    .artist-insight-pill { padding:5px 9px; font-size:11px; }
    .track-history-grid { display:grid; grid-template-columns:repeat(5,minmax(0,1fr)); gap:9px; }
    .track-history-card { padding:12px; display:grid; gap:4px; }
    .track-history-value { font-size:18px; font-weight:710; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; font-variant-numeric:tabular-nums; }

    .artist-profile {
      min-height: 82px;
      padding: 10px;
      display:flex;
      align-items:center;
      gap:12px;
      border-radius:14px;
      background:rgba(255,255,255,.025);
      border:1px solid var(--border);
    }

    .artist-profile-avatar-wrap { width:60px; height:60px; flex:0 0 auto; border-radius:50%; overflow:hidden; display:grid; place-items:center; background:#122019; border:1px solid var(--accent-border); }
    .artist-profile-avatar { width:100%; height:100%; object-fit:cover; display:block; }
    .artist-profile-avatar-fallback { width:100%; height:100%; display:grid; place-items:center; color:var(--muted); font-size:14px; font-weight:720; text-transform:uppercase; }
    .artist-profile-meta { min-width:0; display:grid; gap:3px; }
    .artist-profile-name { font-size:16px; font-weight:700; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .artist-profile-line { font-size:12px; color:var(--muted); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .artist-kpis { display:grid; grid-template-columns:repeat(5,minmax(0,1fr)); gap:9px; }
    .artist-kpi { padding:10px; display:grid; gap:4px; }
    .artist-kpi-value { font-size:17px; font-weight:710; font-variant-numeric:tabular-nums; }
    .artist-subhead { margin-top:2px; color:var(--muted); font-size:10px; text-transform:uppercase; letter-spacing:.7px; }
    .artist-next-list { margin:0; padding:0; list-style:none; display:grid; gap:6px; max-height:210px; overflow:auto; }
    .artist-next-item { min-height:46px; padding:7px 9px; display:flex; align-items:center; justify-content:space-between; gap:8px; border-radius:11px; background:rgba(255,255,255,.025); border:1px solid transparent; cursor:pointer; }
    .artist-next-item:hover { background:rgba(255,255,255,.04); border-color:var(--border); }
    .artist-next-main { min-width:0; flex:1; display:flex; align-items:center; gap:8px; }
    .artist-next-index { flex:0 0 auto; font-size:10px; color:var(--muted); }
    .artist-next-text { min-width:0; display:grid; gap:1px; }
    .artist-next-title { font-size:12px; font-weight:640; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .artist-next-sub { font-size:11px; color:var(--muted); white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
    .artist-next-time { flex:0 0 auto; font-size:11px; color:var(--muted); }
    .artist-next-empty { padding:14px; border-radius:12px; border:1px dashed var(--border); color:var(--muted); font-size:12px; text-align:center; }

    .lyrics-panel { min-width:0; }
    .lyrics-panel-inner { display:grid; gap:12px; }
    .lyrics-head { display:flex; align-items:center; gap:10px; }
    .lyrics-mark { width:32px; height:32px; display:grid; place-items:center; border-radius:10px; color:var(--accent); background:var(--accent-soft); border:1px solid var(--accent-border); }
    .lyrics-title { font-size:17px; font-weight:720; }
    .lyrics-language { margin-left:auto; padding:4px 8px; font-size:10px; text-transform:uppercase; letter-spacing:.65px; }
    .lyrics-scroll { max-height:min(48vh,520px); overflow:auto; scrollbar-width:thin; scrollbar-color:rgba(255,255,255,.14) transparent; }
    .lyrics-content { margin:0; padding:16px 18px; border-radius:14px; background:rgba(255,255,255,.025); border:1px solid var(--border); color:var(--text); font:inherit; font-size:15px; line-height:1.82; white-space:pre-wrap; overflow-wrap:anywhere; }

    @media (max-width: 1180px) {
      .cover-row { grid-template-columns: clamp(250px, 31vw, 340px) minmax(0,1fr); }
      .queue-carousel { grid-auto-columns: clamp(146px, 17vw, 180px); }
      .dock-controls { grid-template-columns: repeat(6, auto) minmax(130px,1fr); }
      #btnPrev, #btnNext, #btnSeekBack, #btnSeekFwd, #btnShuffle { min-width: 64px; padding-inline:11px; }
    }

    @media (max-width: 920px) {
      .shell { width:min(100%,820px); }
      .queue-carousel { display:none; }
      .queue-list { display:grid; max-height:420px; }
      .cover-row { grid-template-columns: minmax(210px, 270px) minmax(0,1fr); }
      .dock-controls { grid-template-columns: repeat(3,minmax(0,1fr)); }
      .volume-wrap { grid-column:1 / -1; grid-template-columns:auto 1fr; padding:4px 6px 0; }
      .stats { grid-template-columns:repeat(2,minmax(0,1fr)); }
      .track-history-grid, .artist-kpis { grid-template-columns:repeat(3,minmax(0,1fr)); }
      .info-block { margin-top:26px; }
      .info-block + .info-block { margin-top:30px; }
    }

    @media (max-width: 640px) {
      body { background:linear-gradient(180deg,#070b09 0%,#030504 100%); }
      .shell { padding:8px; gap:9px; }
      .card { border-radius:18px; box-shadow:0 14px 36px rgba(0,0,0,.28); }
      .topbar { min-height:54px; top:6px; padding:9px 12px; border-radius:16px; }
      .brand { font-size:15px; }
      .status-pill { font-size:10px; padding:6px 8px; }
      .pairing { padding:18px 14px; }
      .now-panel { padding:14px; gap:17px; }
      .cover-row { display:flex; flex-direction:column; align-items:center; gap:16px; }
      .cover-wrap { width:min(78vw,330px); }
      .meta { width:100%; text-align:center; }
      .eyebrow { display:none; }
      .meta h1 { font-size:clamp(23px,7.5vw,31px); line-height:1.08; letter-spacing:-.6px; -webkit-line-clamp:2; }
      .meta .artist { margin-top:7px; font-size:17px; }
      .meta .album { margin-top:4px; font-size:12px; }
      .meta .state { margin-top:10px; }
      .track-chips { justify-content:center; margin-top:8px; }
      .track-chip { max-width:42vw; }
      .dock { gap:12px; }
      .dock-controls { grid-template-columns:repeat(3,minmax(0,1fr)); gap:7px; }
      .dock-controls .btn { min-width:0; min-height:42px; padding:8px 7px; font-size:11px; }
      #btnPlayPause { min-width:0; min-height:48px; font-size:13px; order:2; }
      #btnPrev { order:1; }
      #btnNext { order:3; }
      #btnSeekBack { order:4; }
      #btnShuffle { order:5; }
      #btnSeekFwd { order:6; }
      .volume-wrap { order:7; grid-column:1 / -1; }
      .queue-panel { padding:13px; }
      .queue-head { align-items:center; }
      .queue-head h2 { font-size:18px; }
      .queue-head-actions { gap:5px; }
      .queue-mobile-toggle { display:inline-flex; }
      .queue-mobile-toggle[hidden] { display:none; }
      .queue-list {
        max-height:320px;
        overflow-y:auto;
        overscroll-behavior:contain;
        padding-right:4px;
        scrollbar-gutter:stable;
      }
      .queue-panel.queue-expanded .queue-list {
        max-height:none;
        overflow:visible;
        padding-right:0;
      }
      .queue-item { min-height:52px; }
      .queue-item-time { display:none; }
      .details-tabs { padding:8px; }
      .detail-tab { padding:8px 11px; font-size:12px; }
      .details-body { padding:12px; }
      .stats { grid-template-columns:repeat(2,minmax(0,1fr)); gap:7px; }
      .stat { min-height:72px; padding:10px; }
      .stat-value { font-size:17px; }
      .track-history-grid, .artist-kpis {
        display:grid;
        grid-template-columns:repeat(2,minmax(0,1fr));
        gap:8px;
        overflow:visible;
        padding-bottom:0;
      }
      .track-history-card, .artist-kpi {
        min-width:0;
        min-height:78px;
        padding:11px;
        align-content:center;
      }
      .track-history-card:last-child, .artist-kpi:last-child {
        grid-column:1 / -1;
      }
      .track-history-label, .artist-kpi-label {
        line-height:1.25;
        overflow-wrap:anywhere;
      }
      .track-history-value, .artist-kpi-value {
        font-size:18px;
      }
      .artist-profile { min-height:70px; }
      .artist-profile-avatar-wrap { width:50px; height:50px; }
      .lyrics-content { padding:13px 14px; font-size:14px; line-height:1.72; }
    }

    @media (max-width: 390px) {
      .cover-wrap { width:min(82vw,280px); }
      .meta h1 { font-size:22px; }
      .track-chip { max-width:38vw; }
      .dock-controls .btn { font-size:10px; padding-inline:5px; }
      .volume-wrap .small { display:none; }
      .volume-wrap { grid-template-columns:1fr; }
      .queue-head { flex-wrap:wrap; }
      .queue-head-actions { width:100%; justify-content:space-between; }
      .track-history-head, .artist-head { align-items:flex-start; }
      .track-history-head h3, .artist-head h3 { font-size:16px; }
      .artist-insight-pill { max-width:48%; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
      .artist-profile { align-items:flex-start; }
      .artist-profile-line { white-space:normal; overflow:visible; text-overflow:clip; line-height:1.35; }
    }

    @media (max-width: 920px) and (max-height: 540px) and (orientation: landscape) {
      .shell { width:100%; max-width:none; padding:7px; }
      .topbar { position:static; }
      .cover-row { grid-template-columns:150px minmax(0,1fr); gap:14px; }
      .cover-wrap { width:150px; }
      .meta { text-align:left; }
      .meta h1 { font-size:22px; -webkit-line-clamp:1; }
      .meta .artist { font-size:15px; }
      .track-chips { justify-content:flex-start; }
      .queue-list { max-height:245px; }
      .dock-controls { grid-template-columns:repeat(6,minmax(0,1fr)); }
      .volume-wrap { display:none; }
    }
  </style>
</head>
<body>
  <div class="shell">
    <header class="card topbar">
      <div class="brand">
        <span class="brand-dot"></span>
        <span>${_htmlText(i18n, 'title')}</span>
      </div>
      <span id="pairingState" class="status-pill unpaired">${_htmlText(i18n, 'notPaired')}</span>
    </header>

    <section class="card pairing" id="pairingCard">
      <div class="pairing-title">${_htmlText(i18n, 'pairingRequired')}</div>
      <div class="small">${_htmlText(i18n, 'pairingInstructions')}</div>
      <button id="btnPair" class="btn btn-primary">${_htmlText(i18n, 'requestPairing')}</button>
      <span id="pairingInfo" class="small"></span>
    </section>

    <main class="main-grid">
      <section class="card now-panel">
        <div class="cover-row">
          <div class="cover-wrap">
            <img id="cover" class="cover" alt="Cover" />
          </div>

          <div class="meta">
            <div class="eyebrow">${_htmlText(i18n, 'remoteSession')}</div>
            <h1 id="title">${_htmlText(i18n, 'noTrack')}</h1>
            <p id="artist" class="artist">—</p>
            <p id="album" class="album">${_htmlText(i18n, 'info')}: —</p>
            <div id="playbackState" class="state">${_htmlText(i18n, 'waitingSession')}</div>
            <div class="track-chips">
              <span id="chipSpeed" class="track-chip strong">1.00x</span>
              <span id="chipSource" class="track-chip">${_htmlText(i18n, 'source')}: —</span>
              <span id="chipFavorite" class="track-chip">${_htmlText(i18n, 'notFavorite')}</span>
            </div>
          </div>
        </div>

        <div class="dock">
          <div class="seek-wrap">
            <input id="seekBar" type="range" min="0" max="1000" value="0" aria-label="Seek" />
            <div class="time-row">
              <span id="timeCurrent">00:00</span>
              <span id="timeDuration">00:00</span>
            </div>
          </div>

          <div class="dock-controls">
            <button id="btnPrev" class="btn">${_htmlText(i18n, 'previous')}</button>
            <button id="btnPlayPause" class="btn btn-primary">${_htmlText(i18n, 'play')}</button>
            <button id="btnNext" class="btn">${_htmlText(i18n, 'next')}</button>
            <button id="btnShuffle" class="btn">${_htmlText(i18n, 'shuffle')}</button>
            <button id="btnSeekBack" class="btn">-10s</button>
            <button id="btnSeekFwd" class="btn">+10s</button>
            <div class="volume-wrap">
              <span class="small">${_htmlText(i18n, 'volume')}</span>
              <input id="volumeBar" type="range" min="0" max="100" value="100" aria-label="Volume" />
            </div>
          </div>
        </div>
      </section>

      <aside class="queue-column">
        <section class="card queue-panel" id="queuePanel">
          <div class="queue-head">
            <h2>${_htmlText(i18n, 'queue')}</h2>
            <div class="queue-head-actions">
              <span id="queueCount" class="queue-count">0 ${_htmlText(i18n, 'tracks')}</span>
              <button
                id="btnQueueCompact"
                class="queue-mobile-toggle"
                type="button"
                aria-controls="queueList"
                aria-expanded="false"
                hidden
              >
                <span class="queue-mobile-toggle-icon" aria-hidden="true">⌄</span>
                <span id="queueCompactLabel">${_htmlText(i18n, 'expandQueue')}</span>
              </button>
            </div>
          </div>
          <div id="queueCarousel" class="queue-carousel"></div>
          <ul id="queueList" class="queue-list"></ul>
        </section>
      </aside>
    </main>

    <section class="card details-card" id="detailsCard">
      <nav class="details-tabs" aria-label="Track details">
        <button type="button" class="detail-tab is-active" data-detail-tab="info">${_htmlText(i18n, 'info')}</button>
        <button type="button" class="detail-tab" data-detail-tab="lyrics">${_htmlText(i18n, 'lyrics')}</button>
      </nav>

      <div class="details-body">
        <section class="detail-panel is-active" data-detail-panel="info">
          <div class="stats">
            <div class="stat">
              <div class="stat-label">${_htmlText(i18n, 'currentTime')}</div>
              <div id="statCurrent" class="stat-value">00:00</div>
            </div>
            <div class="stat">
              <div class="stat-label">${_htmlText(i18n, 'duration')}</div>
              <div id="statDuration" class="stat-value">00:00</div>
            </div>
            <div class="stat">
              <div class="stat-label">${_htmlText(i18n, 'queuePosition')}</div>
              <div id="statQueuePos" class="stat-value">-</div>
            </div>
            <div class="stat">
              <div class="stat-label">${_htmlText(i18n, 'progress')}</div>
              <div id="statProgress" class="stat-value accent">0%</div>
            </div>
          </div>

          <section class="track-history info-block">
            <div class="track-history-head">
              <h3>${_htmlText(i18n, 'trackHistory')}</h3>
              <span id="trackHistoryNote" class="artist-insight-pill">${_htmlText(i18n, 'realAppData')}</span>
            </div>
            <div class="track-history-grid">
              <div class="track-history-card">
                <span class="track-history-label">${_htmlText(i18n, 'plays')}</span>
                <strong id="trackPlays" class="track-history-value">0</strong>
              </div>
              <div class="track-history-card">
                <span class="track-history-label">${_htmlText(i18n, 'completed')}</span>
                <strong id="trackCompleted" class="track-history-value">0</strong>
              </div>
              <div class="track-history-card">
                <span class="track-history-label">${_htmlText(i18n, 'skips')}</span>
                <strong id="trackSkips" class="track-history-value">0</strong>
              </div>
              <div class="track-history-card">
                <span class="track-history-label">${_htmlText(i18n, 'retention')}</span>
                <strong id="trackRetention" class="track-history-value">-</strong>
              </div>
              <div class="track-history-card">
                <span class="track-history-label">${_htmlText(i18n, 'lastPlayed')}</span>
                <strong id="trackLastPlayed" class="track-history-value">-</strong>
              </div>
            </div>
          </section>

          <section class="artist-insights info-block">
            <div class="artist-head">
              <h3>${_htmlText(i18n, 'artistData')}</h3>
              <span id="artistInsightCount" class="artist-insight-pill">-</span>
            </div>
            <div class="artist-profile">
              <div class="artist-profile-avatar-wrap">
                <img id="artistAvatar" class="artist-profile-avatar" alt="Artist or band" />
                <span id="artistAvatarFallback" class="artist-profile-avatar-fallback">--</span>
              </div>
              <div class="artist-profile-meta">
                <div id="artistProfileName" class="artist-profile-name">${_htmlText(i18n, 'unknownArtist')}</div>
                <div id="artistProfileType" class="artist-profile-line">${_htmlText(i18n, 'type')}: ${_htmlText(i18n, 'unknown')}</div>
                <div id="artistProfileSource" class="artist-profile-line">${_htmlText(i18n, 'source')}: —</div>
              </div>
            </div>
            <div class="artist-kpis">
              <div class="artist-kpi">
                <span class="artist-kpi-label">${_htmlText(i18n, 'queueTracks')}</span>
                <strong id="artistTracksByArtist" class="artist-kpi-value">0</strong>
              </div>
              <div class="artist-kpi">
                <span class="artist-kpi-label">${_htmlText(i18n, 'queuePlays')}</span>
                <strong id="artistAlbumsCount" class="artist-kpi-value">0</strong>
              </div>
              <div class="artist-kpi">
                <span class="artist-kpi-label">${_htmlText(i18n, 'queueCompletes')}</span>
                <strong id="artistCompletedCount" class="artist-kpi-value">0</strong>
              </div>
              <div class="artist-kpi">
                <span class="artist-kpi-label">${_htmlText(i18n, 'queueSkips')}</span>
                <strong id="artistSkipCount" class="artist-kpi-value">0</strong>
              </div>
              <div class="artist-kpi">
                <span class="artist-kpi-label">${_htmlText(i18n, 'queueAvg')}</span>
                <strong id="artistTotalDuration" class="artist-kpi-value">0%</strong>
              </div>
            </div>
            <div class="artist-subhead">${_htmlText(i18n, 'nextTracksByArtist')}</div>
            <ul id="artistNextList" class="artist-next-list">
              <li class="artist-next-empty">${_htmlText(i18n, 'noArtistDataYet')}</li>
            </ul>
          </section>
        </section>

        <section id="lyricsPanel" class="detail-panel lyrics-panel" data-detail-panel="lyrics" hidden>
          <div class="lyrics-panel-inner">
            <div class="lyrics-head">
              <span class="lyrics-mark" aria-hidden="true">♪</span>
              <span class="lyrics-title">${_htmlText(i18n, 'lyrics')}</span>
              <span id="lyricsLanguage" class="lyrics-language"></span>
            </div>
            <div class="lyrics-scroll">
              <pre id="lyricsContent" class="lyrics-content"></pre>
            </div>
          </div>
        </section>
      </div>
    </section>

    <audio id="audioPlayer" preload="auto" style="display:none;"></audio>
  </div>

  <script nonce="${htmlEscape.convert(scriptNonce)}">
    const i18n = ${jsonEncode(i18n).replaceAll('<', r'\u003c')};
    function t(key) {
      return i18n[key] || key;
    }

    function plural(count, singularKey, pluralKey) {
      return Number(count) === 1 ? t(singularKey) : t(pluralKey);
    }

    const state = {
      token: sessionStorage.getItem("listenfy_local_token") || "",
      pairingReceipt: sessionStorage.getItem("listenfy_pairing_receipt") || "",
      pairingCheckPending: false,
      sessionLoadPending: false,
      privatePlayback: false,
      queueVersion: 0,
      clientId: sessionStorage.getItem("listenfy_local_client_id") || "",
      socket: null,
      wsReconnectTimer: null,
      wsReconnectDelayMs: 1500,
      sessionPollTimer: null,
      healthPollTimer: null,
      pairingPollTimer: null,
      playback: { positionMs: 0, durationMs: 0, isPlaying: false, isBuffering: false, speed: 1, volume: 1, shuffleEnabled: false },
      queue: [],
      currentQueueIndex: 0,
      currentTrackId: "",
      currentVariantId: "",
      sourceLoading: false,
      currentAudioSrc: "",
      currentCoverSrc: "",
      lastRenderedQueueSignature: "",
      lastRenderedQueueIndex: -1,
      lastRenderedTrackId: "",
      queueInteractionUntilMs: 0,
      volumeSendTimer: null,
      wsConnected: false,
      wsLastMessageAt: 0,
      sessionLastSyncAt: 0,
      syncUnstable: false,
      waitingPairing: false,
      pairingPollTicks: 0,
      seekSyncLockUntilMs: 0
    };

    // Retire credentials persisted by older versions.
    localStorage.removeItem("listenfy_local_token");
    const MAX_RENDERED_QUEUE_ITEMS = 90;

    if (!state.clientId) {
      state.clientId = "web-" + Math.random().toString(36).slice(2) + Date.now().toString(36);
      sessionStorage.setItem("listenfy_local_client_id", state.clientId);
    }

    const el = {
      pairingState: document.getElementById("pairingState"),
      pairingInfo: document.getElementById("pairingInfo"),
      pairingCard: document.getElementById("pairingCard"),
      btnPair: document.getElementById("btnPair"),
      cover: document.getElementById("cover"),
      title: document.getElementById("title"),
      artist: document.getElementById("artist"),
      album: document.getElementById("album"),
      playbackState: document.getElementById("playbackState"),
      artistAvatar: document.getElementById("artistAvatar"),
      artistAvatarFallback: document.getElementById("artistAvatarFallback"),
      artistProfileName: document.getElementById("artistProfileName"),
      artistProfileType: document.getElementById("artistProfileType"),
      artistProfileSource: document.getElementById("artistProfileSource"),
      statCurrent: document.getElementById("statCurrent"),
      statDuration: document.getElementById("statDuration"),
      statQueuePos: document.getElementById("statQueuePos"),
      statProgress: document.getElementById("statProgress"),
      chipSpeed: document.getElementById("chipSpeed"),
      chipSource: document.getElementById("chipSource"),
      chipFavorite: document.getElementById("chipFavorite"),
      trackHistoryNote: document.getElementById("trackHistoryNote"),
      trackPlays: document.getElementById("trackPlays"),
      trackCompleted: document.getElementById("trackCompleted"),
      trackSkips: document.getElementById("trackSkips"),
      trackRetention: document.getElementById("trackRetention"),
      trackLastPlayed: document.getElementById("trackLastPlayed"),
      lyricsPanel: document.getElementById("lyricsPanel"),
      lyricsLanguage: document.getElementById("lyricsLanguage"),
      lyricsContent: document.getElementById("lyricsContent"),
      artistInsightCount: document.getElementById("artistInsightCount"),
      artistTracksByArtist: document.getElementById("artistTracksByArtist"),
      artistAlbumsCount: document.getElementById("artistAlbumsCount"),
      artistCompletedCount: document.getElementById("artistCompletedCount"),
      artistSkipCount: document.getElementById("artistSkipCount"),
      artistTotalDuration: document.getElementById("artistTotalDuration"),
      artistNextList: document.getElementById("artistNextList"),
      seekBar: document.getElementById("seekBar"),
      timeCurrent: document.getElementById("timeCurrent"),
      timeDuration: document.getElementById("timeDuration"),
      btnPrev: document.getElementById("btnPrev"),
      btnPlayPause: document.getElementById("btnPlayPause"),
      btnNext: document.getElementById("btnNext"),
      btnShuffle: document.getElementById("btnShuffle"),
      btnSeekBack: document.getElementById("btnSeekBack"),
      btnSeekFwd: document.getElementById("btnSeekFwd"),
      volumeBar: document.getElementById("volumeBar"),
      queueCount: document.getElementById("queueCount"),
      queuePanel: document.getElementById("queuePanel"),
      btnQueueCompact: document.getElementById("btnQueueCompact"),
      queueCompactLabel: document.getElementById("queueCompactLabel"),
      queueCarousel: document.getElementById("queueCarousel"),
      queueList: document.getElementById("queueList"),
      audioPlayer: document.getElementById("audioPlayer")
    };

    const detailTabs = Array.from(document.querySelectorAll("[data-detail-tab]"));
    const detailPanels = Array.from(document.querySelectorAll("[data-detail-panel]"));
    const lyricsTab = document.querySelector('[data-detail-tab="lyrics"]');

    function activateDetailTab(name) {
      const requested = String(name || "info");
      detailTabs.forEach((tab) => {
        tab.classList.toggle("is-active", tab.dataset.detailTab === requested);
      });
      detailPanels.forEach((panel) => {
        panel.classList.toggle("is-active", panel.dataset.detailPanel === requested);
      });
    }

    detailTabs.forEach((tab) => {
      tab.addEventListener("click", () => activateDetailTab(tab.dataset.detailTab));
    });

    const phoneQueueMedia = window.matchMedia("(max-width: 640px)");

    function isPhoneQueueLayout() {
      return phoneQueueMedia.matches;
    }

    function syncQueueCompactUi() {
      if (!el.queuePanel || !el.btnQueueCompact || !el.queueCompactLabel) return;

      const isPhone = isPhoneQueueLayout();
      const canToggle = isPhone && state.queue.length > 6;

      if (!isPhone || !canToggle) {
        el.queuePanel.classList.remove("queue-expanded");
      }

      const expanded = isPhone && canToggle && el.queuePanel.classList.contains("queue-expanded");
      el.btnQueueCompact.hidden = !canToggle;
      el.btnQueueCompact.setAttribute("aria-expanded", expanded ? "true" : "false");
      el.queueCompactLabel.textContent = expanded ? t("compactQueue") : t("expandQueue");
    }

    function centerActiveQueueItemOnPhone(behavior = "auto") {
      if (!isPhoneQueueLayout() || !el.queueList || !el.queuePanel) return;
      if (el.queuePanel.classList.contains("queue-expanded")) return;

      const activeItem = el.queueList.querySelector(".queue-item.active");
      if (!activeItem) return;

      const targetTop = Math.max(
        0,
        activeItem.offsetTop - (el.queueList.clientHeight / 2) + (activeItem.offsetHeight / 2)
      );
      el.queueList.scrollTo({ top: targetTop, behavior });
    }

    if (el.btnQueueCompact) {
      el.btnQueueCompact.addEventListener("click", () => {
        if (!isPhoneQueueLayout() || !el.queuePanel) return;
        const expanded = el.queuePanel.classList.toggle("queue-expanded");
        syncQueueCompactUi();
        if (!expanded) {
          requestAnimationFrame(() => centerActiveQueueItemOnPhone("smooth"));
        }
      });
    }

    if (typeof phoneQueueMedia.addEventListener === "function") {
      phoneQueueMedia.addEventListener("change", syncQueueCompactUi);
    } else if (typeof phoneQueueMedia.addListener === "function") {
      phoneQueueMedia.addListener(syncQueueCompactUi);
    }

    function formatMs(ms) {
      const totalSec = Math.max(0, Math.floor((ms || 0) / 1000));
      const m = Math.floor(totalSec / 60).toString().padStart(2, "0");
      const s = (totalSec % 60).toString().padStart(2, "0");
      return m + ":" + s;
    }

    function renderLyrics(track) {
      const lyrics = String(track?.lyrics || "").trim();
      const language = String(track?.lyricsLanguage || "").trim();
      const hasLyrics = lyrics.length > 0;
      el.lyricsPanel.hidden = !hasLyrics;
      if (lyricsTab) lyricsTab.hidden = !hasLyrics;
      if (!hasLyrics && el.lyricsPanel.classList.contains("is-active")) {
        activateDetailTab("info");
      }
      el.lyricsContent.textContent = hasLyrics ? lyrics : "";
      el.lyricsLanguage.textContent = hasLyrics && language ? language : "";
    }

    function formatSpeed(value) {
      const speed = clampPlaybackSpeed(value);
      return speed.toFixed(speed === Math.round(speed) ? 0 : 2) + "x";
    }

    function formatPercentRatio(value) {
      const n = Number(value);
      if (!Number.isFinite(n)) return "-";
      return Math.round(Math.max(0, Math.min(1, n)) * 100) + "%";
    }

    function formatCompactDate(timestampMs) {
      const raw = Number(timestampMs || 0);
      if (!Number.isFinite(raw) || raw <= 0) return "-";
      const date = new Date(raw);
      if (Number.isNaN(date.getTime())) return "-";
      const now = Date.now();
      const diffMs = Math.max(0, now - date.getTime());
      const minute = 60 * 1000;
      const hour = 60 * minute;
      const day = 24 * hour;
      if (diffMs < hour) {
        const mins = Math.max(1, Math.round(diffMs / minute));
        return mins + "m ago";
      }
      if (diffMs < day) {
        const hours = Math.max(1, Math.round(diffMs / hour));
        return hours + "h ago";
      }
      if (diffMs < 7 * day) {
        const days = Math.max(1, Math.round(diffMs / day));
        return days + "d ago";
      }
      return date.toLocaleDateString(undefined, { month: "short", day: "numeric" });
    }

    function clamp01(value) {
      const n = Number(value);
      if (!Number.isFinite(n)) return 1;
      return Math.max(0, Math.min(1, n));
    }

    function clampPlaybackSpeed(value) {
      const n = Number(value);
      if (!Number.isFinite(n) || n <= 0) return 1;
      return Math.max(0.25, Math.min(4, n));
    }

    function applyAudioPlaybackSpeed() {
      const safeSpeed = clampPlaybackSpeed(state.playback.speed);
      state.playback.speed = safeSpeed;
      if (Math.abs(Number(el.audioPlayer.playbackRate || 1) - safeSpeed) < 0.001) return;
      el.audioPlayer.playbackRate = safeSpeed;
    }

    function normalizedListenProgress(item) {
      const raw = Number(item?.avgListenProgress);
      if (!Number.isFinite(raw) || raw <= 0) return null;
      if (raw <= 1) return Math.max(0, Math.min(1, raw));
      if (raw <= 100) return Math.max(0, Math.min(1, raw / 100));
      return null;
    }

    function hasListenSample(item) {
      const plays = Number(item?.playCount || 0);
      const completed = Number(item?.fullListenCount || 0);
      const skips = Number(item?.skipCount || 0);
      return plays > 0 || completed > 0 || skips > 0 || normalizedListenProgress(item) != null;
    }

    function detectBrowserName(ua) {
      const raw = String(ua || "").toLowerCase();
      if (!raw) return "Browser";
      if (raw.includes("edg/")) return "Edge";
      if (raw.includes("opr/") || raw.includes("opera")) return "Opera";
      if (raw.includes("samsungbrowser")) return "Samsung Internet";
      if (raw.includes("chrome/") && !raw.includes("edg/") && !raw.includes("opr/")) {
        return "Chrome";
      }
      if (raw.includes("firefox/")) return "Firefox";
      if (raw.includes("safari/") && !raw.includes("chrome/")) return "Safari";
      return "Browser";
    }

    function detectPlatformName(ua) {
      const raw = String(ua || "").toLowerCase();
      if (!raw) return "";
      if (raw.includes("windows")) return "Windows";
      if (raw.includes("android")) return "Android";
      if (raw.includes("iphone") || raw.includes("ipad") || raw.includes("ipod")) return "iOS";
      if (raw.includes("mac os") || raw.includes("macintosh")) return "macOS";
      if (raw.includes("linux")) return "Linux";
      return "";
    }

    function buildReadableClientName() {
      const ua = navigator.userAgent || "";
      const browser = detectBrowserName(ua);
      const platform = detectPlatformName(ua);
      if (!platform) return browser;
      return browser + " · " + platform;
    }

    function authQuery() {
      if (!state.token) return "";
      return "?token=" + encodeURIComponent(state.token);
    }

    function withToken(path) {
      if (!state.token) return path;
      const sep = path.includes("?") ? "&" : "?";
      return path + sep + "token=" + encodeURIComponent(state.token);
    }

    function clearRemoteAudioPlayback() {
      try {
        el.audioPlayer.pause();
      } catch (_) {}

      if (el.audioPlayer.src) {
        el.audioPlayer.removeAttribute("src");
      }
      try {
        el.audioPlayer.load();
      } catch (_) {}

      try {
        el.audioPlayer.currentTime = 0;
      } catch (_) {}

      state.currentAudioSrc = "";
      state.sourceLoading = false;
      el.audioPlayer.onloadedmetadata = null;
    }

    function queueSignature(queue) {
      if (!Array.isArray(queue) || queue.length === 0) return "";
      return queue
        .map((item, index) => String(
          item?.id ||
          item?.localPath ||
          item?.playableUrl ||
          (item?.title ? item.title + "#" + index : index)
        ))
        .join("|");
    }

    function visibleQueueEntries(queue, activeIndex) {
      if (!Array.isArray(queue)) return [];
      if (queue.length <= MAX_RENDERED_QUEUE_ITEMS) {
        return queue.map((item, index) => ({ item, index }));
      }

      const safeIndex = Math.max(0, Math.min(queue.length - 1, Number(activeIndex || 0)));
      const before = 35;
      const after = MAX_RENDERED_QUEUE_ITEMS - before - 1;
      let start = Math.max(0, safeIndex - before);
      let end = Math.min(queue.length, safeIndex + after + 1);

      if (end - start < MAX_RENDERED_QUEUE_ITEMS) {
        start = Math.max(0, end - MAX_RENDERED_QUEUE_ITEMS);
        end = Math.min(queue.length, start + MAX_RENDERED_QUEUE_ITEMS);
      }

      const entries = [];
      for (let index = start; index < end; index++) {
        entries.push({ item: queue[index], index });
      }
      return entries;
    }

    function markQueueInteraction() {
      state.queueInteractionUntilMs = Date.now() + 1400;
    }

    function isQueueInteractionActive() {
      return Date.now() < state.queueInteractionUntilMs;
    }

    function lockSeekSync(windowMs = 1000) {
      state.seekSyncLockUntilMs = Date.now() + Math.max(200, Number(windowMs || 0));
    }

    function markSessionSyncNow() {
      state.sessionLastSyncAt = Date.now();
      state.syncUnstable = false;
    }

    function markWsMessageNow() {
      state.wsLastMessageAt = Date.now();
      state.syncUnstable = false;
    }

    function scheduleWsReconnect(delayMs) {
      if (state.wsReconnectTimer) return;
      const waitMs = Math.max(300, Number(delayMs || state.wsReconnectDelayMs || 1500));
      state.wsReconnectTimer = setTimeout(() => {
        state.wsReconnectTimer = null;
        if (!state.token) return;
        connectWs();
      }, waitMs);
    }

    function escapeHtml(value) {
      return String(value || "")
        .replaceAll("&", "&amp;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;")
        .replaceAll('"', "&quot;")
        .replaceAll("'", "&#39;");
    }

    function queueCoverUrl(item, index) {
      const raw = String(item?.coverUrl || "").trim();
      if (raw.startsWith("http://") || raw.startsWith("https://")) {
        return raw;
      }
      const itemId = String(item?.id || "").trim();
      if (state.token && itemId) {
        return withToken("/cover/item?itemId=" + encodeURIComponent(itemId));
      }
      if (state.token && index === state.currentQueueIndex) {
        return withToken("/cover/current");
      }
      return "";
    }

    function buildTrackInfoLine(track) {
      const source = String(track?.source || "").trim();
      const country = String(track?.country || "").trim();
      const parts = [];
      if (track?.variantRole === "instrumental") parts.push("Instrumental");
      if (track?.variantRole === "spatial8d") parts.push("8D");

      if (source) {
        parts.push(source);
      }
      if (country) {
        parts.push(country);
      }
      if (track?.isFavorite === true) {
        parts.push(t("favorite").toLowerCase());
      }

      return parts.length > 0 ? t("info") + ": " + parts.join(" · ") : t("info") + ": —";
    }

    function artistInitials(name) {
      const raw = String(name || "").trim();
      if (!raw) return "--";
      const words = raw.split(/\\s+/).filter(Boolean);
      if (words.length === 1) {
        return words[0].slice(0, 2).toUpperCase();
      }
      return (String(words[0][0] || "") + String(words[1][0] || "")).toUpperCase();
    }

    function inferArtistType(name) {
      const normalized = String(name || "").trim().toLowerCase();
      if (!normalized) return t("unknown");

      const collabHints = [" feat ", " ft ", " x ", " & ", ",", " and ", " y ", " con "];
      for (const hint of collabHints) {
        if (normalized.includes(hint)) {
          return t("artistKindCollab");
        }
      }

      const groupHints = [
        " band",
        " banda",
        " orchestra",
        " orquesta",
        " group",
        " crew",
        " ensemble",
        " trio",
        " quartet",
        " quintet",
        " boys",
        " girls",
        " brothers",
        " sisters"
      ];
      for (const hint of groupHints) {
        if (normalized.includes(hint)) {
          return t("artistKindBand");
        }
      }

      return t("artistKindSoloist");
    }

    function formatArtistKind(kind) {
      const value = String(kind || "").trim().toLowerCase();
      if (value === "band") return t("artistKindBand");
      if (value === "singer") return t("artistKindSoloist");
      return "";
    }

    function flagFromCountryCode(rawCode) {
      const code = String(rawCode || "").trim().toUpperCase();
      if (!/^[A-Z]{2}\$/.test(code)) return "";
      const first = 127397 + code.charCodeAt(0);
      const second = 127397 + code.charCodeAt(1);
      return String.fromCodePoint(first, second);
    }

    function cleanArtistName(raw) {
      let value = String(raw || "").trim();
      if (!value) return "";

      const edgeJunkPattern = /^[\\s\\-:;,.()[\\]{}]+|[\\s\\-:;,.()[\\]{}]+\$/g;
      while (true) {
        const next = value.replace(edgeJunkPattern, "").trim();
        if (next === value || !next) break;
        value = next;
      }

      return value.replace(/\\s+/g, " ").trim();
    }

    function normalizeArtistKey(raw) {
      const cleaned = cleanArtistName(raw).toLowerCase();
      return cleaned || "unknown";
    }

    function dedupeArtistNames(names) {
      const out = [];
      const seen = new Set();
      for (const raw of names || []) {
        const cleaned = cleanArtistName(raw);
        const key = normalizeArtistKey(cleaned);
        if (!cleaned || key === "unknown" || seen.has(key)) continue;
        seen.add(key);
        out.push(cleaned);
      }
      return out;
    }

    function parseArtistCredits(rawArtist) {
      const raw = String(rawArtist || "").trim();
      if (!raw) {
        return { rawArtist: "", primaryArtist: "", collaborators: [], allArtists: [] };
      }

      const markerPattern = /\\b(feat\\.?|ft\\.?|featuring|with)\\b/i;
      const markerGlobalPattern = /\\b(feat\\.?|ft\\.?|featuring|with)\\b/gi;
      const collaboratorSeparatorPattern = /\\s*,\\s*|\\s*&\\s*|\\s+[xX]\\s+/;
      const match = raw.match(markerPattern);

      if (!match) {
        const primary = cleanArtistName(raw);
        return {
          rawArtist: raw,
          primaryArtist: primary,
          collaborators: [],
          allArtists: dedupeArtistNames([primary]),
        };
      }

      const markerText = String(match[0] || "");
      const markerIndex = Number(match.index || 0);
      const primary = cleanArtistName(raw.substring(0, markerIndex));
      let rawCollaborators = raw.substring(markerIndex + markerText.length).trim();
      rawCollaborators = rawCollaborators.replace(markerGlobalPattern, ",");

      const collaborators = dedupeArtistNames(
        rawCollaborators
          .split(collaboratorSeparatorPattern)
          .map((name) => cleanArtistName(name))
          .filter((name) => name.length > 0)
      );

      return {
        rawArtist: raw,
        primaryArtist: primary,
        collaborators: collaborators,
        allArtists: dedupeArtistNames([primary].concat(collaborators)),
      };
    }

    function resolveFocusedArtistKey(track) {
      const profileKey = normalizeArtistKey(track?.artistProfile?.key || "");
      if (profileKey !== "unknown") return profileKey;

      const parsed = parseArtistCredits(track?.artist || "");
      const primaryKey = normalizeArtistKey(parsed.primaryArtist);
      if (primaryKey !== "unknown") return primaryKey;

      for (const name of parsed.allArtists) {
        const key = normalizeArtistKey(name);
        if (key !== "unknown") return key;
      }

      const fallback = normalizeArtistKey(track?.artist || "");
      return fallback !== "unknown" ? fallback : "";
    }

    function matchArtistRelation(track, focusedArtistKey) {
      const target = normalizeArtistKey(focusedArtistKey || "");
      if (!target || target === "unknown") {
        return { matched: false, isPrimary: false, isCollaboration: false };
      }

      const parsed = parseArtistCredits(track?.artist || "");
      const primaryKey = normalizeArtistKey(parsed.primaryArtist);
      const allKeys = new Set();

      for (const name of parsed.allArtists) {
        const key = normalizeArtistKey(name);
        if (key !== "unknown") allKeys.add(key);
      }

      const profileKey = normalizeArtistKey(track?.artistProfile?.key || "");
      if (profileKey !== "unknown") {
        allKeys.add(profileKey);
      }

      const matched = allKeys.has(target);
      if (!matched) {
        return { matched: false, isPrimary: false, isCollaboration: false };
      }

      let isPrimary = false;
      if (primaryKey !== "unknown") {
        isPrimary = primaryKey === target;
      } else if (profileKey !== "unknown" && profileKey === target) {
        isPrimary = true;
      }

      return {
        matched: true,
        isPrimary: isPrimary,
        isCollaboration: !isPrimary,
      };
    }

    function tracksCountForArtist(track) {
      const focusedArtistKey = resolveFocusedArtistKey(track);
      if (!focusedArtistKey || !Array.isArray(state.queue)) return 0;
      let count = 0;
      for (const item of state.queue) {
        const relation = matchArtistRelation(item, focusedArtistKey);
        if (relation.matched) {
          count += 1;
        }
      }
      return count;
    }

    function pickArtistAvatar(track) {
      const profile = track?.artistProfile || null;
      const hasProfile = !!profile;
      const profileKey = String(profile?.key || "").trim();
      if (state.token && profileKey) {
        return withToken("/cover/artist?artistKey=" + encodeURIComponent(profileKey));
      }

      const profileThumb = String(profile?.thumbnail || "").trim();
      if (profileThumb) return profileThumb;

      // If we do have artist profile data but no valid profile image, prefer
      // initials fallback instead of using track cover (which is often album art).
      if (hasProfile) return "";

      const currentTrackId = String(track?.id || "").trim();
      if (state.token && currentTrackId) {
        return withToken("/cover/item?itemId=" + encodeURIComponent(currentTrackId));
      }

      const currentCover = String(track?.coverUrl || "").trim();
      if (currentCover) return currentCover;

      const artist = String(track?.artist || "").trim().toLowerCase();
      if (!artist) return "";
      if (!Array.isArray(state.queue)) return "";

      for (const item of state.queue) {
        const itemArtist = String(item?.artist || "").trim().toLowerCase();
        if (itemArtist !== artist) continue;
        const itemId = String(item?.id || "").trim();
        if (state.token && itemId) {
          return withToken("/cover/item?itemId=" + encodeURIComponent(itemId));
        }
        const candidate = String(item?.coverUrl || "").trim();
        if (candidate) return candidate;
      }
      return "";
    }

    function renderArtistProfile(track) {
      const profile = track?.artistProfile || null;
      const artistName = String(profile?.displayName || track?.artist || "").trim() || t("unknownArtist");
      const source = String(track?.source || "").trim();
      const origin = String(track?.origin || "").trim();
      const sourceLabel = source || origin
        ? (origin && source && origin.toLowerCase() !== source.toLowerCase()
            ? source + " · " + origin
            : source || origin)
        : "—";
      const kindFromProfile = formatArtistKind(profile?.kind);
      const hasProfileKind = kindFromProfile.length > 0;
      const typeLine = hasProfileKind
        ? kindFromProfile
        : t("estimatedType") + ": " + inferArtistType(artistName);
      const flag = flagFromCountryCode(profile?.countryCode);
      const countryName = String(profile?.country || track?.country || "").trim();
      const typeWithCountry = (hasProfileKind && (flag || countryName))
        ? (typeLine + " - " + [flag, countryName].filter(Boolean).join(" "))
        : typeLine;

      const trackCountRaw = Number(profile?.trackCount);
      const profileTrackCount = Number.isFinite(trackCountRaw)
        ? Math.max(0, Math.floor(trackCountRaw))
        : 0;
      const tracksByArtist = profileTrackCount > 0
        ? profileTrackCount
        : tracksCountForArtist(track);
      const memberCountRaw = Number(profile?.memberCount);
      const memberCount = Number.isFinite(memberCountRaw) ? Math.max(0, Math.floor(memberCountRaw)) : 0;
      const detailParts = [];
      if (tracksByArtist > 0) detailParts.push(tracksByArtist + " " + plural(tracksByArtist, "track", "tracks"));
      if (String(profile?.kind || "").toLowerCase() === "band" && memberCount > 0) {
        detailParts.push(memberCount + " " + plural(memberCount, "member", "members"));
      }
      const secondaryLine = detailParts.length > 0
        ? detailParts.join(" · ")
        : t("source") + ": " + sourceLabel;

      el.artistProfileName.textContent = artistName;
      el.artistProfileType.textContent = typeWithCountry;
      el.artistProfileSource.textContent = secondaryLine;

      const avatarSrc = pickArtistAvatar(track);
      el.artistAvatarFallback.textContent = artistInitials(artistName);

      if (!avatarSrc) {
        el.artistAvatar.removeAttribute("src");
        el.artistAvatar.style.display = "none";
        el.artistAvatarFallback.style.display = "grid";
        return;
      }

      el.artistAvatar.onerror = () => {
        el.artistAvatar.removeAttribute("src");
        el.artistAvatar.style.display = "none";
        el.artistAvatarFallback.style.display = "grid";
      };
      el.artistAvatar.onload = () => {
        el.artistAvatar.style.display = "block";
        el.artistAvatarFallback.style.display = "none";
      };

      if (el.artistAvatar.getAttribute("src") !== avatarSrc) el.artistAvatar.src = avatarSrc;
      el.artistAvatar.style.display = "block";
    }

    function setToken(token) {
      state.token = (token || "").trim();
      if (state.token) {
        sessionStorage.setItem("listenfy_local_token", state.token);
        markSessionSyncNow();
      } else {
        sessionStorage.removeItem("listenfy_local_token");
        state.socket?.close();
        state.queue = [];
        state.queueVersion += 1;
        renderQueue();
        state.wsConnected = false;
        state.syncUnstable = false;
        state.sessionLastSyncAt = 0;
        state.wsLastMessageAt = 0;
        state.currentTrackId = "";
        state.currentCoverSrc = "";
        state.playback.shuffleEnabled = false;
        clearRemoteAudioPlayback();
      }
      updatePairingUi();
      updateShuffleButton();
    }

    function stopPairingPolling() {
      if (state.pairingPollTimer) {
        clearInterval(state.pairingPollTimer);
        state.pairingPollTimer = null;
      }
      state.pairingPollTicks = 0;
    }

    async function checkPairingStatus() {
      if (state.pairingCheckPending || !state.pairingReceipt) return;
      state.pairingCheckPending = true;
      try {
        const response = await api("/api/pairing/status?clientId=" + encodeURIComponent(state.clientId), "GET", undefined, { "X-Listenfy-Pairing": state.pairingReceipt });
        if (response?.status === "already_paired" && response?.token) {
          setToken(response.token);
          state.waitingPairing = false;
          el.pairingInfo.textContent = t("pairingApproved");
          stopPairingPolling();
          if (response?.session) {
            renderNowPlaying(response.session);
          } else {
            await loadSession();
          }
          state.pairingReceipt = "";
          sessionStorage.removeItem("listenfy_pairing_receipt");
          connectWs();
        } else if (response?.status === "not_paired") {
          state.waitingPairing = false;
          state.pairingReceipt = "";
          sessionStorage.removeItem("listenfy_pairing_receipt");
          stopPairingPolling();
          el.pairingInfo.textContent = t("sessionEnded");
        }
      } catch (_) {
        // A later poll may recover a transient network error.
      } finally {
        state.pairingCheckPending = false;
        updatePairingUi();
      }
    }

    function startPairingPolling() {
      if (state.pairingPollTimer) return;
      state.pairingPollTicks = 0;
      state.pairingPollTimer = setInterval(() => {
        if (!state.waitingPairing || state.token) {
          stopPairingPolling();
          return;
        }
        state.pairingPollTicks += 1;
        if (state.pairingPollTicks >= 10) {
          el.pairingInfo.textContent = t("waitingApprovalPhone");
        }
        checkPairingStatus();
      }, 1500);
    }

    function updatePairingUi() {
      if (state.token) {
        el.pairingState.className = "status-pill paired";
        if (state.syncUnstable) {
          el.pairingState.textContent = t("pairedSyncing");
        } else if (state.wsConnected) {
          el.pairingState.textContent = t("pairedLive");
        } else {
          el.pairingState.textContent = t("pairedReconnecting");
        }
        el.pairingCard.style.display = "none";
      } else {
        el.pairingState.className = "status-pill unpaired";
        el.pairingState.textContent = state.waitingPairing ? t("waitingApproval") : t("notPaired");
        el.pairingCard.style.display = "grid";
      }
    }

    function updatePlaybackStateBadge() {
      if (state.playback.isBuffering) {
        el.playbackState.textContent = t("buffering");
        return;
      }
      if (state.playback.isPlaying) {
        el.playbackState.textContent = t("playing");
        return;
      }
      el.playbackState.textContent = t("paused");
    }

    function updateShuffleButton() {
      const enabled = !!state.playback.shuffleEnabled;
      el.btnShuffle.textContent = enabled ? t("shuffleOn") : t("shuffleOff");
      el.btnShuffle.classList.toggle("btn-toggle-active", enabled);
    }

    function updateTrackChips(track) {
      el.chipSpeed.textContent = formatSpeed(state.playback.speed);

      const source = String(track?.source || track?.origin || "").trim();
      const format = String(track?.format || "").trim();
      const sourceParts = [];
      if (source) sourceParts.push(source);
      if (format) sourceParts.push(format.toUpperCase());
      el.chipSource.textContent = sourceParts.length > 0
        ? t("source") + ": " + sourceParts.join(" · ")
        : t("source") + ": —";

      const isFavorite = track?.isFavorite === true;
      el.chipFavorite.textContent = isFavorite ? t("favorite") : t("notFavorite");
      el.chipFavorite.classList.toggle("strong", isFavorite);
    }

    function updateTrackHistory(track) {
      const plays = Math.max(0, Math.floor(Number(track?.playCount || 0)));
      const completed = Math.max(0, Math.floor(Number(track?.fullListenCount || 0)));
      const skips = Math.max(0, Math.floor(Number(track?.skipCount || 0)));
      const retention = normalizedListenProgress(track);
      const hasHistory = hasListenSample(track);

      el.trackPlays.textContent = String(plays);
      el.trackCompleted.textContent = String(completed);
      el.trackSkips.textContent = String(skips);
      el.trackRetention.textContent = retention == null ? "-" : formatPercentRatio(retention);
      el.trackLastPlayed.textContent = formatCompactDate(track?.lastPlayedAt);
      el.trackHistoryNote.textContent = hasHistory ? t("realAppData") : t("noHistoryYet");
    }

    function updateStatCards() {
      el.statCurrent.textContent = formatMs(state.playback.positionMs);
      el.statDuration.textContent = formatMs(state.playback.durationMs);
      const progress = state.playback.durationMs > 0
        ? state.playback.positionMs / state.playback.durationMs
        : 0;
      el.statProgress.textContent = formatPercentRatio(progress);
      if (state.queue.length > 0) {
        const pos = state.currentQueueIndex + 1;
        el.statQueuePos.textContent = pos + " / " + state.queue.length;
      } else {
        el.statQueuePos.textContent = "-";
      }
    }

    function renderArtistInsights(track) {
      const artist = String(track?.artist || "").trim();
      const queue = Array.isArray(state.queue) ? state.queue : [];
      const focusedArtistKey = resolveFocusedArtistKey(track);

      if (!artist || !focusedArtistKey) {
        el.artistInsightCount.textContent = "-";
        el.artistTracksByArtist.textContent = "0";
        el.artistAlbumsCount.textContent = "0";
        el.artistCompletedCount.textContent = "0";
        el.artistSkipCount.textContent = "0";
        el.artistTotalDuration.textContent = "-";
        el.artistNextList.innerHTML = "<li class=\\"artist-next-empty\\">" + escapeHtml(t("noArtistInfoForTrack")) + "</li>";
        return;
      }

      const sameArtistEntries = [];
      queue.forEach((item, index) => {
        const relation = matchArtistRelation(item, focusedArtistKey);
        if (relation.matched) {
          sameArtistEntries.push({ item, index, relation });
        }
      });

      let totalPlays = 0;
      let totalCompleted = 0;
      let totalSkips = 0;
      let totalCompletion = 0;
      let completionSamples = 0;
      let favoriteCount = 0;
      const sourceSet = new Set();
      for (const entry of sameArtistEntries) {
        totalPlays += Number(entry.item?.playCount || 0);
        totalCompleted += Number(entry.item?.fullListenCount || 0);
        totalSkips += Number(entry.item?.skipCount || 0);
        const completion = normalizedListenProgress(entry.item);
        if (hasListenSample(entry.item) && completion != null) {
          totalCompletion += completion;
          completionSamples += 1;
        }
        if (entry.item?.isFavorite === true) favoriteCount += 1;
        const source = String(entry.item?.source || "").trim().toLowerCase();
        if (source) sourceSet.add(source);
      }

      const avgCompletion = completionSamples > 0 ? (totalCompletion / completionSamples) : null;
      const sourceLabel = sourceSet.size > 0
        ? Array.from(sourceSet).join(" / ")
        : t("unknownSource");

      el.artistInsightCount.textContent = sameArtistEntries.length + " " + plural(sameArtistEntries.length, "track", "tracks") + " · " + favoriteCount + " " + t("favShort") + " · " + sourceLabel;
      el.artistTracksByArtist.textContent = String(sameArtistEntries.length);
      el.artistAlbumsCount.textContent = String(totalPlays);
      el.artistCompletedCount.textContent = String(totalCompleted);
      el.artistSkipCount.textContent = String(totalSkips);
      el.artistTotalDuration.textContent = avgCompletion == null
        ? "-"
        : formatPercentRatio(avgCompletion);

      const upcoming = sameArtistEntries
        .filter((entry) => entry.index > state.currentQueueIndex)
        .slice(0, 4);

      el.artistNextList.innerHTML = "";
      if (upcoming.length === 0) {
        const emptyItem = document.createElement("li");
        emptyItem.className = "artist-next-empty";
        emptyItem.textContent = t("noMoreArtistTracks");
        el.artistNextList.appendChild(emptyItem);
        return;
      }

      upcoming.forEach(({ item, index, relation }) => {
        const title = escapeHtml(item?.title || t("unknown"));
        const source = escapeHtml(String(item?.source || "").trim() || t("unknownSource"));
        const plays = Number(item?.playCount || 0);
        const completion = normalizedListenProgress(item);
        const roleLabel = relation?.isCollaboration ? t("roleCollab") : t("rolePrincipal");
        const completionLabel = completion == null ? t("noRetention") : formatPercentRatio(completion);
        const subtitle = source + " · " + escapeHtml(roleLabel) + " · " + plays + " " + escapeHtml(plural(plays, "playUnit", "playsUnit")) + " · " + escapeHtml(completionLabel);
        const li = document.createElement("li");
        li.className = "artist-next-item";
        li.innerHTML =
          "<div class=\\"artist-next-main\\">"
          + "<span class=\\"artist-next-index\\">#" + String(index + 1) + "</span>"
          + "<div class=\\"artist-next-text\\">"
          + "<div class=\\"artist-next-title\\">" + title + "</div>"
          + "<div class=\\"artist-next-sub\\">" + subtitle + "</div>"
          + "</div>"
          + "</div>"
          + "<span class=\\"artist-next-time\\">" + formatMs(item?.durationMs || 0) + "</span>";
        li.addEventListener("click", () => requestPlayQueueItem(item, index));
        el.artistNextList.appendChild(li);
      });
    }

    function renderNowPlaying(payload) {
      markSessionSyncNow();
      const previousTrackId = state.currentTrackId;
      const queue = payload?.queue || state.queue || [];
      const queueIndex = Number(payload?.currentQueueIndex ?? state.currentQueueIndex ?? 0);
      const normalizedQueueIndex = Math.max(0, Math.min(Math.max(queue.length - 1, 0), queueIndex));
      const queueTrack = queue.length > 0 ? queue[normalizedQueueIndex] : null;
      const track = Object.hasOwn(payload || {}, "track") ? payload.track : (queueTrack || null);
      const playback = payload?.playback || {};
      const nextTrackId = track?.id || "";
      const sameTrack = previousTrackId && nextTrackId && previousTrackId === nextTrackId;
      const previousPos = Number(state.playback.positionMs || 0);
      const incomingPosRaw = Number(playback.positionMs);
      const incomingPos = Number.isFinite(incomingPosRaw)
        ? Math.max(0, Math.floor(incomingPosRaw))
        : 0;
      const remoteSeekDetected = sameTrack && Math.abs(incomingPos - previousPos) > 1200;

      state.playback = {
        positionMs: incomingPos,
        durationMs: playback.durationMs || 0,
        isPlaying: !!playback.isPlaying,
        isBuffering: !!playback.isBuffering,
        speed: typeof playback.speed === "number"
          ? clampPlaybackSpeed(playback.speed)
          : clampPlaybackSpeed(state.playback.speed),
        volume: typeof playback.volume === "number" ? playback.volume : 1,
        shuffleEnabled: typeof playback.shuffleEnabled === "boolean"
          ? playback.shuffleEnabled
          : !!state.playback.shuffleEnabled
      };
      if (Array.isArray(payload?.queue)) state.queueVersion += 1;
      state.queue = queue;
      state.currentQueueIndex = normalizedQueueIndex;
      state.currentTrackId = nextTrackId;
      state.currentVariantId = String(track?.variantId || "");

      el.title.textContent = track?.title || t("noTrack");
      el.artist.textContent = track?.artist || "—";
      el.album.textContent = buildTrackInfoLine(track);
      renderLyrics(track);
      renderArtistProfile(track);
      renderArtistInsights(track);

      const remoteCover = String(track?.coverUrl || "").trim();
      const coverFromServer = state.currentTrackId
        ? withToken("/cover/item?itemId=" + encodeURIComponent(state.currentTrackId))
        : "";
      const nextCoverSrc = coverFromServer || remoteCover || "";
      if (state.currentCoverSrc !== nextCoverSrc) {
        state.currentCoverSrc = nextCoverSrc;
        el.cover.src = nextCoverSrc;
      }

      el.timeCurrent.textContent = formatMs(state.playback.positionMs);
      el.timeDuration.textContent = formatMs(state.playback.durationMs);
      el.seekBar.value = state.playback.durationMs > 0
        ? Math.floor((state.playback.positionMs / state.playback.durationMs) * 1000)
        : 0;
      const safeVolume = clamp01(state.playback.volume ?? 1);
      el.volumeBar.value = Math.round(safeVolume * 100);
      el.audioPlayer.volume = safeVolume;
      applyAudioPlaybackSpeed();
      el.btnPlayPause.textContent = state.playback.isPlaying ? t("pause") : t("play");
      updateShuffleButton();
      updateTrackChips(track);
      updateTrackHistory(track);

      updatePlaybackStateBadge();
      updateStatCards();
      renderQueue();
      if (!state.currentTrackId) {
        clearRemoteAudioPlayback();
      } else {
        refreshAudioSource();
      }
      if (remoteSeekDetected) {
        lockSeekSync(1300);
      }
      syncAudioClockWithState(remoteSeekDetected);
    }

    function renderQueue() {
      const signature = state.queueVersion;
      const queueChanged = signature !== state.lastRenderedQueueSignature;
      const indexChanged = state.currentQueueIndex !== state.lastRenderedQueueIndex;
      const trackChanged = state.currentTrackId !== state.lastRenderedTrackId;

      const countLabel = state.queue.length + " " + plural(state.queue.length, "track", "tracks");
      el.queueCount.textContent = countLabel;
      syncQueueCompactUi();

      if (!queueChanged && !indexChanged && !trackChanged) {
        return;
      }

      const previousScrollLeft = el.queueCarousel.scrollLeft;
      el.queueCarousel.innerHTML = "";
      el.queueList.innerHTML = "";

      const visibleEntries = visibleQueueEntries(state.queue, state.currentQueueIndex);

      if (visibleEntries.length < state.queue.length) {
        const head = document.createElement("li");
        head.className = "queue-item";
        head.innerHTML =
          "<div class=\\"queue-item-main\\">"
          + "<span class=\\"queue-item-index\\">" + state.queue.length + "</span>"
          + "<div class=\\"queue-item-text\\">"
          + "<div class=\\"queue-item-title\\">" + escapeHtml(t("largeQueueOptimized")) + "</div>"
          + "<div class=\\"queue-item-sub\\">" + escapeHtml(t("showingAroundCurrent")) + "</div>"
          + "</div>"
          + "</div>";
        el.queueList.appendChild(head);
      }

      visibleEntries.forEach((entry) => {
        const item = entry.item;
        const i = entry.index;
        const isActive = i === state.currentQueueIndex;
        const title = escapeHtml(item.title || t("unknown"));
        const artist = escapeHtml(item.artist || "—");
        const coverUrl = escapeHtml(queueCoverUrl(item, i));

        const card = document.createElement("article");
        card.className = "queue-cover-item" + (isActive ? " active" : "");
        card.setAttribute("role", "button");
        card.setAttribute("tabindex", "0");
        card.innerHTML =
          "<div class=\\"queue-cover-wrap\\">"
          + (coverUrl
            ? "<img class=\\"queue-cover\\" src=\\"" + coverUrl + "\\" alt=\\"" + title + "\\" loading=\\"lazy\\">"
            : "<div class=\\"queue-cover-fallback\\">+</div>")
          + "</div>"
          + "<div class=\\"queue-cover-meta\\">"
          + "<div class=\\"queue-cover-title\\">" + title + "</div>"
          + "<div class=\\"queue-cover-artist\\">" + artist + "</div>"
          + "</div>";
        card.addEventListener("click", () => requestPlayQueueItem(item, i));
        card.addEventListener("keydown", (event) => {
          if (event.key === "Enter" || event.key === " ") {
            event.preventDefault();
            requestPlayQueueItem(item, i);
          }
        });

        const img = card.querySelector("img");
        if (img) {
          img.onerror = () => {
            img.remove();
            const fallback = document.createElement("div");
            fallback.className = "queue-cover-fallback";
            fallback.textContent = "+";
            card.querySelector(".queue-cover-wrap")?.appendChild(fallback);
          };
        }
        el.queueCarousel.appendChild(card);

        const li = document.createElement("li");
        li.className = "queue-item" + (isActive ? " active" : "");
        const trackNumber = String(i + 1).padStart(2, "0");
        const subtitle = artist;
        li.innerHTML =
          "<div class=\\"queue-item-main\\">"
          + "<span class=\\"queue-item-index\\">" + trackNumber + "</span>"
          + "<div class=\\"queue-item-text\\">"
          + "<div class=\\"queue-item-title\\">" + title + "</div>"
          + "<div class=\\"queue-item-sub\\">" + subtitle + "</div>"
          + "</div>"
          + "</div>"
          + "<span class=\\"queue-item-time\\">" + formatMs(item.durationMs || 0) + "</span>";
        li.addEventListener("click", () => requestPlayQueueItem(item, i));
        el.queueList.appendChild(li);
      });

      if (!queueChanged) {
        el.queueCarousel.scrollLeft = previousScrollLeft;
      }

      const activeCard = el.queueCarousel.querySelector(".queue-cover-item.active");
      const shouldAutoCenter =
        activeCard &&
        (queueChanged || trackChanged || indexChanged) &&
        !isQueueInteractionActive();
      if (shouldAutoCenter) {
        activeCard.scrollIntoView({ inline: "center", block: "nearest", behavior: "smooth" });
      }

      if ((queueChanged || trackChanged || indexChanged) && !isQueueInteractionActive()) {
        requestAnimationFrame(() => centerActiveQueueItemOnPhone("smooth"));
      }

      state.lastRenderedQueueSignature = signature;
      state.lastRenderedQueueIndex = state.currentQueueIndex;
      state.lastRenderedTrackId = state.currentTrackId;
    }

    function refreshAudioSource() {
      if (!state.token || !state.currentTrackId) {
        clearRemoteAudioPlayback();
        return;
      }
      const src = withToken("/stream/current?track=" + encodeURIComponent(state.currentTrackId)
        + "&variant=" + encodeURIComponent(state.currentVariantId));
      if (state.currentAudioSrc !== src) {
        state.currentAudioSrc = src;
        state.sourceLoading = true;
        el.audioPlayer.onloadedmetadata = () => {
          if (state.currentAudioSrc !== src) return;
          state.sourceLoading = false;
          // The phone owns the position, including resets when changing variant.
          syncAudioClockWithState(true);
          applyAudioPlaybackSpeed();
          if (state.playback.isPlaying) el.audioPlayer.play().catch(() => {});
          else el.audioPlayer.pause();
        };
        el.audioPlayer.src = src;
        return;
      }
      if (state.sourceLoading) return;
      applyAudioPlaybackSpeed();
      syncAudioClockWithState(false);
      if (state.playback.isPlaying) {
        el.audioPlayer.play().catch(() => {});
      } else {
        el.audioPlayer.pause();
      }
    }

    async function api(path, method = "GET", body, extraHeaders = {}) {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 8000);
      try {
        const res = await fetch(path, {
          method,
          cache: "no-store",
          referrerPolicy: "no-referrer",
          signal: controller.signal,
          headers: {
            "Content-Type": "application/json",
            ...(state.token ? { Authorization: "Bearer " + state.token } : {}),
            ...extraHeaders
          },
          body: body ? JSON.stringify(body) : undefined
        });
        if (!res.ok) {
          const err = new Error("HTTP " + res.status);
          err.status = res.status;
          throw err;
        }
        return await res.json();
      } finally {
        clearTimeout(timeout);
      }
    }

    async function requestPairing() {
      if (state.waitingPairing) return;
      state.waitingPairing = true;
      updatePairingUi();
      el.pairingInfo.textContent = t("sendingRequest");
      try {
        if (!state.pairingReceipt) {
          // An expired/rejected identity cannot be used to claim an existing session.
          state.clientId = "web-" + Array.from(crypto.getRandomValues(new Uint8Array(16)),
            (n) => n.toString(16).padStart(2, "0")).join("");
          sessionStorage.setItem("listenfy_local_client_id", state.clientId);
          const response = await api("/api/pairing/request", "POST", {
            clientId: state.clientId,
            clientName: buildReadableClientName()
          });
          state.pairingReceipt = response.requestId || "";
          sessionStorage.setItem("listenfy_pairing_receipt", state.pairingReceipt);
        }
        el.pairingInfo.textContent = t("requestSent");
        startPairingPolling();
        checkPairingStatus();
      } catch (_) {
        el.pairingInfo.textContent = t("couldNotRequestPairing");
        state.waitingPairing = false;
      }
      updatePairingUi();
    }

    async function loadSession() {
      if (!state.token || state.sessionLoadPending) return;
      state.sessionLoadPending = true;
      try {
        renderNowPlaying(await api("/api/session"));
        state.privatePlayback = false;
      } catch (e) {
        const status = Number(e?.status || 0);
        if (status === 423) {
          state.privatePlayback = true;
          clearRemoteAudioPlayback();
        } else if (status === 401 || status === 403) {
          setToken("");
          state.waitingPairing = false;
          stopPairingPolling();
          el.pairingInfo.textContent = t("sessionExpired");
        } else {
          state.syncUnstable = true;
          el.pairingInfo.textContent = t("syncUnstable");
          scheduleWsReconnect(500);
        }
        updatePairingUi();
      } finally {
        state.sessionLoadPending = false;
      }
    }

    function connectWs() {
      if (!state.token) return;
      if (state.wsReconnectTimer) {
        clearTimeout(state.wsReconnectTimer);
        state.wsReconnectTimer = null;
      }

      if (state.socket) {
        try {
          state.socket.onopen = null;
          state.socket.onmessage = null;
          state.socket.onclose = null;
          state.socket.onerror = null;
          state.socket.close();
        } catch (_) {}
        state.socket = null;
      }

      const proto = location.protocol === "https:" ? "wss" : "ws";
      const qs = new URLSearchParams();
      qs.set("clientId", state.clientId);
      if (state.token) qs.set("token", state.token);
      const url = proto + "://" + location.host + "/ws?" + qs.toString();
      state.socket = new WebSocket(url);
      state.wsConnected = false;
      updatePairingUi();

      state.socket.onopen = () => {
        state.wsConnected = true;
        state.wsReconnectDelayMs = 1500;
        markWsMessageNow();
        updatePairingUi();
        // The server sends the initial snapshot after the authenticated upgrade.
      };

      state.socket.onmessage = (evt) => {
        let msg = null;
        try {
          msg = JSON.parse(evt.data);
        } catch (_) {
          return;
        }
        if (!msg || !msg.type) return;
        markWsMessageNow();

        switch (msg.type) {
          case "pairingRequired":
            setToken("");
            state.waitingPairing = false;
            stopPairingPolling();
            el.pairingInfo.textContent = t("sessionEnded");
            updatePairingUi();
            break;
          case "pairingApproved":
            if (msg.payload?.token) {
              setToken(msg.payload.token);
            }
            state.waitingPairing = false;
            stopPairingPolling();
            updatePairingUi();
            loadSession();
            break;
          case "pairingRejected":
            state.waitingPairing = false;
            stopPairingPolling();
            el.pairingInfo.textContent = t("pairingRejected");
            updatePairingUi();
            break;
          case "sessionRevoked":
            setToken("");
            state.waitingPairing = false;
            stopPairingPolling();
            el.pairingInfo.textContent = t("sessionRevoked");
            updatePairingUi();
            break;
          case "privatePlaybackLocked":
            state.privatePlayback = true;
            clearRemoteAudioPlayback();
            break;
          case "currentTrackChanged":
          case "playbackStateChanged":
          case "queueChanged":
            state.privatePlayback = false;
            renderNowPlaying(msg.payload || {});
            break;
          case "progressUpdated":
            if (msg.payload) {
              const previousPos = Number(state.playback.positionMs || 0);
              const incomingPosRaw = Number(msg.payload.positionMs);
              const incomingPos = Number.isFinite(incomingPosRaw)
                ? Math.max(0, Math.floor(incomingPosRaw))
                : previousPos;
              const remoteSeekDetected = Math.abs(incomingPos - previousPos) > 1200;
              state.playback.positionMs = incomingPos;
              markSessionSyncNow();
              state.playback.durationMs = msg.payload.durationMs || 0;
              state.playback.isPlaying = !!msg.payload.isPlaying;
              state.playback.isBuffering = !!msg.payload.isBuffering;
              if (typeof msg.payload.speed === "number") {
                state.playback.speed = clampPlaybackSpeed(msg.payload.speed);
              }
              if (typeof msg.payload.shuffleEnabled === "boolean") {
                state.playback.shuffleEnabled = msg.payload.shuffleEnabled;
              }
              applyAudioPlaybackSpeed();
              el.chipSpeed.textContent = formatSpeed(state.playback.speed);
              el.timeCurrent.textContent = formatMs(state.playback.positionMs);
              el.timeDuration.textContent = formatMs(state.playback.durationMs);
              el.seekBar.value = state.playback.durationMs > 0
                ? Math.floor((state.playback.positionMs / state.playback.durationMs) * 1000)
                : 0;
              el.btnPlayPause.textContent = state.playback.isPlaying ? t("pause") : t("play");
              updateShuffleButton();
              updatePlaybackStateBadge();
              updateStatCards();
              if (remoteSeekDetected) {
                lockSeekSync();
              }
              syncAudioClockWithState(remoteSeekDetected);
            }
            break;
          default:
            break;
        }
      };

      state.socket.onclose = () => {
        state.wsConnected = false;
        state.syncUnstable = !!state.token;
        updatePairingUi();
        console.warn("[LocalConnect] WebSocket closed. Reconnecting...");
        scheduleWsReconnect(state.wsReconnectDelayMs);
        state.wsReconnectDelayMs = Math.min(state.wsReconnectDelayMs * 2, 10000);
      };

      state.socket.onerror = (event) => {
        state.wsConnected = false;
        state.syncUnstable = !!state.token;
        updatePairingUi();
        console.warn("[LocalConnect] WebSocket error");
        console.warn(event);
      };
    }

    function getLivePositionMs() {
      const t = Number(el.audioPlayer.currentTime || 0);
      if (!Number.isFinite(t) || t <= 0) return state.playback.positionMs || 0;
      return Math.floor(t * 1000);
    }

    function applyLocalSeekUi(positionMs) {
      state.playback.positionMs = Math.max(0, positionMs || 0);
      el.timeCurrent.textContent = formatMs(state.playback.positionMs);
      if (state.playback.durationMs > 0) {
        el.seekBar.value = Math.floor((state.playback.positionMs / state.playback.durationMs) * 1000);
      }
      lockSeekSync();
      syncAudioClockWithState(true);
      updateStatCards();
    }

    function syncAudioClockWithState(force = false) {
      if (state.sourceLoading) return;
      if (!state.currentTrackId || !state.token) return;
      const desiredMs = Math.max(0, Number(state.playback.positionMs || 0));
      const desiredSec = desiredMs / 1000;
      if (!Number.isFinite(desiredSec)) return;

      const currentSec = Number(el.audioPlayer.currentTime || 0);
      const driftMs = Number.isFinite(currentSec)
        ? Math.abs((currentSec * 1000) - desiredMs)
        : Number.POSITIVE_INFINITY;
      if (!force && driftMs < 1100) return;

      try {
        el.audioPlayer.currentTime = desiredSec;
      } catch (_) {}
    }

    async function sendControl(action, payload = {}) {
      if (!state.token) return false;
      try {
        await api("/api/control/" + action, "POST", payload);
        markSessionSyncNow();
        return true;
      } catch (e) {
        const status = Number(e?.status || 0);
        if (status === 401 || status === 403) {
          setToken("");
          state.waitingPairing = false;
          stopPairingPolling();
          el.pairingInfo.textContent = t("sessionExpired");
          updatePairingUi();
        }
        return false;
      }
    }

    async function requestPlayQueueItem(item, index) {
      if (!state.token) return;
      const payload = {};
      const itemId = String(item?.id || "").trim();
      if (itemId) {
        payload.itemId = itemId;
      } else {
        payload.index = index;
      }

      markQueueInteraction();
      const previousIndex = state.currentQueueIndex;
      state.currentQueueIndex = index;
      renderQueue();
      const ok = await sendControl("play-item", payload);
      if (!ok) {
        state.currentQueueIndex = previousIndex;
        renderQueue();
      }
    }

    el.btnPair.addEventListener("click", requestPairing);
    el.btnPlayPause.addEventListener("click", () => sendControl("toggle"));
    el.btnPrev.addEventListener("click", () => sendControl("previous"));
    el.btnNext.addEventListener("click", () => sendControl("next"));
    el.btnShuffle.addEventListener("click", async () => {
      const previous = !!state.playback.shuffleEnabled;
      const next = !previous;
      state.playback.shuffleEnabled = next;
      updateShuffleButton();
      const ok = await sendControl("shuffle", { enabled: next });
      if (!ok) {
        state.playback.shuffleEnabled = previous;
        updateShuffleButton();
      }
    });
    el.btnSeekBack.addEventListener("click", () => {
      const target = Math.max(0, getLivePositionMs() - 10000);
      applyLocalSeekUi(target);
      sendControl("seek", { positionMs: target });
    });
    el.btnSeekFwd.addEventListener("click", () => {
      const base = getLivePositionMs();
      const target = Math.min(state.playback.durationMs || base + 10000, base + 10000);
      applyLocalSeekUi(target);
      sendControl("seek", { positionMs: target });
    });
    el.seekBar.addEventListener("change", () => {
      const value = Number(el.seekBar.value || 0);
      const positionMs = state.playback.durationMs > 0
        ? Math.floor((value / 1000) * state.playback.durationMs)
        : 0;
      applyLocalSeekUi(positionMs);
      sendControl("seek", { positionMs });
    });

    el.volumeBar.addEventListener("input", () => {
      const v = clamp01(Number(el.volumeBar.value ?? 100) / 100);
      state.playback.volume = v;
      el.audioPlayer.volume = v;
      if (state.volumeSendTimer) {
        clearTimeout(state.volumeSendTimer);
      }
      state.volumeSendTimer = setTimeout(() => {
        sendControl("volume", { volume: v });
        state.volumeSendTimer = null;
      }, 120);
    });

    el.volumeBar.addEventListener("change", () => {
      const v = clamp01(Number(el.volumeBar.value ?? 100) / 100);
      state.playback.volume = v;
      el.audioPlayer.volume = v;
      if (state.volumeSendTimer) {
        clearTimeout(state.volumeSendTimer);
        state.volumeSendTimer = null;
      }
      sendControl("volume", { volume: v });
    });

    ["pointerdown", "touchstart", "wheel", "scroll"].forEach((eventName) => {
      el.queueCarousel.addEventListener(eventName, markQueueInteraction, { passive: true });
      el.queueList.addEventListener(eventName, markQueueInteraction, { passive: true });
    });

    el.audioPlayer.addEventListener("timeupdate", () => {
      if (state.sourceLoading) return;
      if (!state.playback.isPlaying) return;
      if (Date.now() < state.seekSyncLockUntilMs) return;
      const pos = Math.floor((Number(el.audioPlayer.currentTime || 0)) * 1000);
      if (!Number.isFinite(pos)) return;
      if (pos + 700 < state.playback.positionMs) return;
      state.playback.positionMs = Math.max(pos, state.playback.positionMs);
      el.timeCurrent.textContent = formatMs(state.playback.positionMs);
      if (state.playback.durationMs > 0) {
        el.seekBar.value = Math.floor((state.playback.positionMs / state.playback.durationMs) * 1000);
      }
      updateStatCards();
    });
    el.audioPlayer.addEventListener("play", () => {
      if (state.sourceLoading) return;
      state.playback.isPlaying = true;
      el.btnPlayPause.textContent = t("pause");
      updatePlaybackStateBadge();
    });
    el.audioPlayer.addEventListener("pause", () => {
      if (state.sourceLoading) return;
      state.playback.isPlaying = false;
      el.btnPlayPause.textContent = t("play");
      updatePlaybackStateBadge();
    });

    function startSessionPolling() {
      if (state.sessionPollTimer) return;
      state.sessionPollTimer = setInterval(() => {
        if (!state.token) return;
        if (state.wsConnected && !state.syncUnstable) return;
        loadSession();
      }, 8000);
    }

    function startHealthMonitor() {
      if (state.healthPollTimer) return;
      state.healthPollTimer = setInterval(() => {
        if (!state.token || state.privatePlayback) return;
        const now = Date.now();
        const wsStale = state.wsConnected && state.wsLastMessageAt > 0 && (now - state.wsLastMessageAt) > 9000;
        const sessionStale = state.sessionLastSyncAt > 0 && (now - state.sessionLastSyncAt) > 15000;
        if (!wsStale && !sessionStale) {
          return;
        }

        state.syncUnstable = true;
        el.pairingInfo.textContent = t("syncUnstable");
        updatePairingUi();

        if (wsStale) {
          try {
            state.socket?.close();
          } catch (_) {}
          scheduleWsReconnect(500);
        }
        if (sessionStale) {
          loadSession();
        }
      }, 3000);
    }

    updatePairingUi();
    updateShuffleButton();
    if (state.pairingReceipt && !state.token) requestPairing();
    connectWs();
    startSessionPolling();
    startHealthMonitor();
  </script>
</body>
</html>
''';
}

String _htmlText(Map<String, String> i18n, String key) {
  return htmlEscape.convert(i18n[key] ?? _localConnectWebFallbacks[key] ?? key);
}

const Map<String, String> _localConnectWebFallbacks = <String, String>{
  'title': 'Listenfy Local Connect',
  'notPaired': 'Not paired',
  'pairingRequired': 'Pairing required',
  'pairingInstructions':
      'Request access from this browser and approve on your phone.',
  'requestPairing': 'Request pairing',
  'remoteSession': 'Remote session',
  'noTrack': 'No track',
  'info': 'Info',
  'waitingSession': 'Waiting session',
  'source': 'Source',
  'notFavorite': 'Not favorite',
  'favorite': 'Favorite',
  'currentTime': 'Current Time',
  'duration': 'Duration',
  'queuePosition': 'Queue Position',
  'progress': 'Progress',
  'trackHistory': 'Track history',
  'lyrics': 'Lyrics',
  'realAppData': 'Real app data',
  'noHistoryYet': 'No history yet',
  'plays': 'Plays',
  'completed': 'Completed',
  'skips': 'Skips',
  'retention': 'Retention',
  'lastPlayed': 'Last played',
  'artistData': 'Artist Data',
  'unknownArtist': 'Unknown artist',
  'unknown': 'Unknown',
  'type': 'Type',
  'queueTracks': 'Queue tracks',
  'queuePlays': 'Queue plays',
  'queueCompletes': 'Queue completes',
  'queueSkips': 'Queue skips',
  'queueAvg': 'Queue avg',
  'nextTracksByArtist': 'Next tracks by this artist',
  'noArtistDataYet': 'No artist data available yet.',
  'noArtistInfoForTrack': 'No artist info available for this track.',
  'noMoreArtistTracks': 'No more tracks from this artist in the current queue.',
  'queue': 'Queue',
  'expandQueue': 'Expand',
  'compactQueue': 'Compact',
  'track': 'track',
  'tracks': 'tracks',
  'playUnit': 'play',
  'playsUnit': 'plays',
  'previous': 'Previous',
  'play': 'Play',
  'pause': 'Pause',
  'next': 'Next',
  'shuffle': 'Shuffle',
  'shuffleOn': 'Shuffle On',
  'shuffleOff': 'Shuffle Off',
  'volume': 'Volume',
  'buffering': 'Buffering',
  'playing': 'Playing',
  'paused': 'Paused',
  'pairedSyncing': 'Paired · Syncing...',
  'pairedLive': 'Paired · Live',
  'pairedReconnecting': 'Paired · Reconnecting',
  'waitingApproval': 'Waiting approval',
  'pairingApproved': 'Pairing approved.',
  'waitingApprovalPhone': 'Waiting for approval on your phone...',
  'sendingRequest': 'Sending request...',
  'alreadyPaired': 'Already paired.',
  'requestSent': 'Request sent. Approve on your phone.',
  'couldNotRequestPairing': 'Could not request pairing.',
  'sessionExpired': 'Session expired. Request pairing again.',
  'syncUnstable': 'Sync unstable. Reconnecting...',
  'sessionEnded': 'Session ended on phone.',
  'sessionRevoked': 'Session revoked on phone.',
  'pairingRejected': 'Pairing rejected on phone.',
  'unknownSource': 'unknown source',
  'favShort': 'fav',
  'noRetention': 'no retention',
  'roleCollab': 'feat/collab',
  'rolePrincipal': 'principal',
  'member': 'member',
  'members': 'members',
  'estimatedType': 'Estimated type',
  'artistKindCollab': 'collaboration / multiple artists',
  'artistKindBand': 'Duo, band, or music group',
  'artistKindSoloist': 'Soloist, DJ, or musician',
  'largeQueueOptimized': 'Large queue optimized',
  'showingAroundCurrent': 'Showing tracks around the current song',
};
