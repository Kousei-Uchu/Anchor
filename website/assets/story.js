(() => {
  const stage = document.querySelector('.stage');
  if (!stage) return;
  const slides = [...stage.querySelectorAll('.slide')], pf = document.getElementById('pf'), lockov = stage.querySelector('.lockov');
  const tabs = [0, 1, 0, 2, 3, 0, 0], scrolls = [0, 0, 440, 0, 0, 0, 0], N = slides.length;
  const send = () => { try { pf.contentWindow.postMessage({ tab: tabs[step], scroll: scrolls[step] }, location.origin); } catch (e) {} };
  pf.addEventListener('load', () => setTimeout(send, 300));
  const pos = [[0,0,0,0],[8,6,-6,-4],[14,-4,-12,6],[2,10,-2,-10],[-8,2,8,4],[6,-8,-8,8],[0,0,0,0]];
  let step = 0, lock = false, lastT = 0, lastD = 0, startY = null, captured = false, consumed = false;
  const dots = stage.querySelector('.dots');
  slides.forEach((_, i) => { const b = document.createElement('button'); b.setAttribute('aria-label', 'Step ' + (i + 1)); b.onclick = () => go(i); dots.append(b); });
  function render() {
    slides.forEach((s, i) => s.className = 'slide ' + (i < step ? 'past' : i > step ? 'next' : 'on'));
    lockov.classList.toggle('on', step === 5);
    send();
    [...dots.children].forEach((d, i) => d.classList.toggle('on', i === step));
    const p = pos[step];
    stage.style.setProperty('--x1', p[0] + 'vmax'); stage.style.setProperty('--y1', p[1] + 'vmax');
    stage.style.setProperty('--x2', p[2] + 'vmax'); stage.style.setProperty('--y2', p[3] + 'vmax');
    stage.dataset.step = step;
  }
  function go(n) {
    if (n < 0 || n >= N || n === step) return;
    step = n; lock = true; render();
    setTimeout(() => lock = false, 950);
  }
  const atTop = () => window.scrollY < 4;
  const leave = () => document.getElementById('about').scrollIntoView({ behavior: 'smooth' });
  const canMove = d => (d > 0 && step < N - 1) || (d < 0 && step > 0);
  addEventListener('wheel', e => {
    const now = performance.now(), a = Math.abs(e.deltaY);
    const fresh = now - lastT > 120 || a > lastD * 1.6;
    lastT = now; lastD = a;
    if (!atTop() || a < 4) return;
    const exit = step === N - 1 && e.deltaY > 0;
    if (!canMove(e.deltaY) && !exit) return;
    e.preventDefault();
    if (lock || !fresh) return;
    if (exit) leave(); else go(step + (e.deltaY > 0 ? 1 : -1));
  }, { passive: false });
  addEventListener('touchstart', e => { startY = e.touches[0].clientY; captured = false; consumed = false; }, { passive: true });
  addEventListener('touchmove', e => {
    if (startY == null || !atTop()) return;
    const d = startY - e.touches[0].clientY;
    const exit = step === N - 1 && d > 0;
    if (!captured && !canMove(d) && !exit) return;
    captured = true; e.preventDefault();
    if (!consumed && !lock && Math.abs(d) > 36) { consumed = true; if (step === N - 1 && d > 0) leave(); else go(step + (d > 0 ? 1 : -1)); }
  }, { passive: false });
  addEventListener('touchend', () => { startY = null; captured = false; });
  addEventListener('keydown', e => {
    if (/INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName)) return;
    const k = { ArrowDown: 1, PageDown: 1, ArrowUp: -1, PageUp: -1, ' ': e.shiftKey ? -1 : 1 }[e.key];
    if (!k || !atTop()) return;
    if (k > 0 && step === N - 1) { e.preventDefault(); leave(); }
    else if (canMove(k)) { e.preventDefault(); if (!lock) go(step + k); }
  });
  stage.querySelector('.cue').onclick = () => go(1);
  render();
})();
