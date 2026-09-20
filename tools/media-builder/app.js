/* UI adapted from MiSTer-Phosphor's media builder, GPL-2.0-or-later. */
(() => {
 'use strict';const $=id=>document.getElementById(id),api=RasterPlaylist;
 const state={tracks:[],pending:[],url:'',result:null,busy:true};
 const size=n=>n>=2**30?(n/2**30).toFixed(2)+' GiB':(n/2**20).toFixed(1)+' MiB';
 function message(s){$('status').textContent=s}
 function invalidate(){if(state.url)URL.revokeObjectURL(state.url);state.url='';state.result=null;$('download').hidden=true;$('save').hidden=true}
 function button(text,action,disabled=false){const b=document.createElement('button');b.textContent=text;b.disabled=disabled;b.onclick=action;return b}
 function render(){
  $('tracks').replaceChildren();state.tracks.forEach((t,i)=>{
   const li=document.createElement('li');li.className='track';
   const label=document.createElement('span');label.className='track-name';label.textContent=t.movie.name+' · '+size(t.movie.size);
   const sub=document.createElement('span');sub.className='track-meta';sub.textContent=t.subtitle?'Linked: '+t.subtitle.name:'No linked subtitles';label.append(sub);
   const controls=document.createElement('span');controls.className='controls';
   for(const [text,delta] of [['↑',-1],['↓',1]])controls.append(button(text,()=>{const [track]=state.tracks.splice(i,1);state.tracks.splice(i+delta,0,track);invalidate();render()},state.busy||i+delta<0||i+delta>=state.tracks.length));
   controls.append(button('SRT…',()=>{const input=document.createElement('input');input.type='file';input.accept='.srt';input.onchange=()=>{if(input.files[0]){t.subtitle=input.files[0];invalidate();render()}};input.click()},state.busy));
   if(t.subtitle)controls.append(button('Unlink',()=>{t.subtitle=null;invalidate();render()},state.busy));
   controls.append(button('Remove',()=>{state.tracks.splice(i,1);invalidate();render()},state.busy));li.append(label,controls);$('tracks').append(li);
  });
  $('summary').textContent=state.tracks.length?state.tracks.length+' movies · '+state.tracks.filter(t=>t.subtitle).length+' linked subtitles · '+size(state.tracks.reduce((n,t)=>n+t.movie.size+(t.subtitle?.size||0),0)):'No movies added.';
  $('clear').disabled=state.busy||!state.tracks.length;$('build').disabled=state.busy||!state.tracks.length;
  for(const id of ['choose','openTar','name'])$(id).disabled=state.busy;
 }
 function pair(){let linked=0;state.pending=state.pending.filter(s=>{const candidates=state.tracks.filter(t=>!t.subtitle&&api.stem(t.movie.name)===api.stem(s.name));if(candidates.length===1){candidates[0].subtitle=s;linked++;return false}return true});return linked}
 function add(files){
  if(state.busy)return;let added=0,rejected=0;
  for(const f of files){if(/\.mpg$/i.test(f.name)&&state.tracks.length<255){state.tracks.push({movie:f,subtitle:null});added++}else if(/\.srt$/i.test(f.name))state.pending.push(f);else rejected++}
  const linked=pair();invalidate();render();message(added+' movies added; '+linked+' subtitles linked.'+(state.pending.length?' '+state.pending.length+' SRT files await a unique matching movie; use SRT… to choose manually.':'')+(rejected?' '+rejected+' files skipped (unsupported type or movie limit).':''));
 }
 async function open(file){if(state.busy)return;state.busy=true;render();message('Reading playlist headers…');try{const result=await api.open(file);invalidate();state.tracks=result.tracks;state.pending=[];$('name').value=result.title;message('Playlist opened. Movies and linked subtitles are unchanged.')}catch(e){message('Could not open playlist: '+e.message)}finally{state.busy=false;render()}}
 $('choose').onclick=()=>$('files').click();$('openTar').onclick=()=>$('tarFile').click();
 $('files').onchange=()=>{add($('files').files);$('files').value=''};$('tarFile').onchange=()=>{if($('tarFile').files[0])open($('tarFile').files[0]);$('tarFile').value=''};
 $('clear').onclick=()=>{state.tracks=[];state.pending=[];invalidate();render();message('Playlist cleared.')};$('name').oninput=invalidate;
 $('build').onclick=async()=>{state.busy=true;invalidate();render();try{state.result=await api.build(state.tracks,$('name').value);state.url=URL.createObjectURL(state.result.blob);$('download').href=state.url;$('download').download=state.result.name;$('download').hidden=false;$('save').hidden=!window.showSaveFilePicker;message('Playlist ready: '+size(state.result.blob.size)+'. Movie and subtitle bytes are preserved.')}catch(e){message(e.message)}finally{state.busy=false;render()}};
 $('save').onclick=async()=>{if(!state.result)return;const result=state.result;let writable;try{const handle=await showSaveFilePicker({suggestedName:result.name,types:[{description:'TAR playlist',accept:{'application/x-tar':['.tar']}}]});writable=await handle.createWritable();message('Saving playlist…');await result.blob.stream().pipeTo(writable);message('Playlist saved.')}catch(e){if(writable)try{await writable.abort()}catch{}message(e.name==='AbortError'?'Save cancelled.':e.message)}};
 ['dragenter','dragover'].forEach(type=>$('drop').addEventListener(type,e=>{e.preventDefault();$('drop').classList.add('drag')}));
 ['dragleave','drop'].forEach(type=>$('drop').addEventListener(type,e=>{e.preventDefault();$('drop').classList.remove('drag')}));
 $('drop').addEventListener('drop',e=>{const files=[...e.dataTransfer.files];if(files.length===1&&/\.tar$/i.test(files[0].name))open(files[0]);else add(files)});
 $('drop').addEventListener('keydown',e=>{if(e.target===$('drop')&&(e.key==='Enter'||e.key===' ')){e.preventDefault();if(!state.busy)$('files').click()}});
 globalThis.RasterBuilderUI={addFiles(files){if(state.busy)throw Error('Wait for the playlist operation to finish.');add(files);RasterTabs.show('playlist')}};
 addEventListener('beforeunload',invalidate);render();api.ready.then(()=>{state.busy=false;render();message('Add movies and optional matching SRT files to begin.')}).catch(e=>message('Could not start the local WASM builder: '+e.message));
})();
