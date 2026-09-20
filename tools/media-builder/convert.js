/* GPL-2.0-or-later. Adapted from Raster_OLD's phosphor_mpg_builder.
   Pinned single-thread ffmpeg.wasm; downloaded only when conversion is requested. */
(()=>{
 'use strict';const $=id=>document.getElementById(id);
 const WRAPPER='https://unpkg.com/@ffmpeg/ffmpeg@0.12.15/dist/umd/ffmpeg.js';
 const WORKER='https://unpkg.com/@ffmpeg/ffmpeg@0.12.15/dist/umd/814.ffmpeg.js';
 const CORE='https://unpkg.com/@ffmpeg/core@0.12.10/dist/umd';
 let source=null,engine=null,loaded=false,busy=false,result=null,resultURL='',run=0,aborter=null;
 const human=n=>n>=2**30?(n/2**30).toFixed(2)+' GiB':(n/2**20).toFixed(1)+' MiB';
 const choice=n=>document.querySelector('input[name="'+n+'"]:checked').value;
 const stem=n=>(n.replace(/\.[^.]*$/,'')||'raster-video').replace(/[\\/:*?"<>|\x00-\x1f]/g,'_');
 function updateCommand(){
  try{$('nativeCommand').value=RasterConversionProfile.nativeCommand($('nativeInput').value,$('nativeOutput').value,{fps:choice('fps'),aspect:choice('aspect'),quality:choice('quality')},$('nativeThreads').value);$('copyCommand').disabled=false;$('commandStatus').textContent=''}
  catch(e){$('nativeCommand').value='';$('copyCommand').disabled=true;$('commandStatus').textContent=e.message}
  try{$('batchCommand').value=RasterConversionProfile.nativeBatchCommand({fps:choice('fps'),aspect:choice('aspect'),quality:choice('quality')},$('nativeThreads').value);$('copyBatchCommand').disabled=false;$('batchCommandStatus').textContent=''}
  catch(e){$('batchCommand').value='';$('copyBatchCommand').disabled=true;$('batchCommandStatus').textContent=e.message}
 }
 for(const id of ['nativeInput','nativeOutput','nativeThreads'])$(id).addEventListener('input',updateCommand);
 document.querySelectorAll('.convert-options input').forEach(e=>e.addEventListener('change',updateCommand));
 $('copyCommand').onclick=async()=>{const text=$('nativeCommand').value;if(!text)return;try{await navigator.clipboard.writeText(text);$('commandStatus').textContent='Command copied.'}catch{$('nativeCommand').focus();$('nativeCommand').select();$('commandStatus').textContent='Press Ctrl+C or Command+C to copy the selected command.'}};
 $('copyBatchCommand').onclick=async()=>{const text=$('batchCommand').value;if(!text)return;try{await navigator.clipboard.writeText(text);$('batchCommandStatus').textContent='Folder command copied.'}catch{$('batchCommand').focus();$('batchCommand').select();$('batchCommandStatus').textContent='Press Ctrl+C or Command+C to copy the selected command.'}};
 updateCommand();
 function status(s){$('convertStatus').textContent=s}
 function controls(){ $('convertButton').disabled=busy||!source;$('chooseSource').disabled=busy;$('sourceFile').disabled=busy;$('cancelConvert').hidden=!busy;document.querySelectorAll('.convert-options input').forEach(e=>e.disabled=busy) }
 function clearResult(){if(resultURL)URL.revokeObjectURL(resultURL);resultURL='';result=null;$('downloadMpg').hidden=true;$('addConverted').hidden=true}
 function select(file){if(!file||busy)return;source=file;$('nativeInput').value=file.name;$('nativeOutput').value=stem(file.name)+'_raster.mpg';updateCommand();clearResult();$('sourceLabel').textContent=file.name;$('sourceNote').textContent=human(file.size);$('convertProgress').value=0;$('convertPercent').textContent='';status('Ready to convert.');controls()}
 async function wrapper(){if(globalThis.FFmpegWASM)return;await new Promise((resolve,reject)=>{const script=document.createElement('script');script.src=WRAPPER;script.onload=resolve;script.onerror=()=>{script.remove();reject(Error('Could not download FFmpeg. Check your internet connection and retry.'))};document.head.append(script)})}
 async function blobURL(url,type,signal){const response=await fetch(url,{signal});if(!response.ok)throw Error('Could not download the video engine ('+response.status+').');return URL.createObjectURL(new Blob([await response.arrayBuffer()],{type}))}
 function check(id){if(id!==run)throw new DOMException('Conversion cancelled.','AbortError')}
 async function loadEngine(id,signal){
  if(loaded)return;status('Downloading video engine…');await wrapper();check(id);
  const ff=new FFmpegWASM.FFmpeg();engine=ff;
  ff.on('log',({message})=>{if(!busy||engine!==ff)return;const log=$('convertLog');log.textContent=(log.textContent+message+'\n').slice(-50000);log.scrollTop=log.scrollHeight});
  // The engine is reused: progress/log handlers consult current busy state.
  ff.on('progress',({progress})=>{if(!busy||engine!==ff)return;const p=Math.max(0,Math.min(1,Number.isFinite(progress)?progress:0));$('convertProgress').value=p;$('convertPercent').textContent=Math.round(p*100)+'%'});
  const urls=[];
  try{
   urls.push(await blobURL(WORKER,'text/javascript',signal));check(id);
   const NativeWorker=window.Worker;let loading;
   // Pinned UMD wrapper expects a classic worker at its CDN URL. A local Blob
   // worker preserves file:// support; restore the constructor synchronously.
   window.Worker=class extends NativeWorker{constructor(){super(urls[0])}};
   try{loading=ff.load({coreURL:CORE+'/ffmpeg-core.js',wasmURL:CORE+'/ffmpeg-core.wasm'})}finally{window.Worker=NativeWorker}
   let timer;try{await Promise.race([loading,new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Video engine loading timed out. Check your connection and retry.')),120000)})])}finally{clearTimeout(timer)}check(id);loaded=true;
  }catch(e){ff.terminate();if(engine===ff){engine=null;loaded=false}throw e}
  finally{urls.forEach(URL.revokeObjectURL)}
 }
 $('chooseSource').onclick=()=>$('sourceFile').click();$('sourceFile').onchange=()=>{select($('sourceFile').files[0]);$('sourceFile').value=''};
 for(const event of ['dragenter','dragover'])$('convertDrop').addEventListener(event,e=>{e.preventDefault();$('convertDrop').classList.add('drag')});
 for(const event of ['dragleave','drop'])$('convertDrop').addEventListener(event,e=>{e.preventDefault();$('convertDrop').classList.remove('drag')});
 $('convertDrop').addEventListener('drop',e=>select(e.dataTransfer.files[0]));
 $('convertDrop').onkeydown=e=>{if(e.target===$('convertDrop')&&['Enter',' '].includes(e.key)){e.preventDefault();if(!busy)$('sourceFile').click()}};
 $('convertButton').onclick=async()=>{
  if(!source||busy)return;const file=source,options={fps:choice('fps'),aspect:choice('aspect'),quality:choice('quality')},id=++run;
  busy=true;controls();clearResult();$('convertLog').textContent='';$('convertPercent').textContent='';$('convertProgress').value=0;
  aborter=new AbortController();let ff;
  const ext=file.name.match(/\.[a-z0-9]+$/i)?.[0]||'.input',input='input'+ext,output='output.mpg';
  try{
   if(!file.size)throw Error('Choose a nonempty video.');if(file.size>=2**31)throw Error('This browser converter supports source files smaller than 2 GiB. Use native FFmpeg for larger files.');
   await loadEngine(id,aborter.signal);check(id);ff=engine;
   status('Loading source into memory…');const bytes=new Uint8Array(await file.arrayBuffer());check(id);await ff.writeFile(input,bytes);check(id);
   status('Converting… Keep this page open.');const code=await ff.exec(RasterConversionProfile.argumentsFor(input,output,options));check(id);if(code!==0)throw Error('FFmpeg stopped with exit code '+code+'. See the conversion log.');
   const data=await ff.readFile(output);check(id);result=new File([data],stem(file.name)+'.mpg',{type:'video/mpeg'});resultURL=URL.createObjectURL(result);
   $('downloadMpg').href=resultURL;$('downloadMpg').download=result.name;$('downloadMpg').textContent='Download MPG ('+human(result.size)+')';$('downloadMpg').hidden=false;$('addConverted').hidden=false;$('addConverted').disabled=false;
   $('convertProgress').value=1;$('convertPercent').textContent='100%';status('MPG ready. Download it or add it directly to your playlist.');
  }catch(e){if(id===run){status('Conversion failed: '+(e.message||e));$('convertPercent').textContent=''}}
  finally{if(ff&&id===run){for(const path of [input,output])try{await ff.deleteFile(path)}catch{}}if(id===run){busy=false;aborter=null;controls()}}
 };
 $('cancelConvert').onclick=()=>{if(!busy)return;run++;aborter?.abort();engine?.terminate();engine=null;loaded=false;busy=false;aborter=null;controls();$('convertPercent').textContent='';status('Conversion cancelled. Select a video or try again.')};
 $('addConverted').onclick=()=>{if(!result)return;try{RasterBuilderUI.addFiles([result]);$('addConverted').disabled=true;status('MPG added to your playlist.')}catch(e){status(e.message)}};
 addEventListener('beforeunload',()=>{aborter?.abort();engine?.terminate();if(resultURL)URL.revokeObjectURL(resultURL)});controls();
})();
