const $=id=>document.getElementById(id);
let clicks=0,wheels=0,maximum=0,away=0,returns=0,wasAway=false,lastWheelLog=0;
let presses=0,releases=0,outsideClicks=0,pointerInside=false;
let language='en',native=null;
try{if(localStorage.getItem('portals-gesture-language')==='bg')language='bg';}catch{}
const copy={
  fresh:['New trial. Counters are zero.','Нов тест. Броячите са нула.'],
  click:['Target click received · total {count}','Получен клик в целта · общо {count}'],
  pointerIn:['Pointer is over the target','Курсорът е върху целта'],
  pointerOut:['Pointer is outside the target','Курсорът е извън целта'],
  inputCounts:['Presses: {presses} · Releases: {releases} · Clicks outside: {outside}','Натискания: {presses} · Отпускания: {releases} · Кликове извън целта: {outside}'],
  pressIn:['Mouse down received inside target','Получено натискане вътре в целта'],
  pressOut:['Mouse down received outside target','Получено натискане извън целта'],
  releaseIn:['Mouse up received inside target','Получено отпускане вътре в целта'],
  releaseOut:['Mouse up received outside target','Получено отпускане извън целта'],
  outsideClick:['Click received outside target','Получен клик извън целта'],
  down:['Vertical scroll received · down','Получен вертикален скрол · надолу'],
  up:['Vertical scroll received · up','Получен вертикален скрол · нагоре'],
  blur:['The page lost focus','Страницата изгуби фокус'],
  focus:['Focus returned to the page','Фокусът се върна в страницата'],
  checking:['Checking the controller…','Проверявам контролера…'],
  unavailable:['Check the mode in the Mac controller window','Виж режима в прозореца на Mac контролера'],
  closed:['The controller is closed','Контролерът е затворен'],
  permission:['Accessibility is not allowed yet','Accessibility още не е разрешено'],
  armed:['Control is active · Escape stops it','Управлението е активно · Escape спира'],
  waiting:['Control paused · follow the live hand guide','Управлението е на пауза · виж указанията до камерата'],
  preview:['Preview only · Mac input is off','Само преглед · няма управление на Mac'],
  ready:['Permissions ready · choose Start Mac control','Разрешенията са готови · избери „Управлявай Mac“'],
  tapName:['Index tap','Тапване с показалец'],
  pinchName:['Thumb + index pinch','Палец + показалец'],
  tapGuide:['① Point comfortably: start at screen center. Slow movement aims precisely; faster movement travels further.\n② Keep your palm still; bend your index down, then up — one click.\n③ Orange means a tap is pending; the counter confirms a click. “Recenter” resets your starting position.', '① Посочи удобно: начало в центъра. Бавно движение за точно прицелване; по-бързо — за по-голям ход.\n② Дланта стои; свий показалеца надолу, после нагоре — един клик.\n③ Оранжевото показва започнат жест; броячът потвърждава клика. „Центрирай“ задава нова начална позиция.'],
  pinchGuide:['① Point at the target and pause.\n② Touch thumb and index tips briefly.\n③ Separate them and point again — click on release.', '① Посочи целта и спри за момент.\n② Допри палец и показалец за около половин секунда.\n③ Раздели ги и посочи пак — кликът е при отпускане.'],
};
const entries=[{key:'fresh',params:{},at:null}];
function t(key,params={}){return copy[key][language==='en'?0:1].replace(/\{(\w+)\}/g,(_,name)=>params[name]??'');}
const labels=[...document.querySelectorAll('[data-en]')].map(el=>({el,bg:el.textContent,en:el.dataset.en}));
const ariaLabels=[...document.querySelectorAll('[data-en-aria]')].map(el=>({el,bg:el.getAttribute('aria-label'),en:el.dataset.enAria}));
function renderJournal(){
  $('events').replaceChildren(...entries.map(entry=>{
    const li=document.createElement('li');
    li.textContent=(entry.at?`${entry.at.toLocaleTimeString(language==='bg'?'bg-BG':'en-GB')} · `:'')+t(entry.key,entry.params);
    return li;
  }));
}
function renderStatus(){
  const key=native===null?'checking':native===false?'unavailable':!native.running?'closed':!native.accessibility_allowed?'permission':native.control_enabled?(native.armed?'armed':'waiting'):native.capturing?'preview':'ready';
  $('native-status').textContent=t(key);
  const pinch=native?.running&&native.click_gesture==='pinch';
  $('click-gesture-name').textContent=t(pinch?'pinchName':'tapName');
  $('click-instructions').textContent=t(pinch?'pinchGuide':'tapGuide');
}
function renderInput(){
  $('pointer-position').textContent=t(pointerInside?'pointerIn':'pointerOut');
  $('input-counts').textContent=t('inputCounts',{presses,releases,outside:outsideClicks});
}
function setLanguage(value){
  language=value==='en'?'en':'bg';document.documentElement.lang=language;
  document.title=language==='en'?'Portals · Gesture test':'Portals · Тест на жестове';
  $('test-language').value=language;
  for(const label of labels)label.el.textContent=label[language];
  for(const label of ariaLabels)label.el.setAttribute('aria-label',label[language]);
  renderJournal();renderStatus();renderInput();
  try{localStorage.setItem('portals-gesture-language',language);}catch{}
}
function log(key,params={}){
  entries.unshift({key,params,at:new Date()});entries.length=Math.min(entries.length,10);renderJournal();
}
$('test-language').addEventListener('change',event=>setLanguage(event.target.value));
document.addEventListener('mousemove',event=>{
  if(!event.isTrusted)return;
  pointerInside=$('target').contains(event.target);renderInput();
},{passive:true});
document.documentElement.addEventListener('mouseleave',()=>{pointerInside=false;renderInput();});
for(const kind of ['mousedown','mouseup','click']){
  document.addEventListener(kind,event=>{
    if(!event.isTrusted||event.button!==0)return;
    const inside=$('target').contains(event.target);
    if(kind==='mousedown'){presses++;log(inside?'pressIn':'pressOut');}
    else if(kind==='mouseup'){releases++;log(inside?'releaseIn':'releaseOut');}
    else if(!inside){outsideClicks++;log('outsideClick');}
    renderInput();
  },true);
}
$('target').addEventListener('click',event=>{
  if(!event.isTrusted)return;
  $('click-count').textContent=String(++clicks);$('target').classList.add('success');log('click',{count:clicks});
});
$('scroll-area').addEventListener('wheel',event=>{
  if(!event.isTrusted||event.deltaY===0)return;
  $('wheel-count').textContent=String(++wheels);
  if(performance.now()-lastWheelLog>750){lastWheelLog=performance.now();log(event.deltaY>0?'down':'up');}
},{passive:true});
$('scroll-area').addEventListener('scroll',()=>{
  maximum=Math.max(maximum,$('scroll-area').scrollTop);$('scroll-max').textContent=`${Math.round(maximum)} px`;
},{passive:true});
window.addEventListener('blur',()=>{if(wasAway)return;wasAway=true;away++;$('focus-count').textContent=`${away} / ${returns}`;log('blur');});
window.addEventListener('focus',()=>{if(!wasAway)return;wasAway=false;returns++;$('focus-count').textContent=`${away} / ${returns}`;log('focus');});
async function status(){
  try{
    const response=await fetch('/api/mac/status',{credentials:'same-origin'});
    if(!response.ok)throw Error('owner session required');
    native=await response.json();
  }catch{native=false;}
  renderStatus();
}
setLanguage(language);status();setInterval(status,2000);
