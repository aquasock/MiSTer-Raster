/* Raster playlist builder. GPL-2.0-or-later. Format follows Phosphor's builder. */
(() => {
 "use strict";
 const encoder=new TextEncoder(),decoder=new TextDecoder('utf-8',{fatal:true});
 const normalize=s=>s.replace(/\\/g,'/').replace(/[A-Z]/g,c=>c.toLowerCase());
 const stem=s=>normalize(s.replace(/\.[^.]+$/,''));
 // Displayed title: drop ".mpg", then any source-video extension kept by the batch converter (clip.mp4.mpg).
 const displayTitle=s=>s.replace(/\.[^.]+$/,'').replace(/\.(mp4|m4v|mkv|avi|mov|webm|wmv|flv|ts|m2ts|mts|mpe?g|vob|ogv|3gp)$/i,'');
 const clean=s=>s.replace(/[\\/:*?"<>|\x00-\x1f]+/g,'_').replace(/^#+/,'_');
 const pad=n=>new Uint8Array((512-n%512)%512);
 function hash(s){let h=0x811c9dc5;for(const c of encoder.encode(normalize(s)))h=Math.imul(h^c,0x01000193)>>>0;return h}
 let codec;
 const ready=WebAssembly.instantiate(Uint8Array.from(atob(globalThis.RasterTarWasmBase64),c=>c.charCodeAt(0)),{}).then(({instance})=>codec=instance.exports);
 function mem(){return new Uint8Array(codec.memory.buffer,codec.buffer_ptr(),1024)}
 function header(name,blob){
  const b=encoder.encode(name);if(!b.length||b.length>100)throw Error('A member name exceeds the 100-byte TAR limit: '+name);
  mem().set(b,512);
  if(!codec.make_header(b.length,blob.size,Math.floor((blob.lastModified||0)/1000)))throw Error('A member exceeds the 8 GiB USTAR limit: '+name);
  return mem().slice(0,512);
 }
 function namesFor(tracks){
  const used=new Set(['playlist.m3u']),fingerprints=new Set(),stems=new Set();
  return tracks.map((t,i)=>{
   let base=clean(t.movie.name.replace(/\.[^.]+$/,''))||'Movie '+(i+1),n=base+'.mpg',suffix=1;
   while(used.has(normalize(n)))n=base+' ('+(++suffix)+').mpg';
   used.add(normalize(n));const bytes=encoder.encode(n);
   if(bytes.length>100)throw Error('Shorten this movie filename to at most 96 UTF-8 bytes: '+t.movie.name);
   const fingerprint=bytes.length+':'+hash(n),stemKey=encoder.encode(n.slice(0,-4)).length+':'+hash(n.slice(0,-4));
   if(fingerprints.has(fingerprint)||stems.has(stemKey))throw Error('These filenames have an ambiguous hardware fingerprint. Rename one movie.');
   fingerprints.add(fingerprint);stems.add(stemKey);return n;
  });
 }
 async function build(tracks,title='playlist'){
  await ready;if(!tracks.length||tracks.length>255)throw Error('Choose between 1 and 255 movies.');
  const names=namesFor(tracks),safeTitle=(title.trim()||'playlist').replace(/[\r\n]/g,' ');
  const lines=['#EXTM3U','#PLAYLIST:'+safeTitle];
  tracks.forEach((t,i)=>lines.push('#EXTINF:-1,'+(t.title||displayTitle(t.movie.name)).replace(/[\r\n]/g,' '),names[i]));
  const m3u=new Blob([lines.join('\r\n')+'\r\n']);if(m3u.size>65536)throw Error('The playlist manifest exceeds 64 KiB.');
  const parts=[header('playlist.m3u',m3u),m3u,pad(m3u.size)];
  tracks.forEach((t,i)=>{
   if(!t.movie.size)throw Error('Empty movie: '+t.movie.name);
   parts.push(header(names[i],t.movie),t.movie,pad(t.movie.size));
   if(t.subtitle){if(!t.subtitle.size)throw Error('Empty subtitle: '+t.subtitle.name);parts.push(header(names[i].slice(0,-4)+'.srt',t.subtitle),t.subtitle,pad(t.subtitle.size))}
  });
  parts.push(new Uint8Array(1024));
  const blob=new Blob(parts,{type:'application/x-tar'});if(blob.size>=2**41)throw Error('The archive exceeds the core address range.');
  return {blob,name:(clean(safeTitle)||'playlist')+'.tar',names};
 }
 async function open(file){
  await ready;if(file.size>=2**41)throw Error('The archive exceeds the core address range.');let offset=0,terminated=false;const entries=[],byName=new Map(),fingerprints=new Set();
  while(offset+512<=file.size){
   const bytes=new Uint8Array(await file.slice(offset,offset+512).arrayBuffer());mem().set(bytes);
   const type=codec.inspect_header();if(type===3){terminated=true;break}if(!type)throw Error('Invalid or unsupported USTAR header at byte '+offset+'.');
   const end=bytes.indexOf(0);const name=decoder.decode(bytes.subarray(0,end<0?100:Math.min(end,100))),length=codec.member_size(),start=offset+512;
   if(start+Math.ceil(length/512)*512>file.size)throw Error('The TAR is truncated.');
   if(type===1){const key=normalize(name);if(byName.has(key))throw Error('Duplicate member name: '+name);
    const fp=encoder.encode(key).length+':'+hash(key);if(fingerprints.has(fp))throw Error('Ambiguous member filename fingerprint.');fingerprints.add(fp);
    const entry={name,start,length};entries.push(entry);byName.set(key,entry);
   }offset=start+Math.ceil(length/512)*512;
  }
  if(!terminated)throw Error('The TAR has no end marker.');
  const manifests=entries.filter(e=>/\.m3u$/i.test(e.name));if(manifests.length!==1)throw Error('The TAR must contain exactly one M3U.');
  const m=manifests[0];if(!m.length||m.length>65536)throw Error('The M3U is empty or exceeds 64 KiB.');
  const text=decoder.decode(await file.slice(m.start,m.start+m.length).arrayBuffer()),lines=text.split(/\r\n|\n|\r/);
  const movieEntries=entries.filter(e=>/\.mpg$/i.test(e.name)),srtEntries=entries.filter(e=>/\.srt$/i.test(e.name));
  if([...movieEntries,...srtEntries].some(e=>!e.length))throw Error('Movie and subtitle members must be nonempty.');
  if(movieEntries.length>255||srtEntries.length>255)throw Error('The TAR exceeds 255 movies or subtitles.');
  const tracks=[];let title='',itemTitle='';
  for(const line of lines){
   if(line.startsWith('#PLAYLIST:'))title=line.slice(10);
   if(line.startsWith('#EXTINF:'))itemTitle=line.slice(line.indexOf(',')+1);
   if(!line||line.startsWith('#'))continue;
   const e=byName.get(normalize(line));if(!e||!/\.mpg$/i.test(e.name)||!e.length)throw Error('M3U movie not found or empty: '+line);
   const s=byName.get(normalize(e.name.slice(0,-4)+'.srt'));
   tracks.push({movie:new File([file.slice(e.start,e.start+e.length)],e.name),subtitle:s&&s.length?new File([file.slice(s.start,s.start+s.length)],s.name):null,title:itemTitle});itemTitle='';
  }
  if(!tracks.length||tracks.length>255)throw Error('The M3U must list 1–255 movies.');
  return {tracks,title:title||file.name.replace(/\.tar$/i,'')};
 }
 globalThis.RasterPlaylist={ready,build,open,normalize,stem,hash};
})();
