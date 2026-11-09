import {BONES,MODES,DURATION,STEP_TIMES,sampleGesture} from './hand-demo-motion.mjs';
import {mountPractice} from './hand-practice.mjs';

const COPY={
  badge:['PLAYGROUND','ПОЛЕ ЗА ИГРА'],title:['Don’t watch.\nMake it move.','Раздвижи го.\nС твоята ръка.'],
  intro:['Your camera, your hand, a tiny world to move. Try a real gesture — or grab the card with your mouse.','Твоята камера, твоята ръка и малък свят за пренасяне. Пробвай с истински жест или хвани картата с мишката.'],
  transfer:['Send to phone','Към телефона'],tap:['Index tap','Тап с показалец'],scroll:['Scroll','Скрол'],switch:['Switch apps','Смяна на апове'],
  illustration:['ILLUSTRATED HAND · NO CAMERA FEED','СИМУЛИРАНА РЪКА · БЕЗ ВИДЕО'],landmarks:['21 illustrated joints','21 очертани стави'],
  resultLabel:['DEMO RESULT','РЕЗУЛТАТ В ДЕМОТО'],play:['Play demo','Пусни демото'],pause:['Pause','Пауза'],replay:['↺ Replay','↺ Отначало'],
  timeline:['Animation position','Позиция в анимацията'],
  motionNote:['Reduced motion is on. Select a numbered step to view a still pose, or choose Play demo.','Намалените анимации са включени. Избери стъпка за неподвижен пример или пусни демото.'],
  disclaimer:['Practice here, then return to Portals to send a real tool between paired devices.','Упражнявай се тук, после се върни в Portals за истински трансфер между свързаните устройства.'],
  reference:['See illustrated examples of all four gestures','Виж анимирани примери за четирите жеста'],
  back:['← Back to Portals','← Обратно към Portals'],phone:['PHONE','ТЕЛЕФОН'],click:['Click here','Кликни тук'],
  clicked:['1 demo click','1 демо клик'],step:['STEP','СТЪПКА'],modes:['Gesture examples','Примери за жестове'],
  steps:['Jump to a step','Избери стъпка'],canvas:['Illustrated hand with joint landmarks; the current movement is described beside it.','Анимирана ръка с очертани стави. До нея е описана текущата стъпка.'],
  region:['Illustrated gesture demonstration','Анимирана демонстрация на жестове'],
};
const GUIDES={
  transfer:{
    kicker:['BROWSER CAMERA / PORTALS','КАМЕРА В БРАУЗЪРА / PORTALS'],title:['Pick it up. Bring its state along.','Вземи го. Запази промените.'],
    steps:[['Start on the left','Започни отляво'],['Pinch & hold','Щипни и задръж'],['Move right','Премести надясно'],['Open to release','Отвори пръстите']],
    descriptions:[
      ['Show one hand on the left side of the mirrored camera preview.','Покажи една ръка в лявата част на огледалния изглед от камерата.'],
      ['Touch your thumb and index finger. Keep the pinch closed briefly to grab.','Допри палец и показалец. Задръж щипката за кратко, за да „хванеш“.'],
      ['Keep the pinch closed as you move into the PHONE region on the right.','Дръж пръстите допрени и премести ръката в зоната ТЕЛЕФОН вдясно.'],
      ['Separate your fingers inside the portal. The real tool keeps its edits when it transfers.','Раздели пръстите в портала. При истинско прехвърляне промените в инструмента се запазват.'],
    ],
    result:[['Demo tool · laptop','Демо инструмент · лаптоп'],['Demo tool · phone','Демо инструмент · телефон']],
    detail:['Server A stays offline in both views. This illustrated transfer changes no real device.','Server A остава offline и в двата изгледа. Анимацията не променя реално устройство.'],
    note:['For a real transfer: pair an online phone, keep the tool on the laptop, then enable the browser webcam.','За истински трансфер: свържи телефон, остави инструмента на лаптопа и включи камерата в браузъра.'],
  },
  tap:{
    kicker:['NATIVE MAC CONTROL / INDEX TAP','УПРАВЛЕНИЕ НА MAC / ТАП С ПОКАЗАЛЕЦ'],title:['Aim. Bend. Click on the return.','Прицели се. Свий. Изправи.'],
    steps:[['Point to aim','Посочи целта'],['Hold your palm','Задръж дланта'],['Bend & return','Свий и изправи'],['One click','Един клик']],
    descriptions:[
      ['Point with your index finger. Move your whole hand to position the cursor.','Изправи показалеца. Движи цялата ръка, за да позиционираш курсора.'],
      ['Pause over the target. Keep your palm still; the thumb is not part of this gesture.','Спри върху целта. Задръж дланта неподвижна; палецът не участва в този жест.'],
      ['Bend just your index finger downward, then straighten it. The click target stays locked.','Свий само показалеца надолу и го изправи. Мястото за клика остава фиксирано.'],
      ['A completed bend-and-return produces one click. Relax before the next tap.','Завършеното свиване и изправяне дава един клик. Отпусни преди следващия тап.'],
    ],
    result:[['Target stays still','Целта остава на място'],['1 illustrated click','1 клик в анимацията']],
    detail:['The orange cue shows a pending tap. Only this demo target changes.','Оранжевата точка показва започнат тап. Променя се само демо целта.'],
    note:['Real Mac input needs the native helper, Camera and Accessibility. Start Mac control, then hold an open palm to arm. Escape stops it.','Реалното управление изисква Mac компонента, Camera и Accessibility. Включи управлението и задръж отворена длан. Escape го спира.'],
  },
  scroll:{
    kicker:['NATIVE MAC CONTROL / TWO FINGERS','УПРАВЛЕНИЕ НА MAC / ДВА ПРЪСТА'],title:['Two fingers. Both directions.','Два пръста. Две посоки.'],
    steps:[['Aim at content','Посочи полето'],['Raise two fingers','Вдигни два пръста'],['Move up & down','Нагоре и надолу'],['Relax to finish','Отпусни ръката']],
    descriptions:[
      ['First place the cursor inside the area you want to scroll.','Първо постави курсора в полето, което искаш да скролваш.'],
      ['Raise your index and middle fingers. Keep the ring and little fingers curled.','Изправи показалеца и средния пръст. Дръж безименния и кутрето свити.'],
      ['Move the two-finger pose vertically, then reverse direction. Keep the motion gentle.','Движи ръката с двата изправени пръста вертикално, после обърни посоката. Движи бавно.'],
      ['Relax your fingers to leave the scroll pose. Scroll direction can depend on system settings.','Отпусни пръстите, за да излезеш от жеста. Посоката на скрола може да зависи от системните настройки.'],
    ],
    result:[['Demo content ready','Демо съдържание'],['Up, then back down','Нагоре и обратно']],
    detail:['Only the illustrated list moves. No page or application receives scroll events.','Движи се само нарисуваният списък. Нито страница, нито приложение получава скрол събития.'],
    note:['Use the native Mac controller for real input. Position the cursor before raising the second finger. Escape stops control.','За реален скрол използвай Mac компонента. Позиционирай курсора, преди да вдигнеш втория пръст. Escape спира управлението.'],
  },
  switch:{
    kicker:['NATIVE MAC CONTROL / PALM SWIPE','УПРАВЛЕНИЕ НА MAC / ПЛЪЗГАНЕ С ДЛАН'],title:['An open palm. A different app.','Отворена длан. Друго приложение.'],
    steps:[['Open your palm','Отвори дланта'],['Hold briefly','Задръж за кратко'],['Swipe sideways','Плъзни настрани'],['Relax to reset','Отпусни пръстите']],
    descriptions:[
      ['Show an open palm with your fingers comfortably spread.','Покажи отворена длан с удобно разперени пръсти.'],
      ['Hold the palm still briefly before beginning the sideways movement.','Задръж дланта неподвижна за кратко, преди да я преместиш настрани.'],
      ['Swipe horizontally to the right. A leftward swipe moves in the opposite direction.','Плъзни хоризонтално надясно. Движение наляво превключва в обратната посока.'],
      ['Relax your fingers before repeating. Real apps are visited in alphabetical order.','Отпусни пръстите преди следващия жест. Реалните приложения се обхождат по азбучен ред.'],
    ],
    result:[['Canvas · demo window','Canvas · демо прозорец'],['Notes · demo window','Notes · демо прозорец']],
    detail:['These are illustrated windows. Your running apps stay untouched.','Това са нарисувани прозорци. Отворените ти приложения не се променят.'],
    note:['The real gesture switches running apps; it does not send a Mac app to the phone. Use the native controller. Escape stops control.','Истинският жест сменя работещите приложения; не ги изпраща към телефона. Използвай Mac компонента. Escape спира управлението.'],
  },
};

const $=id=>document.getElementById(id),canvas=$('stage'),ctx=canvas.getContext('2d');
const W=canvas.width,H=canvas.height;
const motion=matchMedia('(prefers-reduced-motion: reduce)');
const query=new URLSearchParams(location.search);
let mode=MODES.includes(query.get('gesture'))?query.get('gesture'):'transfer';
let language='en',time=0,playing=false,frame=null,last=null,previousText='',practice=null;
try {if(localStorage.getItem('portals-gesture-language')==='bg')language='bg';}catch{}
const tr=pair=>pair[language==='bg'?1:0];
const text=(key)=>tr(COPY[key]);
function rounded(x,y,w,h,r,fill,stroke){ctx.beginPath();ctx.roundRect(x,y,w,h,r);if(fill){ctx.fillStyle=fill;ctx.fill();}if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=1.5;ctx.stroke();}}
function label(value,x,y,size=16,color='#a0b1b0',align='left'){
  ctx.font=`${size}px -apple-system,BlinkMacSystemFont,Segoe UI,sans-serif`;ctx.fillStyle=color;ctx.textAlign=align;ctx.fillText(value,x,y);
}
function line(a,b,color,width=2){ctx.strokeStyle=color;ctx.lineWidth=width;ctx.beginPath();ctx.moveTo(...a);ctx.lineTo(...b);ctx.stroke();}
function dot(x,y,r,color){ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.fillStyle=color;ctx.fill();}
function toolCard(x,y,scale=1){
  ctx.save();ctx.translate(x,y);ctx.scale(scale,scale);
  ctx.shadowColor='#a9f4cd24';ctx.shadowBlur=28;
  rounded(-82,-57,164,114,14,'#1c3035','#6a9a91');ctx.shadowBlur=0;
  label('PORTABLE TOOL',-65,-33,11,'#bbd7d0');
  line([-49,-5],[0,-5],'#6a8c83',2);line([0,-5],[48,-5],'#6a8c83',2);
  line([0,-5],[24,28],'#a9f4cd',2);dot(-49,-5,6,'#a9f4cd');dot(0,-5,6,'#a9f4cd');
  dot(48,-5,6,'#f39c95');dot(24,28,6,'#a9f4cd');label('A: OFFLINE',-65,43,10,'#f39c95');ctx.restore();
}
function windowPreview(x,y,title,active=false){
  rounded(x,y,265,265,16,active?'#243d38':'#17262c',active?'#a9f4cd':'#496066');
  for(let i=0;i<3;i++)dot(x+20+i*16,y+22,4,['#f39c95','#ffbf8c','#a9f4cd'][i]);
  label(title,x+23,y+67,25,active?'#c7ffe2':'#cedbd7');
  for(let i=0;i<4;i++)rounded(x+23,y+92+i*31,i===0?160:210,9,4,'#839f973b');
  label('DEMO',x+23,y+242,11,'#91a8a3');
}
function scene(s){
  ctx.clearRect(0,0,W,H);
  const light=ctx.createRadialGradient(W*.33,H*.5,20,W*.4,H*.5,W*.7);
  light.addColorStop(0,'#18313a');light.addColorStop(1,'#0b1418');ctx.fillStyle=light;ctx.fillRect(0,0,W,H);
  ctx.save();ctx.strokeStyle='#6a9da915';ctx.lineWidth=1;
  for(let x=32;x<W;x+=44){ctx.beginPath();ctx.moveTo(x,55);ctx.lineTo(x,H-47);ctx.stroke();}
  for(let y=62;y<H-45;y+=44){ctx.beginPath();ctx.moveTo(25,y);ctx.lineTo(W-25,y);ctx.stroke();}
  for(const [x,y,sx,sy] of [[24,58,1,1],[W-24,58,-1,1],[24,H-45,1,-1],[W-24,H-45,-1,-1]]){
    ctx.beginPath();ctx.moveTo(x+20*sx,y);ctx.lineTo(x,y);ctx.lineTo(x,y+20*sy);ctx.strokeStyle='#6c9aa575';ctx.lineWidth=2;ctx.stroke();
  }
  ctx.restore();
  if(mode==='transfer'){
    rounded(W*.8,78,W*.18,H-135,18,s.result?'#a9f4cd19':'#a9f4cd09','#85d9b848');
    label(text('phone'),W*.89,115,15,'#a9f4cd','center');
    ctx.save();ctx.setLineDash([5,9]);line([W*.8,135],[W*.8,H-75],'#a9f4cd70',2);ctx.restore();
    rounded(W*.89-67,150,134,232,19,'#0d1d22','#739d9480');rounded(W*.89-20,159,40,5,3,'#739d9480');
    let x=W*.22,y=H*.22,scale=1;
    if(s.time>=1.9){x=s.point.x*W;y=s.point.y*H-110;}
    if(s.result){x+=(W*.89-x)*s.amount;y+=(265-y)*s.amount;scale=1-.36*s.amount;}
    toolCard(x,y,scale);
    if(s.grip>.5&&!s.result){ctx.save();ctx.setLineDash([4,7]);line([s.point.x*W,s.point.y*H],[x,y+57], '#ffbf8c80',2);ctx.restore();}
    if(s.result)label(language==='bg'?'СЪСТОЯНИЕТО Е ЗАПАЗЕНО':'STATE KEPT',W*.89,425,11,'#a9f4cd','center');
  }else if(mode==='tap'){
    rounded(W*.63,167,W*.31,270,18,'#15242a','#4b6870');
    label('DEMO TARGET',W*.66,207,13,'#91a8a3');
    rounded(W*.665,248,W*.24,100,13,s.result?'#a9f4cd':'#28433f',s.result?'#a9f4cd':'#79b39b');
    label(text(s.result?'clicked':'click'),W*.785,308,24,s.result?'#13281f':'#c1f4d6','center');
    const x=W*.785,y=H*.45;
    ctx.beginPath();ctx.arc(x,y,23+s.grip*7,0,Math.PI*2);ctx.strokeStyle=s.grip>.1?'#ffbf8c':'#bdaaff';ctx.lineWidth=3;ctx.stroke();
    dot(x,y,5,s.grip>.1?'#ffbf8c':'#bdaaff');
    label(language==='bg'?'ФИКСИРАНА ЦЕЛ':'LOCKED TARGET',W*.785,401,12,'#bdaaff','center');
  }else if(mode==='scroll'){
    rounded(W*.63,142,W*.31,364,18,'#15242a','#4b6870');
    label('DEMO CONTENT',W*.66,181,13,'#91a8a3');
    ctx.save();ctx.beginPath();ctx.rect(W*.65,201,W*.26,278);ctx.clip();
    for(let i=0;i<8;i++){
      const y=214+i*69-s.amount*152;
      rounded(W*.66,y,W*.23,54,8,i%2?'#233d38':'#25363f');
      label(String(i+1).padStart(2,'0'),W*.675,y+33,16,'#a9f4cd');rounded(W*.72,y+25,W*.13,5,2,'#a8c2b155');
    }
    ctx.restore();rounded(W*.919,208,4,265,2,'#3a5156');rounded(W*.919,208+s.amount*143,4,70,2,'#a9f4cd');
    label('↕',W*.56,H*.48,46,'#bdaaff','center');
  }else{
    windowPreview(W*.59,150,'Canvas');windowPreview(W*.67,192,s.result?'Notes':'Canvas',s.result);
    if(s.time>2.6){ctx.save();ctx.setLineDash([6,9]);line([W*.22,H*.65],[W*.55,H*.65],'#bdaaff90',3);ctx.restore();label('→',W*.56,H*.67,38,'#bdaaff');}
  }
  drawHand(s);
}
function drawHand(s){
  const p=s.landmarks.map(v=>[v.x*W,v.y*H]);
  ctx.save();ctx.lineCap='round';ctx.lineJoin='round';
  // A translucent palm and tapered fingers keep the landmark model legible.
  ctx.beginPath();ctx.moveTo(...p[0]);
  for(const i of [1,5,9,13,17])ctx.lineTo(...p[i]);ctx.closePath();
  const skin=ctx.createLinearGradient(p[1][0],0,p[17][0],0);skin.addColorStop(0,'#356e738a');skin.addColorStop(.55,'#7fbaa566');skin.addColorStop(1,'#3a5d7080');
  ctx.fillStyle=skin;ctx.fill();ctx.strokeStyle='#b5ffe260';ctx.lineWidth=2;ctx.stroke();
  for(const start of [1,5,9,13,17]){
    for(let j=0;j<3;j++){
      line(p[start+j],p[start+j+1],'#0a141ae0',30-j*5);
      line(p[start+j],p[start+j+1],skin,26-j*5);
    }
  }
  ctx.shadowColor='#a9f4cd80';ctx.shadowBlur=12;
  for(const [a,b] of BONES)line(p[a],p[b],'#acedd1a0',2.4);
  p.forEach(([x,y],i)=>{dot(x,y,i===0?7:5.5,'#0e292e');dot(x,y,i===0?4:3.3,'#bdfde0');});
  ctx.shadowBlur=0;
  const target=mode==='transfer'?[s.point.x*W,s.point.y*H]:p[8];
  const color=s.grip>.2?'#ffbf8c':'#bdaaff';
  ctx.beginPath();ctx.arc(...target,16+s.grip*7,0,Math.PI*2);ctx.lineWidth=2.5;ctx.strokeStyle=color;ctx.stroke();
  dot(...target,5,color);
  ctx.restore();
}
function updateText(s){
  const key=`${mode}:${language}:${s.step}:${s.result}`;
  if(key===previousText)return;previousText=key;
  const g=GUIDES[mode];
  $('mode-kicker').textContent=tr(g.kicker);$('mode-title').textContent=tr(g.title);
  $('step-count').textContent=`${text('step')} ${String(s.step+1).padStart(2,'0')} / 04`;
  $('step-title').textContent=tr(g.steps[s.step]);$('step-description').textContent=tr(g.descriptions[s.step]);
  $('result-title').textContent=tr(g.result[s.result?1:0]);$('result-detail').textContent=tr(g.detail);
  $('mode-note').textContent=tr(g.note);$('pose-label').textContent=tr(g.steps[s.step]).toUpperCase();
  for(const [i,button] of [...$('steps').children].entries()){
    button.setAttribute('aria-current',i===s.step?'step':'false');button.lastChild.textContent=tr(g.steps[i]);
  }
  for(const button of $('modes').querySelectorAll('button'))button.setAttribute('aria-pressed',String(button.dataset.mode===mode));
}
function paint(){const s=sampleGesture(mode,time);scene(s);updateText(s);$('timeline').value=String(time);$('time').textContent=`${time.toFixed(1)} / ${DURATION} s`;}
function updatePlay(){
  $('play').replaceChildren(document.createTextNode(playing?'Ⅱ ':'▶ '),document.createTextNode(text(playing?'pause':'play')));
  $('play').setAttribute('aria-label',text(playing?'pause':'play'));
}
function pause(){playing=false;cancelAnimationFrame(frame);frame=null;last=null;updatePlay();}
function tick(stamp){
  if(!playing)return;
  if(last!==null)time=Math.min(DURATION,time+(stamp-last)/1000);
  last=stamp;paint();
  if(time>=DURATION){pause();return;}
  frame=requestAnimationFrame(tick);
}
function play(){if(playing)return;if(time>=DURATION)time=0;playing=true;last=null;updatePlay();frame=requestAnimationFrame(tick);}
function languageChanged(){
  document.documentElement.lang=language;$('language').value=language;
  document.title=language==='bg'?'Hermes Portals · Лаборатория за жестове':'Hermes Portals · Gesture Lab';
  for(const el of document.querySelectorAll('[data-copy]'))el.textContent=text(el.dataset.copy);
  $('timeline').setAttribute('aria-label',text('timeline'));$('modes').setAttribute('aria-label',text('modes'));
  $('steps').setAttribute('aria-label',text('steps'));canvas.setAttribute('aria-label',text('canvas'));
  document.querySelector('.demo-card').setAttribute('aria-label',text('region'));
  updatePlay();paint();practice?.translate();
}
for(let i=0;i<4;i++){
  const button=document.createElement('button');button.type='button';
  const number=document.createElement('span');number.textContent=String(i+1).padStart(2,'0');
  button.append(number,document.createTextNode(''));
  button.addEventListener('click',()=>{pause();time=STEP_TIMES[mode][i];paint();});$('steps').append(button);
}
$('modes').addEventListener('click',event=>{
  const button=event.target.closest('button[data-mode]');if(!button)return;
  pause();mode=button.dataset.mode;time=0;paint();if(!motion.matches)play();
});
$('play').addEventListener('click',()=>playing?pause():play());
$('replay').addEventListener('click',()=>{pause();time=0;paint();play();});
$('timeline').addEventListener('input',event=>{pause();time=Number(event.target.value);paint();});
$('language').addEventListener('change',event=>{
  language=event.target.value==='bg'?'bg':'en';try{localStorage.setItem('portals-gesture-language',language);}catch{}
  languageChanged();
});
document.addEventListener('visibilitychange',()=>{if(document.hidden)pause();});
document.addEventListener('keydown',event=>{if(event.key==='Escape')pause();});
window.addEventListener('pagehide',pause);
motion.addEventListener('change',()=>{$('motion-note').hidden=!motion.matches;if(motion.matches)pause();});
$('motion-note').hidden=!motion.matches;
const reference=$('reference-guide');
reference.open=MODES.includes(query.get('gesture'));
reference.addEventListener('toggle',()=>{if(reference.open){practice?.stop();if(!motion.matches&&!document.hidden)play();}else pause();});
practice=mountPractice({getLanguage:()=>language,beforeCamera:()=>{pause();reference.open=false;}});
languageChanged();if(reference.open&&!motion.matches&&!document.hidden)play();
