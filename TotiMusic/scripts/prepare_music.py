from asset_paths import asset_file
from pathlib import Path
import subprocess,json,hashlib,concurrent.futures,uuid
from PIL import Image,ImageDraw,ImageOps

def process(item):
 p=asset_file(f'Design/MusicSources/{item["id"]}.mp4'); info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(p)])); duration=float(info['format']['duration']); name=f'music-{item["id"]}'
 dest=asset_file('MusicMedia/'+name+'.mp4')
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(p),'-map','0:v:0','-map','0:a?','-vf',"scale='min(960,iw)':'min(960,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2",'-c:v','libx264','-preset','fast','-crf','24','-c:a','aac','-b:a','128k','-movflags','+faststart',str(dest)],check=True)
 times=[round(duration*f,2) for f in [.1,.5,.9]]
 frames=[]
 for i,t in enumerate(times):
  f=asset_file(f'Design/MediaReview/{item["id"]}-{i}.jpg'); subprocess.run(['ffmpeg','-v','error','-y','-ss',str(t),'-i',str(dest),'-frames:v','1',str(f)],check=True); frames.append(f)
 Image.open(frames[0]).save(asset_file('MusicMedia/'+name+'.jpg'),quality=90)
 item.update(assetName=name,uuid=str(uuid.uuid5(uuid.NAMESPACE_URL,item['sourceURL'])).upper(),duration=duration,audioTracks=sum(s['codec_type']=='audio' for s in info['streams']),originalSHA256=hashlib.sha256(p.read_bytes()).hexdigest(),runtimeSHA256=hashlib.sha256(dest.read_bytes()).hexdigest(),coverSHA256=hashlib.sha256((asset_file('MusicMedia/'+name+'.jpg')).read_bytes()).hexdigest(),inspectionTimes=times,transformation='H.264 proportional downscale to max 960px; original cadence and duration; retain available audio as AAC')
 print(name,duration,'audio',item['audioTracks'],flush=True);return item
items=json.loads(asset_file('Design/MusicSources/downloads.json').read_text())
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool: items=list(pool.map(process,items))
asset_file('Design/MusicSources/manifest.json').write_text(json.dumps(items,indent=2))
for page in range(3):
 canvas=Image.new('RGB',(1000,960),'#fff8f1');d=ImageDraw.Draw(canvas)
 for row,item in enumerate(items[page*3:page*3+3]):
  for col in range(3):
   im=Image.open(asset_file(f'Design/MediaReview/{item["id"]}-{col}.jpg'));im.thumbnail((320,275));canvas.paste(im,(col*333+(320-im.width)//2,row*320+28));d.text((col*333+6,row*320+8),f'{item["id"]} @ {item["inspectionTimes"][col]}s',fill='#39234f')
 canvas.save(asset_file(f'Design/MediaReview/contact-{page+1}.jpg'))
