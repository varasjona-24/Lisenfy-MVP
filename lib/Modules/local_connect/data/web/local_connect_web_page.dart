import 'dart:convert';

String buildLocalConnectWebPage({Map<String, String> translations = const {}}) {
  final i18n = <String, String>{..._localConnectWebFallbacks, ...translations};
  return '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${_htmlText(i18n, 'title')}</title>
  <style>
    :root {
      --bg: #060a12;
      --bg-soft: #0b1320;
      --card: #101b2a;
      --card-2: #132335;
      --text: #ecf3ff;
      --muted: #9ab0c6;
      --accent: #35d8a3;
      --accent-2: #5da9ff;
      --accent-3: #f7c86a;
      --border: #1f3349;
      --danger: #ff6b6b;
      --radius: 16px;
      --shadow: 0 12px 30px rgba(0, 0, 0, 0.34);
    }

    * {
      box-sizing: border-box;
    }

    body {
      margin: 0;
      min-height: 100vh;
      color: var(--text);
      font-family: "SF Pro Display", "Inter", "Segoe UI", Roboto, -apple-system, sans-serif;
      background:
        radial-gradient(1000px 620px at 18% -18%, rgba(93, 169, 255, 0.24), transparent 60%),
        radial-gradient(820px 500px at 98% -14%, rgba(53, 216, 163, 0.15), transparent 60%),
        linear-gradient(180deg, #080f1d 0%, var(--bg) 44%, #050912 100%);
    }

    .shell {
      max-width: 1180px;
      margin: 0 auto;
      padding: 20px 16px 24px;
      display: grid;
      gap: 14px;
    }

    .card {
      border: 1px solid var(--border);
      border-radius: var(--radius);
      background: linear-gradient(
        180deg,
        color-mix(in oklab, var(--card-2) 88%, black) 0%,
        color-mix(in oklab, var(--card) 92%, black) 100%
      );
      box-shadow: var(--shadow);
    }

    .topbar {
      padding: 14px 16px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
    }

    .brand {
      display: flex;
      align-items: center;
      gap: 10px;
      font-weight: 730;
      letter-spacing: 0.2px;
    }

    .brand-dot {
      width: 10px;
      height: 10px;
      border-radius: 50%;
      background: linear-gradient(180deg, var(--accent), var(--accent-2));
      box-shadow: 0 0 14px color-mix(in oklab, var(--accent) 58%, transparent);
    }

    .status-pill {
      border: 1px solid var(--border);
      border-radius: 999px;
      padding: 7px 12px;
      font-size: 12px;
      color: var(--muted);
      background: color-mix(in oklab, var(--bg-soft) 88%, black);
    }

    .status-pill.paired {
      color: var(--accent);
      border-color: color-mix(in oklab, var(--accent) 44%, var(--border));
      background: color-mix(in oklab, var(--accent) 11%, transparent);
    }

    .status-pill.unpaired {
      color: #ffd48f;
    }

    .pairing {
      padding: 14px 16px;
      display: grid;
      gap: 8px;
    }

    .pairing-title {
      font-size: 15px;
      font-weight: 680;
    }

    .small {
      font-size: 12px;
      color: var(--muted);
    }

    .btn {
      border: 1px solid var(--border);
      background: color-mix(in oklab, var(--bg-soft) 88%, black);
      color: var(--text);
      border-radius: 10px;
      padding: 10px 10px;
      cursor: pointer;
      font-weight: 610;
      letter-spacing: 0.14px;
      transition: border-color 120ms ease, transform 100ms ease, filter 120ms ease;
    }

    .btn:hover {
      border-color: color-mix(in oklab, var(--accent) 43%, var(--border));
      filter: brightness(1.03);
    }

    .btn:active {
      transform: translateY(1px);
    }

    .btn-primary {
      background: linear-gradient(
        180deg,
        color-mix(in oklab, var(--accent) 30%, #123127) 0%,
        color-mix(in oklab, var(--accent) 17%, #0c1421) 100%
      );
    }

    .btn-toggle-active {
      border-color: color-mix(in oklab, var(--accent) 52%, var(--border));
      background: linear-gradient(
        180deg,
        color-mix(in oklab, var(--accent) 24%, #122f25) 0%,
        color-mix(in oklab, var(--accent) 12%, #0c1421) 100%
      );
      color: color-mix(in oklab, var(--text) 95%, #d5ffee);
    }

    .main-grid {
      display: grid;
      gap: 14px;
      grid-template-columns: minmax(0, 1.05fr) minmax(320px, 0.95fr);
      align-items: start;
    }

    .now-panel {
      padding: 16px;
      display: grid;
      gap: 14px;
      align-content: start;
      position: relative;
      overflow: hidden;
      background:
        linear-gradient(135deg, rgba(53, 216, 163, 0.08), transparent 42%),
        linear-gradient(180deg, color-mix(in oklab, var(--card-2) 90%, black), color-mix(in oklab, var(--card) 94%, black));
    }

    .now-panel > * {
      position: relative;
      z-index: 1;
    }

    .cover-row {
      display: grid;
      grid-template-columns: 220px 1fr;
      gap: 16px;
      align-items: start;
    }

    .cover-wrap {
      width: 220px;
      height: 220px;
      border-radius: 18px;
      border: 1px solid var(--border);
      overflow: hidden;
      background: linear-gradient(150deg, #1b2d45, #101b2a);
      box-shadow: 0 18px 34px rgba(0, 0, 0, 0.38);
    }

    .cover {
      width: 100%;
      height: 100%;
      object-fit: cover;
      display: block;
    }

    .eyebrow {
      margin-bottom: 8px;
      color: color-mix(in oklab, var(--accent) 82%, white);
      font-size: 11px;
      font-weight: 720;
      letter-spacing: 0.75px;
      text-transform: uppercase;
    }

    .meta h1 {
      margin: 0 0 4px;
      font-size: 32px;
      line-height: 1.12;
      letter-spacing: 0;
      font-weight: 745;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .meta .artist {
      margin: 0;
      font-size: 22px;
      font-weight: 540;
      letter-spacing: 0;
      color: color-mix(in oklab, var(--text) 96%, #a6c4df);
    }

    .meta .album {
      margin: 4px 0 0;
      color: var(--muted);
      font-size: 14px;
    }

    .meta .state {
      margin-top: 12px;
      display: inline-flex;
      align-items: center;
      border: 1px solid var(--border);
      border-radius: 999px;
      padding: 6px 10px;
      color: var(--muted);
      font-size: 12px;
      background: color-mix(in oklab, var(--bg-soft) 87%, black);
    }

    .track-chips {
      margin-top: 12px;
      display: flex;
      flex-wrap: wrap;
      gap: 7px;
    }

    .track-chip {
      border: 1px solid var(--border);
      border-radius: 999px;
      padding: 6px 9px;
      color: var(--muted);
      background: color-mix(in oklab, var(--bg-soft) 86%, black);
      font-size: 12px;
      line-height: 1;
      max-width: 100%;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .track-chip.strong {
      color: color-mix(in oklab, var(--accent-3) 78%, white);
      border-color: color-mix(in oklab, var(--accent-3) 38%, var(--border));
      background: color-mix(in oklab, var(--accent-3) 10%, var(--bg-soft));
    }

    .artist-profile {
      margin-top: 12px;
      border: 1px solid var(--border);
      border-radius: 12px;
      background: color-mix(in oklab, var(--bg-soft) 86%, black);
      padding: 9px 10px;
      display: flex;
      align-items: center;
      gap: 10px;
      min-height: 72px;
    }

    .artist-profile-avatar-wrap {
      width: 54px;
      height: 54px;
      border-radius: 999px;
      border: 1px solid color-mix(in oklab, var(--accent) 35%, var(--border));
      overflow: hidden;
      flex: 0 0 auto;
      background: linear-gradient(160deg, #19314b, #0f1a29);
      display: grid;
      place-items: center;
    }

    .artist-profile-avatar {
      width: 100%;
      height: 100%;
      object-fit: cover;
      display: block;
    }

    .artist-profile-avatar-fallback {
      width: 100%;
      height: 100%;
      display: grid;
      place-items: center;
      font-size: 15px;
      font-weight: 720;
      letter-spacing: 0.2px;
      color: color-mix(in oklab, var(--text) 94%, #95b8d8);
      text-transform: uppercase;
    }

    .artist-profile-meta {
      min-width: 0;
      display: grid;
      gap: 2px;
    }

    .artist-profile-name {
      font-size: 14px;
      font-weight: 670;
      color: var(--text);
      line-height: 1.2;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .artist-insights .artist-profile {
      margin-top: 4px;
      margin-bottom: 10px;
    }

    .artist-profile-line {
      font-size: 12px;
      color: var(--muted);
      line-height: 1.25;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .stats {
      display: grid;
      grid-template-columns: repeat(4, minmax(0, 1fr));
      gap: 8px;
    }

    .stat {
      border: 1px solid var(--border);
      border-radius: 12px;
      background: color-mix(in oklab, var(--bg-soft) 88%, black);
      padding: 10px;
      display: grid;
      gap: 2px;
      min-height: 60px;
      align-content: center;
    }

    .stat-label {
      font-size: 11px;
      color: var(--muted);
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    .stat-value {
      font-size: 15px;
      font-weight: 650;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .stat-value.accent {
      color: color-mix(in oklab, var(--accent) 80%, white);
    }

    .track-history {
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 11px 12px;
      background: color-mix(in oklab, var(--bg-soft) 88%, black);
      display: grid;
      gap: 10px;
    }

    .track-history-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
    }

    .track-history-head h3 {
      margin: 0;
      font-size: 14px;
      color: var(--text);
      letter-spacing: 0;
    }

    .track-history-grid {
      display: grid;
      grid-template-columns: repeat(5, minmax(0, 1fr));
      gap: 8px;
    }

    .track-history-card {
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 8px;
      display: grid;
      gap: 2px;
      background: color-mix(in oklab, var(--bg) 88%, black);
      min-width: 0;
    }

    .track-history-label {
      font-size: 10px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: var(--muted);
    }

    .track-history-value {
      font-size: 15px;
      font-weight: 680;
      color: var(--text);
      font-variant-numeric: tabular-nums;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .queue-panel {
      padding: 14px;
      display: grid;
      gap: 12px;
      align-content: start;
      align-self: start;
      height: max-content;
      position: sticky;
      top: 14px;
    }

    .queue-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
    }

    .queue-head h2 {
      margin: 0;
      font-size: 22px;
      letter-spacing: 0;
      font-weight: 710;
    }

    .queue-count {
      border: 1px solid var(--border);
      border-radius: 999px;
      padding: 5px 10px;
      font-size: 12px;
      color: var(--muted);
      background: color-mix(in oklab, var(--bg-soft) 88%, black);
    }

    .queue-carousel {
      display: grid;
      grid-auto-flow: column;
      grid-auto-columns: minmax(148px, 1fr);
      gap: 10px;
      overflow-x: auto;
      padding-bottom: 6px;
      scroll-snap-type: x mandatory;
    }

    .queue-carousel::-webkit-scrollbar {
      height: 6px;
    }

    .queue-carousel::-webkit-scrollbar-thumb {
      background: color-mix(in oklab, var(--border) 84%, white);
      border-radius: 999px;
    }

    .queue-cover-item {
      border: 1px solid var(--border);
      border-radius: 12px;
      overflow: hidden;
      background: color-mix(in oklab, var(--bg-soft) 86%, black);
      scroll-snap-align: start;
      transition: border-color 120ms ease, transform 120ms ease;
      min-width: 0;
      cursor: pointer;
    }

    .queue-cover-item:hover {
      transform: translateY(-1px);
      border-color: color-mix(in oklab, var(--accent) 42%, var(--border));
    }

    .queue-cover-item.active {
      border-color: color-mix(in oklab, var(--accent) 54%, var(--border));
      box-shadow: 0 0 0 1px color-mix(in oklab, var(--accent) 24%, transparent);
    }

    .queue-cover-wrap {
      width: 100%;
      aspect-ratio: 1 / 1;
      background: linear-gradient(150deg, #1b2d45, #101b2a);
      overflow: hidden;
    }

    .queue-cover {
      width: 100%;
      height: 100%;
      object-fit: cover;
      display: block;
    }

    .queue-cover-fallback {
      width: 100%;
      height: 100%;
      display: grid;
      place-items: center;
      color: #8aa3bd;
      font-size: 28px;
    }

    .queue-cover-meta {
      padding: 8px 9px 9px;
      display: grid;
      gap: 2px;
    }

    .queue-cover-title {
      font-size: 12px;
      color: var(--text);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      font-weight: 620;
    }

    .queue-cover-artist {
      font-size: 11px;
      color: var(--muted);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .queue-list {
      margin: 0;
      padding: 0;
      list-style: none;
      display: grid;
      gap: 8px;
      max-height: min(42vh, 420px);
      overflow: auto;
      scrollbar-width: thin;
      scrollbar-color: color-mix(in oklab, var(--border) 86%, white) transparent;
    }

    .queue-list::-webkit-scrollbar,
    .stats::-webkit-scrollbar,
    .track-history-grid::-webkit-scrollbar,
    .artist-kpis::-webkit-scrollbar {
      width: 8px;
      height: 6px;
    }

    .queue-list::-webkit-scrollbar-thumb,
    .stats::-webkit-scrollbar-thumb,
    .track-history-grid::-webkit-scrollbar-thumb,
    .artist-kpis::-webkit-scrollbar-thumb {
      background: color-mix(in oklab, var(--border) 86%, white);
      border-radius: 999px;
    }

    .queue-list::-webkit-scrollbar-track,
    .stats::-webkit-scrollbar-track,
    .track-history-grid::-webkit-scrollbar-track,
    .artist-kpis::-webkit-scrollbar-track {
      background: transparent;
    }

    .queue-item {
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 8px 10px;
      display: flex;
      justify-content: space-between;
      gap: 10px;
      align-items: center;
      color: var(--text);
      cursor: pointer;
      background: color-mix(in oklab, var(--bg-soft) 78%, black);
      transition: border-color 120ms ease, background 120ms ease;
    }

    .queue-item:hover {
      border-color: color-mix(in oklab, var(--accent) 34%, var(--border));
      background: color-mix(in oklab, var(--card-2) 86%, black);
    }

    .queue-item.active {
      border-color: color-mix(in oklab, var(--accent) 45%, var(--border));
      background: color-mix(in oklab, var(--accent) 10%, var(--card));
    }

    .queue-item-main {
      min-width: 0;
      flex: 1;
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .queue-item-index {
      width: 24px;
      height: 24px;
      border-radius: 999px;
      display: grid;
      place-items: center;
      font-size: 11px;
      font-weight: 670;
      color: var(--muted);
      border: 1px solid var(--border);
      background: color-mix(in oklab, var(--bg-soft) 92%, black);
      flex: 0 0 auto;
      font-variant-numeric: tabular-nums;
    }

    .queue-item-text {
      min-width: 0;
      display: grid;
      gap: 1px;
    }

    .queue-item-title {
      font-size: 13px;
      font-weight: 640;
      color: var(--text);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .queue-item-sub {
      font-size: 12px;
      color: var(--muted);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .queue-item-time {
      border: 1px solid var(--border);
      border-radius: 999px;
      padding: 4px 8px;
      font-size: 12px;
      line-height: 1;
      color: var(--muted);
      font-variant-numeric: tabular-nums;
      background: color-mix(in oklab, var(--bg-soft) 88%, black);
      flex: 0 0 auto;
    }

    .queue-item.active .queue-item-index {
      color: color-mix(in oklab, var(--accent) 76%, white);
      border-color: color-mix(in oklab, var(--accent) 45%, var(--border));
      background: color-mix(in oklab, var(--accent) 18%, var(--bg-soft));
    }

    .queue-item.active .queue-item-time {
      color: var(--text);
      border-color: color-mix(in oklab, var(--accent) 38%, var(--border));
    }

    .artist-insights {
      border: 1px solid var(--border);
      border-radius: 14px;
      padding: 11px 12px;
      background: color-mix(in oklab, var(--bg-soft) 88%, black);
      display: grid;
      gap: 10px;
    }

    .artist-head {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
    }

    .artist-head h3 {
      margin: 0;
      font-size: 14px;
      letter-spacing: 0.2px;
      color: var(--text);
    }

    .artist-insight-pill {
      border: 1px solid var(--border);
      border-radius: 999px;
      padding: 4px 8px;
      font-size: 12px;
      color: var(--muted);
      background: color-mix(in oklab, var(--bg) 88%, black);
    }

    .artist-kpis {
      display: grid;
      grid-template-columns: repeat(5, minmax(0, 1fr));
      gap: 8px;
    }

    .artist-kpi {
      border: 1px solid var(--border);
      border-radius: 10px;
      padding: 7px 8px;
      display: grid;
      gap: 2px;
      background: color-mix(in oklab, var(--bg) 88%, black);
    }

    .artist-kpi-label {
      font-size: 10px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
      color: var(--muted);
    }

    .artist-kpi-value {
      font-size: 16px;
      font-weight: 680;
      color: var(--text);
      font-variant-numeric: tabular-nums;
    }

    .artist-subhead {
      font-size: 11px;
      text-transform: uppercase;
      letter-spacing: 0.6px;
      color: var(--muted);
    }

    .artist-next-list {
      margin: 0;
      padding: 0;
      list-style: none;
      display: grid;
      gap: 6px;
      max-height: 148px;
      overflow: auto;
    }

    .artist-next-item {
      border: 1px solid var(--border);
      border-radius: 9px;
      padding: 7px 8px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 8px;
      cursor: pointer;
      background: color-mix(in oklab, var(--bg) 88%, black);
      transition: border-color 120ms ease, background 120ms ease;
    }

    .artist-next-item:hover {
      border-color: color-mix(in oklab, var(--accent) 34%, var(--border));
      background: color-mix(in oklab, var(--card-2) 88%, black);
    }

    .artist-next-main {
      min-width: 0;
      display: flex;
      align-items: center;
      gap: 8px;
      flex: 1;
    }

    .artist-next-index {
      font-size: 10px;
      color: var(--muted);
      border: 1px solid var(--border);
      border-radius: 999px;
      padding: 3px 6px;
      line-height: 1;
      font-variant-numeric: tabular-nums;
      flex: 0 0 auto;
      background: color-mix(in oklab, var(--bg-soft) 90%, black);
    }

    .artist-next-text {
      min-width: 0;
      display: grid;
      gap: 1px;
    }

    .artist-next-title {
      font-size: 12px;
      color: var(--text);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      font-weight: 620;
    }

    .artist-next-sub {
      font-size: 11px;
      color: var(--muted);
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .artist-next-time {
      font-size: 12px;
      color: var(--muted);
      border: 1px solid var(--border);
      border-radius: 999px;
      padding: 4px 8px;
      line-height: 1;
      font-variant-numeric: tabular-nums;
      background: color-mix(in oklab, var(--bg-soft) 88%, black);
      flex: 0 0 auto;
    }

    .artist-next-empty {
      border: 1px dashed var(--border);
      border-radius: 9px;
      padding: 10px 9px;
      color: var(--muted);
      font-size: 12px;
      background: color-mix(in oklab, var(--bg) 86%, black);
    }

    .dock {
      padding: 12px 14px;
      display: grid;
      gap: 10px;
      backdrop-filter: blur(8px);
    }

    .seek-wrap {
      padding: 8px 10px;
      border: 1px solid var(--border);
      border-radius: 12px;
      background: color-mix(in oklab, var(--bg-soft) 88%, black);
    }

    .time-row {
      margin-top: 4px;
      display: flex;
      justify-content: space-between;
      color: var(--muted);
      font-size: 12px;
      font-variant-numeric: tabular-nums;
    }

    input[type=range] {
      width: 100%;
      accent-color: var(--accent);
    }

    .dock-controls {
      display: grid;
      grid-template-columns: repeat(6, minmax(0, 1fr)) minmax(160px, 0.8fr);
      gap: 8px;
      align-items: center;
    }

    .volume-wrap {
      display: grid;
      gap: 4px;
      border: 1px solid var(--border);
      border-radius: 10px;
      background: color-mix(in oklab, var(--bg-soft) 88%, black);
      padding: 7px 9px;
    }

    .volume-wrap .small {
      font-size: 11px;
      line-height: 1;
    }

    @media (min-width: 1400px) {
      .shell {
        max-width: 1500px;
        padding: 28px 28px 32px;
        gap: 18px;
      }

      .topbar {
        padding: 18px 22px;
      }

      .brand {
        font-size: 22px;
      }

      .status-pill {
        font-size: 15px;
        padding: 9px 14px;
      }

      .main-grid {
        grid-template-columns: minmax(0, 1.35fr) minmax(420px, 0.75fr);
        gap: 18px;
      }

      .now-panel {
        padding: 22px;
        gap: 18px;
      }

      .cover-row {
        grid-template-columns: 320px 1fr;
        gap: 24px;
      }

      .cover-wrap {
        width: 320px;
        height: 320px;
        border-radius: 22px;
      }

      .eyebrow {
        font-size: 13px;
      }

      .meta h1 {
        font-size: 46px;
        line-height: 1.08;
      }

      .meta .artist {
        font-size: 30px;
      }

      .meta .album {
        font-size: 18px;
      }

      .meta .state,
      .track-chip,
      .artist-insight-pill {
        font-size: 15px;
      }

      .track-chip {
        padding: 8px 12px;
      }

      .stat {
        min-height: 78px;
        padding: 13px;
      }

      .stat-label,
      .track-history-label,
      .artist-kpi-label {
        font-size: 12px;
      }

      .stat-value,
      .track-history-value,
      .artist-kpi-value {
        font-size: 22px;
      }

      .track-history,
      .artist-insights,
      .queue-panel {
        padding: 16px;
      }

      .track-history-head h3,
      .artist-head h3 {
        font-size: 18px;
      }

      .artist-profile {
        min-height: 86px;
        padding: 12px;
      }

      .artist-profile-avatar-wrap {
        width: 64px;
        height: 64px;
      }

      .artist-profile-name {
        font-size: 18px;
      }

      .artist-profile-line {
        font-size: 15px;
      }

      .artist-next-list {
        max-height: 240px;
      }

      .artist-next-item,
      .queue-item {
        padding: 11px 12px;
      }

      .artist-next-title,
      .queue-item-title {
        font-size: 16px;
      }

      .artist-next-sub,
      .queue-item-sub {
        font-size: 14px;
      }

      .queue-head h2 {
        font-size: 28px;
      }

      .queue-count {
        font-size: 15px;
      }

      .queue-carousel {
        grid-auto-columns: minmax(190px, 1fr);
      }

      .queue-list {
        max-height: min(46vh, 560px);
      }

      .dock {
        padding: 16px 18px;
        gap: 14px;
      }

      .seek-wrap {
        padding: 11px 14px;
      }

      .time-row {
        font-size: 15px;
      }

      .dock-controls {
        grid-template-columns: repeat(6, minmax(120px, 1fr)) minmax(220px, 0.8fr);
        gap: 10px;
      }

      .btn {
        font-size: 16px;
        padding: 13px 12px;
      }

      .volume-wrap {
        padding: 10px 12px;
      }

      .volume-wrap .small {
        font-size: 13px;
      }
    }

    @media (max-width: 980px) {
      .shell {
        max-width: 760px;
      }

      .main-grid {
        grid-template-columns: 1fr;
      }

      .queue-panel {
        position: static;
      }

      .cover-row {
        grid-template-columns: 180px 1fr;
      }

      .cover-wrap {
        width: 180px;
        height: 180px;
      }

      .meta h1 {
        font-size: 24px;
      }

      .meta .artist {
        font-size: 19px;
      }

      .artist-profile {
        min-height: 68px;
      }

      .artist-profile-avatar-wrap {
        width: 48px;
        height: 48px;
      }

      .artist-kpis {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }

      .track-history-grid {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }

      .stats {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }

      .dock-controls {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }

      .queue-carousel {
        grid-auto-columns: minmax(130px, 1fr);
      }
    }

    @media (max-width: 720px) {
      body {
        background:
          linear-gradient(180deg, #080f1d 0%, var(--bg) 52%, #050912 100%);
      }

      .shell {
        padding: 10px 10px 14px;
        gap: 10px;
      }

      .card {
        border-radius: 12px;
      }

      .topbar {
        padding: 10px 12px;
      }

      .brand {
        min-width: 0;
      }

      .brand span:last-child {
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }

      .status-pill {
        padding: 6px 9px;
        white-space: nowrap;
      }

      .pairing {
        padding: 12px;
      }

      .now-panel {
        padding: 12px;
        gap: 10px;
      }

      .cover-row {
        grid-template-columns: 88px minmax(0, 1fr);
        gap: 11px;
        align-items: center;
      }

      .cover-wrap {
        width: 88px;
        height: 88px;
        border-radius: 12px;
        box-shadow: 0 10px 20px rgba(0, 0, 0, 0.32);
      }

      .eyebrow {
        display: none;
      }

      .meta h1 {
        font-size: 20px;
        line-height: 1.14;
        -webkit-line-clamp: 2;
      }

      .meta .artist {
        font-size: 15px;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }

      .meta .album {
        display: none;
      }

      .meta .state {
        margin-top: 7px;
        padding: 5px 8px;
        font-size: 11px;
      }

      .track-chips {
        margin-top: 7px;
        gap: 5px;
      }

      .track-chip {
        padding: 5px 7px;
        font-size: 11px;
        max-width: 140px;
      }

      .stats {
        grid-template-columns: repeat(4, minmax(88px, 1fr));
        overflow-x: auto;
        padding-bottom: 2px;
        scroll-snap-type: x mandatory;
        scrollbar-width: thin;
      }

      .stat {
        min-height: 54px;
        min-width: 88px;
        padding: 8px;
        scroll-snap-align: start;
      }

      .stat-label,
      .track-history-label,
      .artist-kpi-label {
        font-size: 9px;
      }

      .track-history {
        padding: 10px;
      }

      .track-history-grid {
        grid-template-columns: repeat(5, minmax(88px, 1fr));
        overflow-x: auto;
        padding-bottom: 2px;
        scroll-snap-type: x mandatory;
        scrollbar-width: thin;
      }

      .track-history-card {
        min-width: 88px;
        scroll-snap-align: start;
      }

      .artist-insights {
        padding: 10px;
      }

      .artist-profile {
        min-height: 60px;
        padding: 8px;
      }

      .artist-profile-avatar-wrap {
        width: 42px;
        height: 42px;
      }

      .artist-profile-name {
        font-size: 13px;
      }

      .artist-profile-line {
        font-size: 11px;
      }

      .artist-kpis {
        grid-template-columns: repeat(5, minmax(88px, 1fr));
        overflow-x: auto;
        padding-bottom: 2px;
        scroll-snap-type: x mandatory;
        scrollbar-width: thin;
      }

      .artist-kpi {
        min-width: 88px;
        scroll-snap-align: start;
      }

      .artist-next-list {
        max-height: 188px;
      }

      @media (orientation: portrait) {
        .artist-insights {
          display: grid;
        }

        .queue-carousel {
          display: none;
        }
      }

      .queue-panel {
        padding: 12px;
      }

      .queue-carousel {
        display: none;
      }

      .queue-list {
        max-height: none;
      }

      .queue-item {
        padding: 9px 9px;
      }

      .queue-item-time {
        display: none;
      }

      .dock {
        padding: 9px;
        gap: 8px;
        border-radius: 14px;
        margin-top: 2px;
      }

      .seek-wrap {
        padding: 6px 8px;
      }

      .dock-controls {
        grid-template-columns: repeat(3, minmax(0, 1fr));
        gap: 6px;
      }

      .dock-controls .btn {
        padding: 9px 6px;
        font-size: 12px;
      }

      #btnShuffle {
        display: none;
      }

      .volume-wrap {
        grid-column: span 3;
      }
    }

    @media (max-width: 380px) {
      .cover-row {
        grid-template-columns: 72px minmax(0, 1fr);
      }

      .cover-wrap {
        width: 72px;
        height: 72px;
      }

      .meta h1 {
        font-size: 18px;
      }

      .track-chip {
        max-width: 112px;
      }
    }

    @media (max-width: 980px) and (max-height: 520px) and (orientation: landscape) {
      .shell {
        max-width: none;
        padding: 8px;
      }

      .cover-row {
        grid-template-columns: 76px minmax(0, 1fr);
      }

      .cover-wrap {
        width: 76px;
        height: 76px;
        border-radius: 10px;
      }

      .meta h1 {
        font-size: 18px;
        -webkit-line-clamp: 1;
      }

      .meta .artist {
        font-size: 14px;
      }

      .track-history,
      .artist-insights {
        display: none;
      }

      .queue-carousel {
        display: none;
      }

      .queue-list {
        max-height: 180px;
      }

      .dock {
        padding: 7px;
        gap: 6px;
      }

      .seek-wrap {
        padding: 5px 7px;
      }

      .dock-controls {
        grid-template-columns: repeat(5, minmax(0, 1fr)) minmax(120px, 1fr);
        gap: 5px;
      }

      .dock-controls .btn {
        padding: 8px 5px;
        font-size: 11px;
      }

      #btnShuffle {
        display: none;
      }

      .volume-wrap {
        grid-column: auto;
        padding: 6px 7px;
      }

      .volume-wrap .small {
        display: none;
      }
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

        <section class="track-history">
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

        <section class="artist-insights">
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

      <section class="card queue-panel">
        <div class="queue-head">
          <h2>${_htmlText(i18n, 'queue')}</h2>
          <span id="queueCount" class="queue-count">0 ${_htmlText(i18n, 'tracks')}</span>
        </div>
        <div id="queueCarousel" class="queue-carousel"></div>
        <ul id="queueList" class="queue-list"></ul>
      </section>
    </main>

    <footer class="card dock">
      <div class="seek-wrap">
        <input id="seekBar" type="range" min="0" max="1000" value="0" />
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
          <input id="volumeBar" type="range" min="0" max="100" value="100" />
        </div>
      </div>
    </footer>

    <audio id="audioPlayer" preload="auto" style="display:none;"></audio>
  </div>

  <script>
    const i18n = ${jsonEncode(i18n)};
    function t(key) {
      return i18n[key] || key;
    }

    function plural(count, singularKey, pluralKey) {
      return Number(count) === 1 ? t(singularKey) : t(pluralKey);
    }

    const state = {
      token: localStorage.getItem("listenfy_local_token") || "",
      clientId: localStorage.getItem("listenfy_local_client_id") || "",
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

    const MAX_RENDERED_QUEUE_ITEMS = 90;

    if (!state.clientId) {
      state.clientId = "web-" + Math.random().toString(36).slice(2) + Date.now().toString(36);
      localStorage.setItem("listenfy_local_client_id", state.clientId);
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
      queueCarousel: document.getElementById("queueCarousel"),
      queueList: document.getElementById("queueList"),
      audioPlayer: document.getElementById("audioPlayer")
    };

    function formatMs(ms) {
      const totalSec = Math.max(0, Math.floor((ms || 0) / 1000));
      const m = Math.floor(totalSec / 60).toString().padStart(2, "0");
      const s = (totalSec % 60).toString().padStart(2, "0");
      return m + ":" + s;
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
        if (!state.token && !state.waitingPairing) return;
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

      el.artistAvatar.src = avatarSrc;
      el.artistAvatar.style.display = "block";
    }

    function setToken(token) {
      state.token = (token || "").trim();
      if (state.token) {
        localStorage.setItem("listenfy_local_token", state.token);
        markSessionSyncNow();
      } else {
        localStorage.removeItem("listenfy_local_token");
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
      try {
        const response = await api("/api/pairing/status?clientId=" + encodeURIComponent(state.clientId));
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
          connectWs();
        }
      } catch (_) {
        // Keep waiting while network is stable.
      } finally {
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
        const subtitle = source + " · " + roleLabel + " · " + plays + " " + plural(plays, "playUnit", "playsUnit") + " · " + completionLabel;
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
      const track = payload?.track || queueTrack || null;
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
      state.queue = queue;
      state.currentQueueIndex = normalizedQueueIndex;
      state.currentTrackId = nextTrackId;

      el.title.textContent = track?.title || t("noTrack");
      el.artist.textContent = track?.artist || "—";
      el.album.textContent = buildTrackInfoLine(track);
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
      const safeVolume = clamp01(state.playback.volume || 1);
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
      const signature = queueSignature(state.queue);
      const queueChanged = signature !== state.lastRenderedQueueSignature;
      const indexChanged = state.currentQueueIndex !== state.lastRenderedQueueIndex;
      const trackChanged = state.currentTrackId !== state.lastRenderedTrackId;

      const countLabel = state.queue.length + " " + plural(state.queue.length, "track", "tracks");
      el.queueCount.textContent = countLabel;

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
        const coverUrl = queueCoverUrl(item, i);

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

      state.lastRenderedQueueSignature = signature;
      state.lastRenderedQueueIndex = state.currentQueueIndex;
      state.lastRenderedTrackId = state.currentTrackId;
    }

    function refreshAudioSource() {
      if (!state.token || !state.currentTrackId) {
        clearRemoteAudioPlayback();
        return;
      }
      const src = withToken("/stream/current?track=" + encodeURIComponent(state.currentTrackId));
      if (state.currentAudioSrc !== src) {
        state.currentAudioSrc = src;
        el.audioPlayer.src = src;
      }
      applyAudioPlaybackSpeed();
      syncAudioClockWithState(false);
      if (state.playback.isPlaying) {
        el.audioPlayer.play().catch(() => {});
      } else {
        el.audioPlayer.pause();
      }
    }

    async function api(path, method = "GET", body) {
      const sep = path.includes("?") ? "&" : "?";
      const url = state.token ? (path + sep + "token=" + encodeURIComponent(state.token)) : path;
      const res = await fetch(url, {
        method,
        cache: "no-store",
        headers: { "Content-Type": "application/json" },
        body: body ? JSON.stringify(body) : undefined
      });
      if (!res.ok) {
        console.warn("[LocalConnect] API error", method, path, res.status);
        const err = new Error("HTTP " + res.status);
        err.status = res.status;
        throw err;
      }
      return res.json().catch(() => ({}));
    }

    async function requestPairing() {
      state.waitingPairing = true;
      updatePairingUi();
      el.pairingInfo.textContent = t("sendingRequest");
      try {
        const response = await api("/api/pairing/request", "POST", {
          clientId: state.clientId,
          clientName: buildReadableClientName()
        });
        if (response?.status === "already_paired" && response?.token) {
          setToken(response.token);
          state.waitingPairing = false;
          el.pairingInfo.textContent = t("alreadyPaired");
          if (response?.session) {
            renderNowPlaying(response.session);
          } else {
            await loadSession();
          }
          connectWs();
        } else {
          el.pairingInfo.textContent = t("requestSent");
          startPairingPolling();
          checkPairingStatus();
        }
      } catch (e) {
        el.pairingInfo.textContent = t("couldNotRequestPairing");
        state.waitingPairing = false;
        console.warn("[LocalConnect] Pairing request failed", e);
      }
      updatePairingUi();
    }

    async function loadSession() {
      if (!state.token) return;
      try {
        const data = await api("/api/session");
        markSessionSyncNow();
        if (data?.track || (Array.isArray(data?.queue) && data.queue.length > 0)) {
          renderNowPlaying(data);
          return;
        }
        const pair = await Promise.all([
          api("/api/current"),
          api("/api/queue")
        ]);
        const current = pair[0];
        const queue = pair[1];
        renderNowPlaying({
          track: current?.track || null,
          playback: data?.playback || state.playback,
          queue: queue?.queue || [],
          currentQueueIndex: queue?.currentQueueIndex || 0
        });
      } catch (e) {
        const status = Number(e?.status || 0);
        if (status === 401 || status === 403) {
          setToken("");
          state.currentAudioSrc = "";
          state.waitingPairing = false;
          stopPairingPolling();
          el.pairingInfo.textContent = t("sessionExpired");
          updatePairingUi();
          return;
        }

        state.syncUnstable = true;
        el.pairingInfo.textContent = t("syncUnstable");
        scheduleWsReconnect(500);
        updatePairingUi();
        console.warn("[LocalConnect] Session load failed", e);
      }
    }

    function connectWs() {
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
        if (state.token) {
          loadSession();
        }
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
          case "currentTrackChanged":
          case "playbackStateChanged":
          case "queueChanged":
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
      const v = clamp01(Number(el.volumeBar.value || 100) / 100);
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
      const v = clamp01(Number(el.volumeBar.value || 100) / 100);
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
      state.playback.isPlaying = true;
      el.btnPlayPause.textContent = t("pause");
      updatePlaybackStateBadge();
    });
    el.audioPlayer.addEventListener("pause", () => {
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
        if (!state.token) return;
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
    connectWs();
    startSessionPolling();
    startHealthMonitor();
    loadSession();
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
