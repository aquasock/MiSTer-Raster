/* MPG encoding recipe adapted from Raster_OLD/tools/phosphor_mpg_builder. GPL-2.0-or-later. */
(()=>{
  function videoFilter(aspect) {
    const common = ':flags=lanczos+accurate_rnd:in_color_matrix=auto:out_color_matrix=bt601:in_range=auto:out_range=limited,pad=720:480:(ow-iw)/2:(oh-ih)/2:black';
    if (aspect === '16:9') {
      return `scale=w='if(gte(dar,16/9),720,2*round(405*dar/2))':h='if(gte(dar,16/9),2*round(1280/(3*dar)),480)'${common},setsar=32/27,format=yuv420p`;
    }
    return `scale=w='if(gte(dar,4/3),720,2*round(270*dar))':h='if(gte(dar,4/3),2*round(320/dar),480)'${common},setsar=8/9,format=yuv420p`;
  }

  function argumentsFor(inputName, outputName, options) {
    const fps = options.fps;
    const aspect = options.aspect;
    const quality = options.quality;
    const frameRate = fps === '30' ? '30000/1001' : '24000/1001';
    const gop = fps === '30' ? '30' : '24';
    const qualityArgs = quality === 'maximum'
      ? ['-q:v', '1', '-qmin', '1', '-qmax', '8']
      : ['-q:v', '3', '-qmin', '2', '-qmax', '12'];

    return [
      '-i', inputName,
      '-map', '0:v:0', '-map', '0:a:0?', '-sn', '-dn',
      '-vf', videoFilter(aspect),
      '-r:v', frameRate, '-fps_mode:v', 'cfr',
      '-c:v', 'mpeg2video', '-profile:v', 'main', '-level:v', 'main',
      '-pix_fmt', 'yuv420p', '-threads', '1', '-flags:v', '+bitexact',
      '-g', gop, '-bf', '2', '-b_strategy', '0', '-mbd', 'rd', '-trellis', '2',
      ...qualityArgs,
      '-maxrate:v', '8000k', '-bufsize:v', '1835008',
      '-sc_threshold', '1000000000', '-mpv_flags', '+strict_gop',
      '-aspect', aspect, '-colorspace', 'smpte170m', '-color_range', 'tv',
      '-c:a', 'mp2', '-ar', '48000', '-ac', '2', '-b:a', '192k',
      '-f', 'mpeg', outputName
    ];
  }

// POSIX shell quoting preserves spaces, apostrophes and shell metacharacters.
  function shellQuote(value){return "'"+String(value).replace(/'/g,"'\"'\"'")+"'"}
  function nativeCommand(input,output,options,threads){
    threads=Number(threads);
    if(!Number.isInteger(threads)||threads<1||threads>8)throw Error('Choose 1–8 threads.');
    if(!input||!output)throw Error('Enter input and output filenames.');
    if(input===output)throw Error('Use a different output filename.');
    // Prefix relative filenames so leading '-' and protocol-like names stay paths.
    const path=s=>s.startsWith('/')||s.startsWith('./')||s.startsWith('../')?s:'./'+s;
    const args=argumentsFor(path(input),path(output),options);
    args[args.indexOf('-threads')+1]=String(threads);
    return ['ffmpeg','-hide_banner','-n','-threads',String(threads),'-filter_threads',String(threads),...args].map(shellQuote).join(' ');
  }
  function nativeBatchCommand(options,threads){
    threads=Number(threads);
    if(!Number.isInteger(threads)||threads<1||threads>8)throw Error('Choose 1–8 threads.');
    const args=argumentsFor('INPUT','OUTPUT',options);
    args[args.indexOf('-threads')+1]=String(threads);
    const encoded=args.map((arg,index)=>index===1?'"$raster_input"':index===args.length-1?'"$raster_output"':shellQuote(arg));
    const command=['ffmpeg','-hide_banner','-nostdin','-n','-threads',String(threads),'-filter_threads',String(threads)].map(shellQuote).concat(encoded).join(' ');
    return [
      '(',
      '  command -v ffmpeg >/dev/null 2>&1 && command -v ffprobe >/dev/null 2>&1 || {',
      '    printf "%s\\n" "Install FFmpeg and ffprobe first." >&2; exit 1;',
      '  }',
      '  mkdir -p ./Raster || exit 1',
      '  raster_failed=0',
      '  for raster_input in ./* ./.[!.]* ./..?*; do',
      '    [ -f "$raster_input" ] || continue',
      '    [ "$(ffprobe -v error -select_streams V:0 -show_entries stream=codec_type -of csv=p=0 "$raster_input" 2>/dev/null)" = video ] || continue',
      '    raster_output="./Raster/${raster_input#./}.mpg"',
      '    if [ -e "$raster_output" ]; then',
      '      printf "Already exists: %s\\n" "$raster_output"; continue',
      '    fi',
      '    if '+command+'; then',
      '      printf "Converted: %s\\n" "$raster_output"',
      '    else',
      '      printf "Failed: %s (check output before retrying)\\n" "$raster_input" >&2',
      '      raster_failed=1',
      '    fi',
      '  done',
      '  exit "$raster_failed"',
      ')'
    ].join('\n');
  }
globalThis.RasterConversionProfile={argumentsFor,nativeCommand,nativeBatchCommand};
})();
