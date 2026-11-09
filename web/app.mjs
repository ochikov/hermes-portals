import {drawGraph} from './graph.mjs';
import {HandCamera} from './camera.mjs';
import {KINDS, renderTool} from './tools.mjs';

const $ = id => document.getElementById(id);
let state=null, online=false, busy=false, socket=null, reconnect=null, pairing=null;
let qrUntil=0, camera=null, openingCamera=false, firstSnapshot=true, closed=false;
let lastMessage=0;
let cameraAttempt=0;
let toolController=null;
let macState=null, macBusy=false, macCheck=null;
const fragment = new URLSearchParams(location.hash.slice(1));
const invitation = fragment.get('owner') || fragment.get('pair');
const invitationKind = fragment.has('owner') ? 'owner' : 'phone';
// Keep short-lived invitations out of browser history and referrers.
if (location.hash) history.replaceState(null,'',location.pathname);
window.addEventListener('hashchange',()=>{if(location.hash)location.reload();});

function notice(message) { $('notice').textContent=message; $('notice').hidden=!message; }
function stopBrowserCamera(){
  cameraAttempt++;camera?.stop();openingCamera=false;
  $('camera-toggle').textContent='Enable webcam';$('camera-placeholder').hidden=false;
}
function showWelcome(message) {
  stopBrowserCamera();
  $('room').hidden=true; $('welcome').hidden=false;
  $('welcome-message').textContent=message;
}
async function api(path, body) {
  const response=await fetch('/api/'+path,{method:body===undefined?'GET':'POST',credentials:'same-origin',
    headers:body===undefined?{}:{'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body)});
  const data=await response.json();
  if (!response.ok) {
    if (response.status===409 && data.artifact && state) render({...state,artifact:data.artifact,library:data.library??state.library});
    if (response.status===401) {closed=true;socket?.close();showWelcome(data.detail);}
    throw new Error(typeof data.detail==='string'?data.detail:'Request could not be completed');
  }
  return data;
}
function connection(value) {
  online=value;
  $('connection').textContent=value?'Live':'Reconnecting';
  $('connection').className='connection '+(value?'online':'offline');
  $('transport').textContent=value?'LIVE / SHARED STATE':'CONNECTION LOST / CHANGES PAUSED';
  controls();
}
function controls() {
  const disabled=!online||busy||!state;
  const away=state&&state.artifact.display!==(state.you.role==='owner'?'laptop':'phone');
  for(const input of document.querySelectorAll('#diagram-view button, #tool-view input, #tool-view button')) input.disabled=disabled||away;
  $('recall').disabled=disabled;
  $('handoff').disabled=disabled||away||(state?.you.role==='owner'&&!state?.phone.online);
  $('pair-toggle').disabled=disabled;
  $('revoke').disabled=disabled;
  for(const button of $('library-section').querySelectorAll('button')){
    button.disabled=disabled||(button.hasAttribute('data-template')&&(state?.library?.length??0)>=30);
  }
}
function renderLibrary(data) {
  const entries=data.library??[];
  $('library-count').textContent=`${entries.length} / 30 saved`;
  $('library').replaceChildren(...entries.map(entry=>{
    const button=document.createElement('button');button.type='button';button.dataset.artifact=entry.id;
    button.setAttribute('aria-pressed',String(entry.id===data.artifact.id));
    const title=document.createElement('strong');title.textContent=entry.title;
    const kind=document.createElement('span');kind.textContent=KINDS[entry.kind]??entry.kind;
    button.append(title,kind);button.addEventListener('click',()=>perform({type:'open',artifact_id:entry.id}));return button;
  }));
}
function render(data) {
  if (state && data.artifact.revision<state.artifact.revision) return;
  const previous=state, artifact=data.artifact, role=data.you.role;
  state=data;
  document.body.dataset.role=role;
  $('room').hidden=false; $('welcome').hidden=true; $('pair-form').hidden=true;
  $('owner-controls').hidden=role!=='owner'; $('phone-controls').hidden=role!=='phone';
  $('library-section').hidden=role!=='owner';
  $('device-label').textContent=role==='owner'?'LAPTOP / WORKSPACE':'PHONE / PORTAL';
  $('network-notice').hidden=!data.network.lan;
  $('phone-status').textContent=data.phone.online?`${data.phone.name} · online`:data.phone.paired?'Phone disconnected':'No phone paired';
  $('revoke').hidden=!data.phone.paired;
  $('revision').textContent=`Revision ${artifact.revision}`;
  $('diagram-title').textContent=artifact.title;
  $('artifact-id').textContent=artifact.id.slice(0,8);
  $('tool-kind').textContent=artifact.kind==='diagram'?'INTERACTIVE DIAGRAM · SIMULATION':(KINDS[artifact.kind]??artifact.kind).toUpperCase();
  const changed=!previous||previous.artifact.revision!==artifact.revision;
  if(!previous||previous.artifact.id!==artifact.id||JSON.stringify(previous.library)!==JSON.stringify(data.library))renderLibrary(data);
  const here=role==='owner'?'laptop':'phone', away=artifact.display!==here;
  $('away').hidden=!away;
  $('away-title').textContent=role==='owner'?'On your phone':'On the laptop';
  $('handoff').textContent=role==='owner'?'Send to phone →':'← Return to laptop';
  const diagram=artifact.kind==='diagram';
  $('diagram-view').hidden=!diagram;$('tool-view').hidden=diagram;
  if(changed&&diagram){
  const path=drawGraph($('diagram'),artifact,node=>perform({type:'select',node}));
  $('route-status').textContent=path.length?'Live route: '+path.map(id=>artifact.nodes.find(n=>n.id===id).label).join(' → '):'No available path. Restore a node to reconnect the route.';
  $('route-status').classList.toggle('down',!path.length);
  $('node-buttons').replaceChildren(...artifact.nodes.map(node=>{
    const button=document.createElement('button'); button.type='button';button.textContent=node.label;
    button.setAttribute('aria-pressed',String(artifact.selected===node.id));
    button.addEventListener('click',()=>perform({type:'select',node:node.id}));return button;
  }));
  const selected=artifact.nodes.find(node=>node.id===artifact.selected);
  $('selected-label').textContent=selected?.label||'';
  $('toggle-node').textContent=artifact.disabled.includes(artifact.selected)?'Restore node':'Simulate failure';
  }else if(changed){toolController=renderTool($('tool-view'),artifact,perform);}
  if (previous && previous.artifact.display!==artifact.display && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
    const card=$('diagram-card');card.classList.remove('arriving','departing');
    void card.offsetWidth;card.classList.add(away?'departing':'arriving');
  }
  if (data.phone.paired && data.phone.id!==previous?.phone.id) {$('qr-box').hidden=true;pairing=null;}
  controls();
  if (firstSnapshot && role==='owner' && !data.phone.paired) newPair();
  firstSnapshot=false;
}
async function perform(action) {
  if (!online||busy||!state) return;
  const artifactId=state.artifact.id;
  busy=true;controls();notice('');
  try {
    // Commit every typed calculator value before handing off or changing tools.
    // A failed/conflicting save stops the transition instead of dropping edits.
    const values=state.artifact.kind==='calculator'?toolController?.pendingValues():null;
    if(values&&Object.keys(values).length)render(await api('action',{type:'set_values',values,revision:state.artifact.revision}));
    if(state.artifact.id!==artifactId)throw new Error('The active tool changed. Review it before trying again.');
    if(action.type!=='save')render(await api('action',{...action,revision:state.artifact.revision}));
    else if(state.artifact.kind==='calculator')toolController=renderTool($('tool-view'),state.artifact,perform);
  }
  catch(error){
    notice(error.message);
    if(state?.artifact.kind!=='diagram')toolController=renderTool($('tool-view'),state.artifact,perform);
  }
  finally {busy=false;controls();}
}
function connect() {
  if(closed) return;
  clearTimeout(reconnect);
  socket=new WebSocket(`${location.protocol==='https:'?'wss':'ws'}://${location.host}/ws`);
  socket.onmessage=event=>{
    try {render(JSON.parse(event.data));lastMessage=Date.now();connection(true);}
    catch(error){notice('Could not read the live state: '+error.message);}
  };
  socket.onclose=event=>{
    connection(false);
    if(event.code===4401){closed=true;showWelcome('Device access expired or was revoked. Open a new invitation.');return;}
    if(!closed) reconnect=setTimeout(connect,1200);
  };
  socket.onerror=()=>socket.close();
}
async function newPair() {
  try {
    pairing=await api('pair',{});qrUntil=Date.now()+pairing.expires_in*1000;
    notice('');
    $('qr-image').src=pairing.qr;$('qr-box').hidden=false;
    $('pair-link').href=pairing.url;$('pair-link').hidden=false;
    $('qr-hint').textContent=pairing.lan?"Scan with your phone's camera. Use the same Wi-Fi.":'Local-only mode. Restart with /portals start <laptop LAN IP> to connect a phone.';
    updateExpiry();
  } catch(error){notice(error.message);}
}
function updateExpiry() {
  if(!pairing) return;
  const seconds=Math.max(0,Math.ceil((qrUntil-Date.now())/1000));
  $('qr-expiry').textContent=seconds?`One-use invitation · ${seconds}s remaining`:'Expired. Tap New QR to pair.';
  if(!seconds){$('qr-image').removeAttribute('src');$('qr-image').hidden=true;$('pair-link').hidden=true;}
  else $('qr-image').hidden=false;
}
async function enter(token,kind,name) {
  await api('exchange',{token,kind,name});
  closed=false;render(await api('state'));connect();
}
function renderMac(data){
  macState=data;$('mac-control').hidden=!data.supported;
  $('mac-open').disabled=macBusy||!data.installed;
  $('mac-stop').disabled=macBusy||!data.running||(!data.capturing&&!data.starting);
  const text=!data.installed?'Native controller needs setup. See /portals mac open.':
    data.starting?'Waiting for camera permission…':data.control_enabled?(data.armed?'Mac control active · Escape to stop':'Control paused · follow the live hand guide'):
    data.capturing?'Preview only · Mac input is off':data.running?'Controller open · choose a mode in its window':'Controller is off';
  $('mac-status').textContent=text;
  if((data.capturing||data.starting)&&(camera?.active||openingCamera))stopBrowserCamera();
}
async function refreshMac(){
  if(state?.you.role!=='owner'||!['127.0.0.1','localhost'].includes(location.hostname))return macState;
  if(macCheck)return macCheck;
  macCheck=api('mac/status').then(data=>{renderMac(data);return data;});
  try {return await macCheck;}
  finally {macCheck=null;}
}
async function macAction(action){
  macBusy=true;notice('');
  if(action==='open')stopBrowserCamera();
  if(macState)renderMac(macState);
  try {const data=await api('mac/'+action,{});renderMac(data);}
  catch(error){notice(error.message);}
  finally {macBusy=false;if(macState)renderMac(macState);await refreshMac().catch(()=>{});}
}
$('mac-open').addEventListener('click',()=>macAction('open'));
$('mac-stop').addEventListener('click',()=>macAction('stop'));
$('pair-form').addEventListener('submit',async event=>{
  event.preventDefault();const button=event.submitter;button.disabled=true;
  try {await enter(invitation,'phone',$('phone-name').value.trim()||'My phone');notice('');}
  catch(error){notice(error.message);button.disabled=false;}
});
$('pair-toggle').addEventListener('click',newPair);
for(const button of document.querySelectorAll('[data-template]'))button.addEventListener('click',()=>perform({type:'template',template:button.dataset.template}));
$('revoke').addEventListener('click',async()=>{try{render(await api('revoke',{}));notice('Phone disconnected.');}catch(error){notice(error.message);}});
$('toggle-node').addEventListener('click',()=>perform({type:'set_node',node:state.artifact.selected,enabled:state.artifact.disabled.includes(state.artifact.selected)}));
$('restore').addEventListener('click',()=>perform({type:'restore'}));
$('handoff').addEventListener('click',()=>perform({type:'handoff',target:state.you.role==='owner'?'phone':'laptop'}));
$('recall').addEventListener('click',()=>perform({type:'handoff',target:state.you.role==='owner'?'laptop':'phone'}));
$('camera-toggle').addEventListener('click',async()=>{
  if(camera?.active||openingCamera){stopBrowserCamera();return;}
  const attempt=++cameraAttempt;
  openingCamera=true;$('camera-toggle').textContent='Cancel camera startup';notice('');
  try {
    const native=await refreshMac();
    if(native?.capturing||native?.starting){notice('Stop the Mac controller before enabling the Portals camera.');return;}
    if(attempt!==cameraAttempt||document.hidden||closed)return;
  }catch(error){stopBrowserCamera();notice('Could not check Mac controller status. Try again before starting the camera.');return;}
  if(!camera) camera=new HandCamera({video:$('camera'),canvas:$('hand-overlay'),status:$('gesture-status'),pointer:$('hand-pointer'),
    onThrow:()=>perform({type:'handoff',target:'phone'}),
    enabled:()=>online&&!busy&&state?.phone.online&&state?.artifact.display==='laptop',
    onStopped:()=>{$('camera-toggle').textContent='Enable webcam';$('camera-placeholder').hidden=false;openingCamera=false;},
  });
  try {
    await camera.start();
    if(camera.active){$('camera-toggle').textContent='Disable webcam';$('camera-placeholder').hidden=true;}
  } catch(error){notice(error.name==='NotAllowedError'?'Camera access was declined. You can still use the transfer button.':error.message);}
  finally {if(attempt===cameraAttempt){openingCamera=false;if(!camera.active)$('camera-toggle').textContent='Enable webcam';}}
});
document.addEventListener('visibilitychange',()=>{
  if(document.hidden){stopBrowserCamera();$('gesture-status').textContent='Camera stopped while this page is hidden. Enable it to resume.';}
  if(!document.hidden)refreshMac().catch(()=>{});
});
window.addEventListener('pagehide',()=>{stopBrowserCamera();closed=true;clearTimeout(reconnect);socket?.close();});
window.addEventListener('pageshow',event=>{if(event.persisted){closed=false;connect();}});
setInterval(()=>{updateExpiry();if(online&&lastMessage&&Date.now()-lastMessage>12000){connection(false);socket?.close();}},1000);
setInterval(()=>{if(!document.hidden&&!closed)refreshMac().catch(()=>{});},2000);
let diagramWidth=0;
new ResizeObserver(()=>{
  const width=$('diagram').clientWidth;
  if(state?.artifact.kind==='diagram'&&width&&width!==diagramWidth){diagramWidth=width;drawGraph($('diagram'),state.artifact,node=>perform({type:'select',node}));}
}).observe($('diagram-card'));

try {
  if(invitation&&invitationKind==='phone') {
    showWelcome('Connect this phone to your Portals workspace.');$('pair-form').hidden=false;
  } else if(invitation) {await enter(invitation,'owner','Laptop');}
  else {render(await api('state'));connect();}
} catch(error) {showWelcome(error.message);}
refreshMac().catch(()=>{});
