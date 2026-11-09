import {HandCamera} from './camera.mjs';
import {PracticeRoom,previewPoint} from './hand-practice-model.mjs';

const COPY={
  eyebrow:['YOUR HAND / YOUR PLAYGROUND','ТВОЯТА РЪКА / ТВОЯТ ТЕСТ'],title:['Pick up a little world.','Хвани цял малък свят.'],
  mouse:['Mouse / touch','Мишка / докосване'],privacy:['Local video · no recording · Esc to stop','Локално видео · без запис · Esc за стоп'],
  local:['PRACTICE / THIS PAGE ONLY','УПРАЖНЕНИЕ / САМО ТУК'],phone:['PHONE','ТЕЛЕФОН'],portable:['INTERACTIVE TOOL','ИНТЕРАКТИВЕН ИНСТРУМЕНТ'],cardTitle:['A resilient service','Устойчива система'],
  permission:['The camera is optional. This exercise moves a sample card inside this page; it does not send it to a real phone or control your Mac.','Камерата е по избор. Тук местиш пробна карта в страницата. Не я изпращаш към реален телефон и не управляваш Mac-а.'],
  start:['◉ Start camera','◉ Включи камерата'],stop:['■ Stop camera','■ Спри камерата'],cancel:['Cancel startup','Откажи включването'],
  off:['CAMERA OFF','КАМЕРА ИЗКЛЮЧЕНА'],live:['LIVE CAMERA','ЖИВА КАМЕРА'],starting:['STARTING…','ВКЛЮЧВАНЕ…'],
  pointer:['MOUSE / TOUCH','МИШКА / ДОКОСВАНЕ'],keyboard:['KEYBOARD','КЛАВИАТУРА'],camera:['YOUR LIVE HAND','ТВОЯТА РЪКА НА ЖИВО'],
  pointerTip:['Drag the card → let go inside the phone','Плъзни картата → пусни я в телефона'],
  cameraTip:['Pinch the card → move right → open your fingers','Щипни картата → надясно → отвори пръстите'],
  keyboardTip:['Space to grab · arrows to move · Space to release','Space за хващане · стрелки за движение · Space за пускане'],
  restore:['Restore Server A','Възстанови Server A'],fail:['Turn off Server A','Изключи Server A'],again:['↺ Try again','↺ Опитай пак'],back:['← Bring it back','← Върни картата'],
  kept:['State preserved','Състоянието е запазено'],cameraCount:['camera transfers','трансфери с камера'],pointerCount:['mouse / touch transfers','трансфери с мишка / допир'],keyboardCount:['keyboard transfers','трансфери с клавиатура'],
  access:['Open Portals on localhost and sign in first, so we can check that Mac control is stopped. Mouse practice is available here.','Първо отвори Portals през localhost и влез в сесията, за да проверим дали Mac управлението е спряно. Тестът с мишка работи и сега.'],
  conflict:['Stop camera capture in Hermes Portals Control first, then try again.','Първо спри камерата в Hermes Portals Control, после опитай отново.'],
  denied:['Camera access was denied. Allow it in the browser site settings, or use mouse / touch.','Достъпът до камерата е отказан. Разреши го от настройките на сайта в браузъра или използвай мишка / докосване.'],
  unavailable:['Could not start hand tracking. Check camera access and the local camera assets, then try again. Mouse / touch still works.','Проследяването не се включи. Провери достъпа до камерата и локалните файлове за разпознаване, после опитай пак. Мишката / докосването работят.'],
  interrupted:['Camera tracking stopped. Start it again when ready; no transfer was counted.','Проследяването с камерата спря. Включи го отново, когато си готов. Прекъсването не се отчита като трансфер.'],
};
const FEEDBACK={
  ready:[['Grab the card.','Хвани картата.'],['Drag it to the glowing phone on the right. Or focus the card, press Space, then use the arrow keys.','Плъзни я към светещия телефон вдясно. Или избери картата с Tab, натисни Space и използвай стрелките.']],
  cameraReady:[['Find the card with your hand.','Посочи картата с ръка.'],['Show one hand. Move the purple ring over the card, then touch thumb and index finger and hold briefly.','Покажи една ръка. Постави лилавия кръг върху картата, допри палец и показалец и задръж за кратко.']],
  hover:[['You found it. Pinch to grab.','Намери я. Щипни, за да я хванеш.'],['Touch thumb and index finger over the card and keep them together.','Допри палец и показалец върху картата и ги задръж допрени.']],
  holding:[['Hold the pinch…','Задръж щипката…'],['Almost there. Keep thumb and index finger together until the card lifts.','Почти готово. Дръж палец и показалец допрени, докато картата се повдигне.']],
  dragging:[['You have it. Move right.','Хвана я. Премести надясно.'],['Keep holding until you reach the phone. The card brings its current state along.','Продължи да държиш до телефона. Картата носи текущото си състояние със себе си.']],
  release:[['Inside the portal. Let go.','В портала си. Пусни.'],['Open your fingers, release the mouse, or press Space — depending on your input mode.','Отвори пръстите, пусни мишката или натисни Space — според избрания режим.']],
  delivered:[['Same world. New screen.','Същият свят. Нов екран.'],['You completed the practice transfer. Change Server A or bring the card back and try it again.','Завърши пробния трансфер. Промени Server A или върни картата и опитай отново.']],
  lost:[['Looking for your hand…','Търся ръката…'],['Keep one hand inside the camera view. A lost hand never counts as a release; grab the card again if it returns.','Дръж една ръка в кадър. Загубената ръка не се брои за пускане; хвани картата отново, ако се върне.']],
  'one-hand':[['One hand at a time.','По една ръка.'],['Show just one hand, then grab the card again.','Остави само една ръка в кадър и хвани картата отново.']],
  cancelled:[['Back here. Try again.','Отново тук. Опитай пак.'],['Hold the card all the way into the phone before releasing it.','Дръж картата чак до телефона, преди да я пуснеш.']],
  loading:[['Preparing your camera…','Подготвям камерата…'],['Allow camera access if your browser asks. You can cancel at any time.','Разреши камерата, ако браузърът попита. Можеш да откажеш по всяко време.']],
};

export function mountPractice({getLanguage,beforeCamera=()=>{}}){
  const $=id=>document.getElementById('practice-'+id),room=new PracticeRoom();
  let source='pointer',camera=null,opening=false,attempt=0,monitor=null,errorKey='',pointerId=null;
  let previousFeedback='',previousTotal=0,checking=false,confettiTimer=null;
  const tr=pair=>pair[getLanguage()==='bg'?1:0],text=key=>tr(COPY[key]);
  const stage=$('stage'),card=$('card'),video=$('video');
  function burst(){
    clearTimeout(confettiTimer);$('confetti').replaceChildren();
    if(!matchMedia('(prefers-reduced-motion: reduce)').matches)for(let i=0;i<12;i++){
      const particle=document.createElement('i');
      particle.style.setProperty('--dx',`${Math.cos(i*Math.PI/6)*90}px`);
      particle.style.setProperty('--dy',`${Math.sin(i*Math.PI/6)*90}px`);
      particle.style.background=i%2?'#bbaaff':'#a9f4cd';$('confetti').append(particle);
    }
    confettiTimer=setTimeout(()=>$('confetti').replaceChildren(),900);
  }
  function render(){
    const active=!!camera?.active;
    stage.dataset.phase=room.phase;card.style.left=`${room.position.x*100}%`;card.style.top=`${room.position.y*100}%`;
    card.dataset.offline=String(room.offline);card.setAttribute('aria-disabled',String(active||opening||room.location==='phone'));
    card.setAttribute('aria-label',`${text('cardTitle')}. ${text(source+'Tip')}`);
    $('card-state').textContent=`Server A · ${room.offline?'OFFLINE':'ONLINE'}`;
    $('state').textContent=text(room.offline?'restore':'fail');$('reset').textContent=text(room.location==='phone'?'back':'again');
    $('camera').textContent=text(opening?'cancel':active?'stop':'start');
    $('mouse').setAttribute('aria-pressed',String(!active&&!opening));
    $('signal').textContent=text(opening?'starting':active?'live':'off');$('signal').dataset.live=String(active);
    $('source').textContent=text(source==='camera'&&!active?'off':source);
    $('stage-tip').textContent=text((source==='camera'&&!active?'pointer':source)+'Tip');
    $('score').textContent=String(room.counts[source]);$('score-label').textContent=text(source+'Count');
    $('result').textContent=room.location==='phone'?`${text('kept')} · Server A ${room.offline?'OFFLINE':'ONLINE'}`:'';
    $('progress').style.width=`${room.hold*100}%`;
    const feedback=FEEDBACK[opening?'loading':active&&room.phase==='ready'?'cameraReady':room.phase]||FEEDBACK.ready;
    const title=tr(feedback[0]),description=tr(feedback[1]),key=title+description;
    if(previousFeedback!==key){$('feedback').textContent=title;$('instruction').textContent=description;previousFeedback=key;}
    $('error').hidden=!errorKey;$('error').textContent=errorKey?text(errorKey):'';
    const total=Object.values(room.counts).reduce((a,b)=>a+b,0);if(total>previousTotal)burst();previousTotal=total;
  }
  function releaseCapture(){
    if(pointerId!==null&&card.hasPointerCapture(pointerId))card.releasePointerCapture(pointerId);
    pointerId=null;
  }
  function stop(){
    attempt++;opening=false;clearInterval(monitor);monitor=null;releaseCapture();
    camera?.stop();video.hidden=true;stage.style.aspectRatio='';room.cancel();render();
  }
  async function nativeStatus(){
    if(!['127.0.0.1','localhost'].includes(location.hostname))throw new Error('access');
    const response=await fetch('/api/mac/status',{credentials:'same-origin',cache:'no-store',signal:AbortSignal.timeout(3500)});
    if(!response.ok)throw new Error('access');
    const status=await response.json();
    if(typeof status.supported!=='boolean')throw new Error('access');
    if(status.capturing||status.starting)throw new Error('conflict');
  }
  async function checkWhileActive(){
    if(checking||(!camera?.active&&!opening))return;
    const current=attempt;checking=true;
    try{await nativeStatus();}
    catch(error){if(current===attempt){stop();errorKey=error.message==='conflict'?'conflict':'access';render();}}
    finally{checking=false;}
  }
  async function start(){
    if(opening||camera?.active){stop();return;}
    beforeCamera();releaseCapture();room.reset();source='camera';opening=true;errorKey='';const current=++attempt;render();
    try{
      try{await nativeStatus();}catch(error){throw new Error(error.message==='conflict'?'conflict':'access');}
      if(current!==attempt||document.hidden)return;
      camera??=new HandCamera({video,canvas:$('joints'),pointer:$('pointer'),status:$('engine-status'),
        onFrame:frame=>{
          if(!camera.active||document.hidden)return;
          const p=previewPoint(frame.point,video.videoWidth,video.videoHeight,stage.clientWidth,stage.clientHeight);
          room.camera({...frame,point:p});
          $('pointer').hidden=!p;
          if(p){$('pointer').style.left=`${p.x*100}%`;$('pointer').style.top=`${p.y*100}%`;$('pointer').dataset.grabbed=String(['holding','dragging','release'].includes(room.phase));}
          render();
        },onError:()=>{stop();errorKey='interrupted';render();},
      });
      monitor=setInterval(checkWhileActive,1500);
      await camera.start();
      if(current!==attempt||document.hidden)return;
      opening=false;video.hidden=false;render();stage.scrollIntoView({block:'center'});
    }catch(error){
      if(current!==attempt)return;
      stop();errorKey=['access','conflict'].includes(error.message)?error.message:error.name==='NotAllowedError'?'denied':'unavailable';render();
    }
  }
  const point=event=>{const rect=stage.getBoundingClientRect();return{x:(event.clientX-rect.left)/rect.width,y:(event.clientY-rect.top)/rect.height};};
  card.addEventListener('pointerdown',event=>{
    if(opening||camera?.active||event.button!==0||pointerId!==null)return;
    const p=point(event);if(!room.begin(p))return;
    event.preventDefault();source='pointer';errorKey='';pointerId=event.pointerId;card.setPointerCapture(pointerId);card.focus({preventScroll:true});render();
  });
  card.addEventListener('pointermove',event=>{if(event.pointerId===pointerId){room.pointer(point(event));render();}});
  card.addEventListener('pointerup',event=>{if(event.pointerId===pointerId){room.release(point(event));releaseCapture();render();}});
  card.addEventListener('lostpointercapture',()=>{if(pointerId!==null){pointerId=null;room.cancel();render();}});
  card.addEventListener('pointercancel',()=>{releaseCapture();room.cancel();render();});
  card.addEventListener('keydown',event=>{
    if(camera?.active||opening||pointerId!==null)return;
    if([' ','Enter'].includes(event.key)){
      event.preventDefault();if(event.repeat)return;source='keyboard';errorKey='';
      if(room.drag)room.release(room.lastPoint);else room.begin(room.position,'keyboard');render();
    }else if(event.key.startsWith('Arrow')&&room.drag?.source==='keyboard'){
      event.preventDefault();const p={...room.lastPoint};
      p.x=Math.max(.05,Math.min(.95,p.x+(event.key==='ArrowLeft'?-.07:event.key==='ArrowRight'?.07:0)));
      p.y=Math.max(.05,Math.min(.95,p.y+(event.key==='ArrowUp'?-.07:event.key==='ArrowDown'?.07:0)));
      room.pointer(p);render();
    }
  });
  $('camera').addEventListener('click',start);
  $('mouse').addEventListener('click',()=>{stop();source='pointer';errorKey='';render();});
  $('reset').addEventListener('click',()=>{releaseCapture();room.reset();errorKey='';render();});
  $('state').addEventListener('click',()=>{room.offline=!room.offline;render();});
  document.addEventListener('keydown',event=>{if(event.key==='Escape'){stop();render();}});
  document.addEventListener('visibilitychange',()=>{if(document.hidden)stop();});
  window.addEventListener('pagehide',()=>{stop();clearTimeout(confettiTimer);});
  function translate(){for(const el of document.querySelectorAll('[data-practice]'))el.textContent=text(el.dataset.practice);render();}
  translate();return{translate,stop};
}
