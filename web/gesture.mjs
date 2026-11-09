/** Hand tracking is independent of transport. Times are monotonic milliseconds.
 * A hold, deliberate rightward movement and an open release are all required.
 * Losing the hand cancels the grab; it must never count as a release.
 */
export class ThrowGesture {
  constructor() { this.reset(); this.cooldownUntil = 0; }
  reset() { this.phase = 'idle'; this.started = 0; this.startX = 0; this.lastSeen = 0; }
  update({time, x, y, pinch, visible, enabled = true}) {
    if (!enabled) { this.reset(); return {phase:'disabled'}; }
    if (!visible) {
      if (time - this.lastSeen > 180) this.reset();
      return {phase:'no-hand'};
    }
    if (![time,x,y,pinch].every(Number.isFinite)) { this.reset(); return {phase:'no-hand'}; }
    this.lastSeen = time;
    if (time < this.cooldownUntil) return {phase:'cooldown'};
    if (this.phase !== 'idle' && time - this.started > 3500) this.reset();
    if (this.phase === 'idle') {
      if (pinch < .30 && x < .65 && y > .12 && y < .88) {
        this.phase = 'holding'; this.started = time; this.startX = x;
      }
    } else if (this.phase === 'holding') {
      if (pinch > .48) this.reset();
      else if (time - this.started >= 180) this.phase = 'grabbed';
    } else if (this.phase === 'grabbed') {
      if (pinch > .48) {
        const thrown = x > .80 && x - this.startX > .20 && y > .12 && y < .88;
        this.reset();
        if (thrown) { this.cooldownUntil = time + 1200; return {phase:'thrown', thrown:true}; }
      }
    }
    return {phase:this.phase, ready:this.phase === 'grabbed' && x > .80 && y > .12 && y < .88};
  }
}

export function handPoint(landmarks) {
  if (!landmarks || landmarks.length !== 21) return null;
  const distance = (a,b) => Math.hypot(a.x-b.x,a.y-b.y);
  const scale = distance(landmarks[0], landmarks[9]);
  if (scale < .03) return null;
  return {
    // Preview is mirrored so the user's rightward motion feels natural.
    x: 1 - (landmarks[4].x + landmarks[8].x) / 2,
    y: (landmarks[4].y + landmarks[8].y) / 2,
    pinch: distance(landmarks[4], landmarks[8]) / scale,
  };
}
