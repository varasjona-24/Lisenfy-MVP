String buildLocalConnectWebPage() {
  return '''
<!doctype html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Listenfy Local Connect</title>
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

    .main-grid {
      display: grid;
      gap: 14px;
      grid-template-columns: minmax(0, 1.05fr) minmax(320px, 0.95fr);
    }

    .now-panel {
      padding: 16px;
      display: grid;
      gap: 14px;
      align-content: start;
    }

    .cover-row {
      display: grid;
      grid-template-columns: 190px 1fr;
      gap: 16px;
      align-items: start;
    }

    .cover-wrap {
      width: 190px;
      height: 190px;
      border-radius: 14px;
      border: 1px solid var(--border);
      overflow: hidden;
      background: linear-gradient(150deg, #1b2d45, #101b2a);
      box-shadow: 0 12px 24px rgba(0, 0, 0, 0.3);
    }

    .cover {
      width: 100%;
      height: 100%;
      object-fit: cover;
      display: block;
    }

    .meta h1 {
      margin: 0 0 4px;
      font-size: 40px;
      line-height: 1.02;
      letter-spacing: -0.7px;
      font-weight: 745;
    }

    .meta .artist {
      margin: 0;
      font-size: 22px;
      font-weight: 540;
      letter-spacing: -0.2px;
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

    .stats {
      display: grid;
      grid-template-columns: repeat(3, minmax(0, 1fr));
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

    .queue-panel {
      padding: 14px;
      display: grid;
      gap: 12px;
      align-content: start;
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
      letter-spacing: -0.35px;
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
      max-height: 270px;
      overflow: auto;
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
      grid-template-columns: repeat(3, minmax(0, 1fr));
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
      position: sticky;
      bottom: 10px;
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
      grid-template-columns: repeat(5, minmax(0, 1fr)) minmax(160px, 0.8fr);
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

    @media (max-width: 980px) {
      .main-grid {
        grid-template-columns: 1fr;
      }

      .cover-row {
        grid-template-columns: 1fr;
      }

      .cover-wrap {
        width: 100%;
        height: auto;
        aspect-ratio: 1 / 1;
      }

      .meta h1 {
        font-size: 32px;
      }

      .meta .artist {
        font-size: 19px;
      }

      .artist-kpis {
        grid-template-columns: 1fr;
      }

      .dock-controls {
        grid-template-columns: repeat(2, minmax(0, 1fr));
      }

      .queue-carousel {
        grid-auto-columns: minmax(130px, 1fr);
      }
    }
  </style>
</head>
<body>
  <div class="shell">
    <header class="card topbar">
      <div class="brand">
        <span class="brand-dot"></span>
        <span>Listenfy Local Connect</span>
      </div>
      <span id="pairingState" class="status-pill unpaired">Not paired</span>
    </header>

    <section class="card pairing" id="pairingCard">
      <div class="pairing-title">Pairing required</div>
      <div class="small">Request access from this browser and approve on your phone.</div>
      <button id="btnPair" class="btn btn-primary">Request pairing</button>
      <span id="pairingInfo" class="small"></span>
    </section>

    <main class="main-grid">
      <section class="card now-panel">
        <div class="cover-row">
          <div class="cover-wrap">
            <img id="cover" class="cover" alt="Cover" />
          </div>
          <div class="meta">
            <h1 id="title">No track</h1>
            <p id="artist" class="artist">—</p>
            <p id="album" class="album">Info: —</p>
            <div id="playbackState" class="state">Waiting session</div>
          </div>
        </div>

        <div class="stats">
          <div class="stat">
            <div class="stat-label">Current Time</div>
            <div id="statCurrent" class="stat-value">00:00</div>
          </div>
          <div class="stat">
            <div class="stat-label">Duration</div>
            <div id="statDuration" class="stat-value">00:00</div>
          </div>
          <div class="stat">
            <div class="stat-label">Queue Position</div>
            <div id="statQueuePos" class="stat-value">-</div>
          </div>
        </div>

        <section class="artist-insights">
          <div class="artist-head">
            <h3>Artist Data</h3>
            <span id="artistInsightCount" class="artist-insight-pill">-</span>
          </div>
          <div class="artist-kpis">
            <div class="artist-kpi">
              <span class="artist-kpi-label">Tracks in queue</span>
              <strong id="artistTracksByArtist" class="artist-kpi-value">0</strong>
            </div>
            <div class="artist-kpi">
              <span class="artist-kpi-label">Total plays</span>
              <strong id="artistAlbumsCount" class="artist-kpi-value">0</strong>
            </div>
            <div class="artist-kpi">
              <span class="artist-kpi-label">Avg completion</span>
              <strong id="artistTotalDuration" class="artist-kpi-value">0%</strong>
            </div>
          </div>
          <div class="artist-subhead">Next tracks by this artist</div>
          <ul id="artistNextList" class="artist-next-list">
            <li class="artist-next-empty">No artist data available yet.</li>
          </ul>
        </section>
      </section>

      <section class="card queue-panel">
        <div class="queue-head">
          <h2>Queue</h2>
          <span id="queueCount" class="queue-count">0 tracks</span>
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
        <button id="btnPrev" class="btn">Previous</button>
        <button id="btnPlayPause" class="btn btn-primary">Play</button>
        <button id="btnNext" class="btn">Next</button>
        <button id="btnSeekBack" class="btn">-10s</button>
        <button id="btnSeekFwd" class="btn">+10s</button>
        <div class="volume-wrap">
          <span class="small">Volume</span>
          <input id="volumeBar" type="range" min="0" max="100" value="100" />
        </div>
      </div>
    </footer>

    <audio id="audioPlayer" preload="auto" style="display:none;"></audio>
  </div>

  <script>
    const state = {
      token: localStorage.getItem("listenfy_local_token") || "",
      clientId: localStorage.getItem("listenfy_local_client_id") || "",
      socket: null,
      wsReconnectTimer: null,
      wsReconnectDelayMs: 1500,
      sessionPollTimer: null,
      healthPollTimer: null,
      pairingPollTimer: null,
      playback: { positionMs: 0, durationMs: 0, isPlaying: false, isBuffering: false, volume: 1 },
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
      pairingPollTicks: 0
    };

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
      statCurrent: document.getElementById("statCurrent"),
      statDuration: document.getElementById("statDuration"),
      statQueuePos: document.getElementById("statQueuePos"),
      artistInsightCount: document.getElementById("artistInsightCount"),
      artistTracksByArtist: document.getElementById("artistTracksByArtist"),
      artistAlbumsCount: document.getElementById("artistAlbumsCount"),
      artistTotalDuration: document.getElementById("artistTotalDuration"),
      artistNextList: document.getElementById("artistNextList"),
      seekBar: document.getElementById("seekBar"),
      timeCurrent: document.getElementById("timeCurrent"),
      timeDuration: document.getElementById("timeDuration"),
      btnPrev: document.getElementById("btnPrev"),
      btnPlayPause: document.getElementById("btnPlayPause"),
      btnNext: document.getElementById("btnNext"),
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

    function clamp01(value) {
      const n = Number(value);
      if (!Number.isFinite(n)) return 1;
      return Math.max(0, Math.min(1, n));
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

    function markQueueInteraction() {
      state.queueInteractionUntilMs = Date.now() + 1400;
    }

    function isQueueInteractionActive() {
      return Date.now() < state.queueInteractionUntilMs;
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
      }
      updatePairingUi();
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
          el.pairingInfo.textContent = "Pairing approved.";
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
          el.pairingInfo.textContent = "Waiting for approval on your phone...";
        }
        checkPairingStatus();
      }, 1500);
    }

    function updatePairingUi() {
      if (state.token) {
        el.pairingState.className = "status-pill paired";
        if (state.syncUnstable) {
          el.pairingState.textContent = "Paired · Syncing…";
        } else if (state.wsConnected) {
          el.pairingState.textContent = "Paired · Live";
        } else {
          el.pairingState.textContent = "Paired · Reconnecting";
        }
        el.pairingCard.style.display = "none";
      } else {
        el.pairingState.className = "status-pill unpaired";
        el.pairingState.textContent = state.waitingPairing ? "Waiting approval" : "Not paired";
        el.pairingCard.style.display = "grid";
      }
    }

    function updatePlaybackStateBadge() {
      if (state.playback.isBuffering) {
        el.playbackState.textContent = "Buffering";
        return;
      }
      if (state.playback.isPlaying) {
        el.playbackState.textContent = "Playing";
        return;
      }
      el.playbackState.textContent = "Paused";
    }

    function updateStatCards() {
      el.statCurrent.textContent = formatMs(state.playback.positionMs);
      el.statDuration.textContent = formatMs(state.playback.durationMs);
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

      if (!artist) {
        el.artistInsightCount.textContent = "-";
        el.artistTracksByArtist.textContent = "0";
        el.artistAlbumsCount.textContent = "0";
        el.artistTotalDuration.textContent = "0%";
        el.artistNextList.innerHTML = "<li class=\\"artist-next-empty\\">No artist info available for this track.</li>";
        return;
      }

      const normArtist = artist.toLowerCase();
      const sameArtistEntries = [];
      queue.forEach((item, index) => {
        const itemArtist = String(item?.artist || "").trim().toLowerCase();
        if (itemArtist && itemArtist === normArtist) {
          sameArtistEntries.push({ item, index });
        }
      });

      let totalPlays = 0;
      let totalCompletion = 0;
      let completionSamples = 0;
      let favoriteCount = 0;
      const sourceSet = new Set();
      for (const entry of sameArtistEntries) {
        totalPlays += Number(entry.item?.playCount || 0);
        const completion = Number(entry.item?.avgListenProgress);
        if (Number.isFinite(completion)) {
          totalCompletion += Math.max(0, Math.min(1, completion));
          completionSamples += 1;
        }
        if (entry.item?.isFavorite === true) favoriteCount += 1;
        const source = String(entry.item?.source || "").trim().toLowerCase();
        if (source) sourceSet.add(source);
      }

      const avgCompletion = completionSamples > 0 ? (totalCompletion / completionSamples) : 0;
      const sourceLabel = sourceSet.size > 0
        ? Array.from(sourceSet).join(" / ")
        : "unknown source";

      el.artistInsightCount.textContent = sameArtistEntries.length + " tracks · " + favoriteCount + " fav · " + sourceLabel;
      el.artistTracksByArtist.textContent = String(sameArtistEntries.length);
      el.artistAlbumsCount.textContent = String(totalPlays);
      el.artistTotalDuration.textContent = Math.round(avgCompletion * 100) + "%";

      const upcoming = sameArtistEntries
        .filter((entry) => entry.index > state.currentQueueIndex)
        .slice(0, 4);

      el.artistNextList.innerHTML = "";
      if (upcoming.length === 0) {
        const emptyItem = document.createElement("li");
        emptyItem.className = "artist-next-empty";
        emptyItem.textContent = "No more tracks from this artist in the current queue.";
        el.artistNextList.appendChild(emptyItem);
        return;
      }

      upcoming.forEach(({ item, index }) => {
        const title = escapeHtml(item?.title || "Unknown");
        const source = escapeHtml(String(item?.source || "").trim() || "source unknown");
        const plays = Number(item?.playCount || 0);
        const subtitle = source + " · " + plays + (plays === 1 ? " play" : " plays");
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
      const incomingPos = playback.positionMs || 0;
      const audioPos = Math.floor((Number(el.audioPlayer.currentTime || 0)) * 1000);
      const isPlayingLike = !!playback.isPlaying || state.playback.isPlaying;
      let resolvedPos = incomingPos;
      if (sameTrack && isPlayingLike) {
        const safeAudioPos = Number.isFinite(audioPos) && audioPos > 0 ? audioPos : 0;
        resolvedPos = Math.max(state.playback.positionMs || 0, safeAudioPos, incomingPos);
      }

      state.playback = {
        positionMs: resolvedPos,
        durationMs: playback.durationMs || 0,
        isPlaying: !!playback.isPlaying,
        isBuffering: !!playback.isBuffering,
        volume: typeof playback.volume === "number" ? playback.volume : 1
      };
      state.queue = queue;
      state.currentQueueIndex = normalizedQueueIndex;
      state.currentTrackId = nextTrackId;

      el.title.textContent = track?.title || "No track";
      el.artist.textContent = track?.artist || "—";
      const infoParts = [];
      const source = String(track?.source || "").trim();
      const origin = String(track?.origin || "").trim();
      const country = String(track?.country || "").trim();
      if (source) infoParts.push(source);
      if (origin) infoParts.push(origin);
      if (country) infoParts.push(country);
      if (track?.isFavorite === true) infoParts.push("favorite");
      el.album.textContent = infoParts.length > 0
        ? "Info: " + infoParts.join(" · ")
        : "Info: —";
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
      el.btnPlayPause.textContent = state.playback.isPlaying ? "Pause" : "Play";

      updatePlaybackStateBadge();
      updateStatCards();
      renderQueue();
      refreshAudioSource();
    }

    function renderQueue() {
      const signature = queueSignature(state.queue);
      const queueChanged = signature !== state.lastRenderedQueueSignature;
      const indexChanged = state.currentQueueIndex !== state.lastRenderedQueueIndex;
      const trackChanged = state.currentTrackId !== state.lastRenderedTrackId;

      const countLabel = state.queue.length + " track" + (state.queue.length === 1 ? "" : "s");
      el.queueCount.textContent = countLabel;

      if (!queueChanged && !indexChanged && !trackChanged) {
        return;
      }

      const previousScrollLeft = el.queueCarousel.scrollLeft;
      el.queueCarousel.innerHTML = "";
      el.queueList.innerHTML = "";

      state.queue.forEach((item, i) => {
        const isActive = i === state.currentQueueIndex;
        const title = escapeHtml(item.title || "Unknown");
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
      if (!state.token || !state.currentTrackId) return;
      const src = withToken("/stream/current?track=" + encodeURIComponent(state.currentTrackId));
      if (state.currentAudioSrc !== src) {
        state.currentAudioSrc = src;
        el.audioPlayer.src = src;
      }
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
      el.pairingInfo.textContent = "Sending request...";
      try {
        const response = await api("/api/pairing/request", "POST", {
          clientId: state.clientId,
          clientName: navigator.userAgent
        });
        if (response?.status === "already_paired" && response?.token) {
          setToken(response.token);
          state.waitingPairing = false;
          el.pairingInfo.textContent = "Already paired.";
          if (response?.session) {
            renderNowPlaying(response.session);
          } else {
            await loadSession();
          }
          connectWs();
        } else {
          el.pairingInfo.textContent = "Request sent. Approve on your phone.";
          startPairingPolling();
          checkPairingStatus();
        }
      } catch (e) {
        el.pairingInfo.textContent = "Could not request pairing.";
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
          el.pairingInfo.textContent = "Session expired. Request pairing again.";
          updatePairingUi();
          return;
        }

        state.syncUnstable = true;
        el.pairingInfo.textContent = "Sync unstable. Reconnecting…";
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
            el.pairingInfo.textContent = "Session ended on phone.";
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
            el.pairingInfo.textContent = "Pairing rejected on phone.";
            updatePairingUi();
            break;
          case "currentTrackChanged":
          case "playbackStateChanged":
          case "queueChanged":
            renderNowPlaying(msg.payload || {});
            break;
          case "progressUpdated":
            if (msg.payload) {
              const incomingPos = msg.payload.positionMs || 0;
              const audioPos = Math.floor((Number(el.audioPlayer.currentTime || 0)) * 1000);
              if (state.playback.isPlaying && Number.isFinite(audioPos) && audioPos > 0) {
                state.playback.positionMs = Math.max(audioPos, incomingPos);
              } else {
                state.playback.positionMs = incomingPos;
              }
              markSessionSyncNow();
              state.playback.durationMs = msg.payload.durationMs || 0;
              state.playback.isPlaying = !!msg.payload.isPlaying;
              state.playback.isBuffering = !!msg.payload.isBuffering;
              el.timeCurrent.textContent = formatMs(state.playback.positionMs);
              el.timeDuration.textContent = formatMs(state.playback.durationMs);
              el.seekBar.value = state.playback.durationMs > 0
                ? Math.floor((state.playback.positionMs / state.playback.durationMs) * 1000)
                : 0;
              el.btnPlayPause.textContent = state.playback.isPlaying ? "Pause" : "Play";
              updatePlaybackStateBadge();
              updateStatCards();
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
      if (el.audioPlayer.duration && Number.isFinite(el.audioPlayer.duration)) {
        el.audioPlayer.currentTime = state.playback.positionMs / 1000;
      }
      updateStatCards();
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
          el.pairingInfo.textContent = "Session expired. Request pairing again.";
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
      el.btnPlayPause.textContent = "Pause";
      updatePlaybackStateBadge();
    });
    el.audioPlayer.addEventListener("pause", () => {
      state.playback.isPlaying = false;
      el.btnPlayPause.textContent = "Play";
      updatePlaybackStateBadge();
    });

    function startSessionPolling() {
      if (state.sessionPollTimer) return;
      state.sessionPollTimer = setInterval(() => {
        if (!state.token) return;
        loadSession();
      }, 2000);
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
        el.pairingInfo.textContent = "Sync unstable. Reconnecting…";
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
    connectWs();
    startSessionPolling();
    startHealthMonitor();
    loadSession();
  </script>
</body>
</html>
''';
}
