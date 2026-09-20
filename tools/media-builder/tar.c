/* Raster TAR header codec, GPL-2.0-or-later. No libc or imported runtime. */
typedef unsigned char u8;
typedef unsigned int u32;
typedef unsigned long long u64;
static u8 buffer[1024];
__attribute__((visibility("default"))) u32 buffer_ptr(void){return (u32)buffer;}
static void text(u32 pos,const char *s){while(*s)buffer[pos++]=(u8)*s++;}
static int octal(u32 pos,u32 width,u64 value){
 buffer[pos+width-1]=0;
 for(u32 i=width-1;i;i--){buffer[pos+i-1]='0'+(value&7);value>>=3;}
 return value==0;
}
__attribute__((visibility("default"))) int make_header(u32 len,double bytes,double modified){
 if(!len||len>100||bytes<0||bytes>8589934591.0||modified<0||modified>8589934591.0)return 0;
 for(u32 i=0;i<512;i++)buffer[i]=0;
 for(u32 i=0;i<len;i++){if(!buffer[512+i])return 0;buffer[i]=buffer[512+i];}
 text(100,"0000644");text(108,"0000000");text(116,"0000000");
 if(!octal(124,12,(u64)bytes)||!octal(136,12,(u64)modified))return 0;
 for(u32 i=148;i<156;i++)buffer[i]=32;
 buffer[156]='0';text(257,"ustar");text(263,"00");text(265,"MiSTer");text(297,"MiSTer");
 u32 sum=0;for(u32 i=0;i<512;i++)sum+=buffer[i];
 octal(148,7,sum);buffer[155]=32;return 1;
}
static int number(u32 pos,u32 count,u64 *out){
 u64 n=0;for(u32 i=0;i<count;i++){
  u8 c=buffer[pos+i];if(c>='0'&&c<='7')n=(n<<3)+(c-'0');
  else if(c!=0&&c!=32)return 0;
 }*out=n;return 1;
}
/* 1=regular file, 2=directory, 3=zero terminator, 0=invalid/unsupported. */
__attribute__((visibility("default"))) int inspect_header(void){
 u32 sum=0,nonzero=0;u64 expected,size;
 for(u32 i=0;i<512;i++){nonzero|=buffer[i];sum+=(i>=148&&i<156)?32:buffer[i];}
 if(!nonzero)return 3;
 if(buffer[257]!='u'||buffer[258]!='s'||buffer[259]!='t'||buffer[260]!='a'||buffer[261]!='r'||buffer[262]||buffer[263]!='0'||buffer[264]!='0')return 0;
 if(!number(148,8,&expected)||expected!=sum||!number(124,12,&size))return 0;
 for(u32 i=345;i<500;i++)if(buffer[i])return 0;
 if(!buffer[0])return 0;
 if(buffer[156]==0||buffer[156]=='0')return 1;
 return buffer[156]=='5'?2:0;
}
__attribute__((visibility("default"))) double member_size(void){u64 n=0;number(124,12,&n);return (double)n;}
