import {ThrowGesture, handPoint} from './gesture.mjs';

const CONNECTIONS = [[0,1],[1,2],[2,3],[3,4],[0,5],[5,6],[6,7],[7,8],
  [5,9],[9,10],[10,11],[11,12],[9,13],[13,14],[14,15],[15,16],
  [13,17],[0,17],[17,18],[18,19],[19,20]];

export class HandCamera {
  constructor({video,canvas,status,pointer,onThrow,enabled,onStopped,onFrame,onError}) {
    Object.assign(this,{video,canvas,status,pointer,onThrow,enabled,onStopped,onFrame,onError});
    this.gesture = new ThrowGesture(); this.generation = 0; this.active = false;
    this.lastFrame = -1; this.lastInference = 0; this.lastThrow = false;
  }
  async start() {
    const generation = ++this.generation;
    if (!window.isSecureContext || !navigator.mediaDevices?.getUserMedia) {
      throw new Error('Open the laptop link at http://127.0.0.1. Browsers require localhost or HTTPS for camera access.');
    }
    this.status.textContent = 'Loading local hand tracker…';
    const {FilesetResolver,HandLandmarker} = await import('/static/vendor/vision_bundle.mjs');
    if (generation !== this.generation) return;
    const files = await FilesetResolver.forVisionTasks('/static/vendor/wasm');
    if (generation !== this.generation) return;
    const tracker = await HandLandmarker.createFromOptions(files, {
      baseOptions: {modelAssetPath:'/static/vendor/hand_landmarker.task',delegate:'CPU'},
      runningMode:'VIDEO', numHands:this.onFrame?2:1,
      minHandDetectionConfidence:.65, minHandPresenceConfidence:.65, minTrackingConfidence:.65,
    });
    if (generation !== this.generation) { tracker.close(); return; }
    this.tracker = tracker;
    let stream;
    try {
      this.status.textContent = 'Allow camera access in this tab to start hand tracking.';
      stream = await navigator.mediaDevices.getUserMedia({audio:false,video:{width:{ideal:640},height:{ideal:480},facingMode:'user'}});
      if (generation !== this.generation) { stream.getTracks().forEach(t=>t.stop()); return; }
      this.stream = stream; this.video.srcObject = stream; await this.video.play();
      stream.getVideoTracks().forEach(track=>track.addEventListener('ended',()=>{
        if(generation===this.generation){this.stop();this.onError?.(new Error('Camera stream ended'));}
      },{once:true}));
    } catch (error) { if(generation !== this.generation) return; this.stop(); throw error; }
    if (generation !== this.generation) return;
    this.active = true; this.lastFrame = -1; this.gesture.reset();
    this.status.textContent = 'Show one hand. Pinch on the left, hold, move right, then release.';
    this.frame = requestAnimationFrame(time=>this.tick(time));
  }
  stop() {
    this.generation++; this.active = false; cancelAnimationFrame(this.frame);
    this.stream?.getTracks().forEach(t=>t.stop()); this.stream = null;
    this.video.srcObject = null; this.tracker?.close(); this.tracker = null;
    this.canvas.getContext('2d').clearRect(0,0,this.canvas.width,this.canvas.height);
    this.pointer.hidden = true; this.gesture.reset(); this.onStopped?.();
    this.status.textContent = 'Camera is off. Enable it to track your hand locally.';
  }
  tick(time) {
    if (!this.active) return;
    try {
      if (this.video.readyState >= 2 && this.video.currentTime !== this.lastFrame && time-this.lastInference > 65) {
        this.lastFrame = this.video.currentTime; this.lastInference = time;
        const result = this.tracker.detectForVideo(this.video,time);
        const landmarks = this.onFrame&&result.landmarks.length!==1?null:result.landmarks[0], point = handPoint(landmarks);
        this.draw(landmarks);
        // Raw preview consumers never enter the real handoff branch below.
        if(this.onFrame){
          this.onFrame({time,landmarks,point,hands:result.landmarks.length});
          this.frame=requestAnimationFrame(next=>this.tick(next));return;
        }
        const progress = this.gesture.update({time,visible:!!point,...point,enabled:this.enabled()});
        if (point) {
          this.pointer.hidden = false;
          this.pointer.style.left = `${Math.max(0,Math.min(1,point.x))*100}%`;
          this.pointer.style.top = `${Math.max(0,Math.min(1,point.y))*100}%`;
          this.pointer.dataset.grabbed = String(['grabbed','holding'].includes(progress.phase));
        } else this.pointer.hidden = true;
        const labels = {
          idle:'Pinch on the left to grab the tool.', holding:'Hold the pinch…',
          grabbed:progress.ready?'Release to send to your phone.':'Keep pinching and move to the right portal.',
          'no-hand':'Show one hand in the camera.', disabled:'Pair an online phone and bring the tool to the laptop.',
          cooldown:'Transfer sent.', thrown:'Sending the same tool to your phone…',
        };
        this.status.textContent = labels[progress.phase] || '';
        if (progress.thrown) Promise.resolve(this.onThrow()).catch(error=>{this.status.textContent=error.message;});
      }
    } catch (error) {
      this.stop(); this.status.textContent = `Hand tracking stopped: ${error.message}`;this.onError?.(error); return;
    }
    this.frame = requestAnimationFrame(next=>this.tick(next));
  }
  draw(landmarks) {
    const canvas=this.canvas, ctx=canvas.getContext('2d');
    const width=canvas.width=this.onFrame?(this.video.videoWidth||640):640;
    const height=canvas.height=this.onFrame?(this.video.videoHeight||480):480;
    ctx.clearRect(0,0,width,height);
    if (!landmarks) return;
    ctx.strokeStyle='#8eeec8';ctx.fillStyle='#8eeec8';ctx.lineWidth=3;
    for (const [a,b] of CONNECTIONS) {
      ctx.beginPath();ctx.moveTo((1-landmarks[a].x)*width,landmarks[a].y*height);
      ctx.lineTo((1-landmarks[b].x)*width,landmarks[b].y*height);ctx.stroke();
    }
    for (const point of landmarks) {ctx.beginPath();ctx.arc((1-point.x)*width,point.y*height,4,0,Math.PI*2);ctx.fill();}
  }
}
