"""
web.py
------
Simple local web UI for the charging-wattage predictor. Wraps the same
ChargingWattPredictor used by app/main.py -- no prediction logic lives
here, only the HTTP layer and the page markup.

Run:
    python -m app.web
Then open:
    http://localhost:5000        (or http://<pi-ip>:5000 from another device)
"""

import sys
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))

from flask import Flask, jsonify, render_template_string, request

from prediction.predictor import ChargingWattPredictor, ValidationError

app = Flask(__name__)
predictor = ChargingWattPredictor()  # loaded once at startup, reused per request

# Dataset's observed charging_watt range, used to scale the gauge visual.
GAUGE_MIN, GAUGE_MAX = 5, 125


PAGE = r"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Charging Wattage Predictor</title>
<style>
  :root {
    --bg: #0e1416;
    --panel: #161f22;
    --panel-border: #253138;
    --text: #e7eef0;
    --text-dim: #8aa0a8;
    --text-faint: #56676d;
    --amber: #ffb020;
    --green: #4ade80;
    --blue: #5fb4ff;
    --mono: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
    --sans: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    background: var(--bg);
    background-image:
      radial-gradient(circle at 15% 0%, rgba(95,180,255,0.06), transparent 45%),
      radial-gradient(circle at 85% 100%, rgba(255,176,32,0.05), transparent 45%);
    color: var(--text);
    font-family: var(--sans);
    min-height: 100vh;
    padding: 40px 20px 60px;
  }
  .wrap { max-width: 620px; margin: 0 auto; }

  header { margin-bottom: 32px; }
  .eyebrow {
    font-family: var(--mono);
    font-size: 12px;
    letter-spacing: 0.14em;
    text-transform: uppercase;
    color: var(--amber);
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 10px;
  }
  .eyebrow::before {
    content: "";
    width: 7px; height: 7px;
    border-radius: 50%;
    background: var(--amber);
    box-shadow: 0 0 8px var(--amber);
  }
  h1 {
    font-size: 26px;
    margin: 0 0 6px;
    letter-spacing: -0.01em;
  }
  .sub { color: var(--text-dim); font-size: 14.5px; line-height: 1.5; max-width: 46ch; }

  .panel {
    background: var(--panel);
    border: 1px solid var(--panel-border);
    border-radius: 14px;
    padding: 24px;
    margin-bottom: 20px;
  }

  .row { display: flex; gap: 12px; margin-bottom: 14px; }
  .field { flex: 1; display: flex; flex-direction: column; gap: 6px; }
  .field.full { flex: 1 1 100%; }
  label {
    font-size: 12px;
    color: var(--text-dim);
    font-family: var(--mono);
    letter-spacing: 0.02em;
  }
  input, select {
    background: #0e1416;
    border: 1px solid var(--panel-border);
    color: var(--text);
    border-radius: 8px;
    padding: 10px 12px;
    font-size: 14.5px;
    font-family: var(--sans);
    outline: none;
    transition: border-color 0.15s;
    width: 100%;
  }
  input:focus, select:focus { border-color: var(--blue); }
  input::placeholder { color: var(--text-faint); }

  details {
    margin-top: 4px;
    border-top: 1px dashed var(--panel-border);
    padding-top: 14px;
  }
  summary {
    cursor: pointer;
    font-size: 13px;
    color: var(--text-dim);
    font-family: var(--mono);
    user-select: none;
  }
  summary:hover { color: var(--text); }
  .grid3 { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin-top: 14px; }
  .grid2 { display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px; margin-top: 14px; }
  .checks { display: flex; flex-wrap: wrap; gap: 14px; margin-top: 14px; }
  .check { display: flex; align-items: center; gap: 6px; font-size: 13px; color: var(--text-dim); }
  .check input { width: auto; }

  button {
    margin-top: 18px;
    width: 100%;
    background: var(--amber);
    color: #14100a;
    border: none;
    border-radius: 8px;
    padding: 13px;
    font-size: 14.5px;
    font-weight: 600;
    font-family: var(--sans);
    cursor: pointer;
    transition: filter 0.15s, transform 0.05s;
  }
  button:hover { filter: brightness(1.08); }
  button:active { transform: scale(0.995); }
  button:disabled { opacity: 0.5; cursor: progress; }

  /* ---- Result panel ---- */
  #result { display: none; }
  #result.show { display: block; }

  .phone-name { font-family: var(--mono); font-size: 13px; color: var(--text-dim); margin-bottom: 16px; }

  .gauge-readout { display: flex; align-items: baseline; gap: 8px; margin-bottom: 6px; }
  .gauge-value { font-family: var(--mono); font-size: 44px; font-weight: 700; line-height: 1; }
  .gauge-unit { font-family: var(--mono); font-size: 18px; color: var(--text-dim); }

  .gauge-track {
    height: 10px;
    background: #0e1416;
    border: 1px solid var(--panel-border);
    border-radius: 6px;
    overflow: hidden;
    margin-bottom: 14px;
  }
  .gauge-fill {
    height: 100%;
    width: 0%;
    border-radius: 6px;
    background: linear-gradient(90deg, var(--amber), var(--green));
    transition: width 0.6s cubic-bezier(.2,.8,.2,1);
  }
  .gauge-scale {
    display: flex;
    justify-content: space-between;
    font-family: var(--mono);
    font-size: 10.5px;
    color: var(--text-faint);
    margin-bottom: 18px;
  }

  .badge {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-family: var(--mono);
    font-size: 12px;
    letter-spacing: 0.02em;
    padding: 5px 10px;
    border-radius: 999px;
    border: 1px solid;
  }
  .badge.verified { color: var(--green); border-color: rgba(74,222,128,0.35); background: rgba(74,222,128,0.08); }
  .badge.predicted { color: var(--blue); border-color: rgba(95,180,255,0.35); background: rgba(95,180,255,0.08); }
  .badge::before { content: "●"; font-size: 8px; }

  .note {
    margin-top: 14px;
    font-size: 12.5px;
    color: var(--text-dim);
    line-height: 1.5;
    border-left: 2px solid var(--panel-border);
    padding-left: 10px;
  }

  .error {
    display: none;
    background: rgba(255, 90, 90, 0.08);
    border: 1px solid rgba(255, 90, 90, 0.3);
    color: #ff8a8a;
    padding: 12px 14px;
    border-radius: 8px;
    font-size: 13.5px;
    margin-bottom: 20px;
    line-height: 1.5;
  }
  .error.show { display: block; }

  footer { text-align: center; font-size: 11.5px; color: var(--text-faint); font-family: var(--mono); margin-top: 8px; }
</style>
</head>
<body>
<div class="wrap">
  <header>
    <div class="eyebrow">Charging Diagnostics</div>
    <h1>Maximum Charging Wattage</h1>
    <p class="sub">Enter a phone's brand and model to look it up. If it's not in the known
    database, add whatever specs you have and the model will estimate it.</p>
  </header>

  <div class="error" id="error"></div>

  <form class="panel" id="form">
    <div class="row">
      <div class="field">
        <label for="brand">BRAND</label>
        <input id="brand" name="smartphone_brand" placeholder="Xiaomi" required>
      </div>
      <div class="field">
        <label for="model">MODEL</label>
        <input id="model" name="model" placeholder="Redmi Note 14 SE 5G" required>
      </div>
    </div>

    <details id="moreDetails">
      <summary>+ Add specs (helps if the phone isn't in the database)</summary>

      <div class="grid3">
        <div class="field">
          <label for="ram_gb">RAM (GB)</label>
          <input id="ram_gb" name="ram_gb" type="number" step="1" placeholder="8">
        </div>
        <div class="field">
          <label for="storage_gb">STORAGE (GB)</label>
          <input id="storage_gb" name="storage_gb" type="number" step="1" placeholder="128">
        </div>
        <div class="field">
          <label for="battery_mah">BATTERY (mAh)</label>
          <input id="battery_mah" name="battery_mah" type="number" step="1" placeholder="5000">
        </div>
      </div>

      <div class="grid3">
        <div class="field">
          <label for="price_inr">PRICE (INR)</label>
          <input id="price_inr" name="price_inr" type="number" step="1" placeholder="20000">
        </div>
        <div class="field">
          <label for="display_inches">DISPLAY (IN)</label>
          <input id="display_inches" name="display_inches" type="number" step="0.1" placeholder="6.6">
        </div>
        <div class="field">
          <label for="refresh_rate_hz">REFRESH (HZ)</label>
          <input id="refresh_rate_hz" name="refresh_rate_hz" type="number" step="1" placeholder="120">
        </div>
      </div>

      <div class="grid2">
        <div class="field">
          <label for="processor_brand">PROCESSOR BRAND</label>
          <select id="processor_brand" name="processor_brand">
            <option value="">—</option>
            <option value="snapdragon">Snapdragon</option>
            <option value="mediatek">MediaTek</option>
            <option value="exynos">Exynos</option>
            <option value="unisoc">Unisoc</option>
            <option value="apple">Apple</option>
            <option value="tensor">Tensor</option>
          </select>
        </div>
        <div class="field">
          <label for="clock_speed_ghz">CLOCK SPEED (GHZ)</label>
          <input id="clock_speed_ghz" name="clock_speed_ghz" type="number" step="0.1" placeholder="2.4">
        </div>
      </div>

      <div class="checks">
        <label class="check"><input type="checkbox" id="has_5g" name="has_5g"> 5G</label>
        <label class="check"><input type="checkbox" id="has_nfc" name="has_nfc"> NFC</label>
        <label class="check"><input type="checkbox" id="has_ir_blaster" name="has_ir_blaster"> IR blaster</label>
        <label class="check"><input type="checkbox" id="fast_charging" name="fast_charging" checked> Fast charging</label>
      </div>
    </details>

    <button type="submit" id="submitBtn">Predict charging power</button>
  </form>

  <div class="panel" id="result">
    <div class="phone-name" id="phoneName"></div>
    <div class="gauge-readout">
      <div class="gauge-value" id="gaugeValue">--</div>
      <div class="gauge-unit">watts</div>
    </div>
    <div class="gauge-track"><div class="gauge-fill" id="gaugeFill"></div></div>
    <div class="gauge-scale"><span>5W</span><span>65W</span><span>125W</span></div>
    <span class="badge" id="badge"></span>
    <div class="note" id="note" style="display:none;"></div>
  </div>

  <footer>Layer 1: verified database lookup &nbsp;·&nbsp; Layer 2: ML prediction fallback</footer>
</div>

<script>
const form = document.getElementById('form');
const submitBtn = document.getElementById('submitBtn');
const errorBox = document.getElementById('error');
const resultBox = document.getElementById('result');
const GAUGE_MIN = {{ gauge_min }}, GAUGE_MAX = {{ gauge_max }};

form.addEventListener('submit', async (e) => {
  e.preventDefault();
  errorBox.classList.remove('show');
  resultBox.classList.remove('show');
  submitBtn.disabled = true;
  submitBtn.textContent = 'Predicting…';

  const fd = new FormData(form);
  const payload = {};
  for (const [key, value] of fd.entries()) {
    if (value === '') continue;
    payload[key] = value;
  }
  ['has_5g', 'has_nfc', 'has_ir_blaster', 'fast_charging'].forEach(name => {
    payload[name] = form.querySelector(`[name="${name}"]`).checked;
  });

  try {
    const res = await fetch('/api/predict', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Something went wrong.');

    document.getElementById('phoneName').textContent = `${data.brand} ${data.model}`;
    document.getElementById('gaugeValue').textContent = data.charging_watt;
    const pct = Math.max(0, Math.min(100,
      ((data.charging_watt - GAUGE_MIN) / (GAUGE_MAX - GAUGE_MIN)) * 100));
    document.getElementById('gaugeFill').style.width = pct + '%';

    const badge = document.getElementById('badge');
    if (data.source.toLowerCase().includes('database')) {
      badge.className = 'badge verified';
      badge.textContent = 'Verified database match';
    } else {
      badge.className = 'badge predicted';
      badge.textContent = 'Machine learning prediction';
    }

    const noteEl = document.getElementById('note');
    if (data.note) {
      noteEl.style.display = 'block';
      noteEl.textContent = data.note;
    } else {
      noteEl.style.display = 'none';
    }

    resultBox.classList.add('show');
  } catch (err) {
    errorBox.textContent = err.message;
    errorBox.classList.add('show');
  } finally {
    submitBtn.disabled = false;
    submitBtn.textContent = 'Predict charging power';
  }
});
</script>
</body>
</html>
"""


@app.route("/")
def index():
    return render_template_string(PAGE, gauge_min=GAUGE_MIN, gauge_max=GAUGE_MAX)


@app.route("/api/predict", methods=["POST"])
def api_predict():
    payload = request.get_json(silent=True) or {}
    try:
        result = predictor.predict(payload)
    except ValidationError as e:
        return jsonify({"error": str(e)}), 400
    except Exception as e:  # unexpected errors -> generic message, logged server-side
        app.logger.exception("Unexpected prediction error")
        return jsonify({"error": "Prediction failed unexpectedly. Please try again."}), 500

    return jsonify({
        "brand": result.brand.title(),
        "model": result.model,
        "charging_watt": result.charging_watt,
        "source": result.source,
        "note": result.confidence_note,
    })


if __name__ == "__main__":
    # host="0.0.0.0" so it's reachable from other devices on the network
    # (e.g. your phone/laptop hitting the Raspberry Pi's IP address).
    app.run(host="0.0.0.0", port=5000, debug=False)
