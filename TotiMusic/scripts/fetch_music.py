from asset_paths import asset_output
import concurrent.futures, subprocess, json, pathlib, shutil
root=pathlib.Path(__file__).resolve().parents[1]

clips=[(8042838,'A Woman Singing with a Microphone','ANTONI SHKRABA production','live','Soul in the spotlight','soul'),(7586634,'A Woman Singing while Using Condenser Microphone','Los Muertos Crew','live','The velvet vocal booth','pop'),(9419269,'A Woman Holding the Microphone While Singing','cottonbro studio','live','Midnight microphone','jazz'),(8135078,'Man Singing in the Music Studio','ANTONI SHKRABA production','live','One take, all heart','pop'),(8117115,'A Man Singing while using Microphone','Ivan S','shorts','A verse worth replaying','acoustic'),(7090702,'A Woman Singing in a Studio','cottonbro studio','shorts','Inside the recording room','soul'),(7087182,'A Woman Singing in Front of the Microphone','cottonbro studio','shorts','Find your own voice','pop'),(8134898,'Woman Singing in the Microphone','ANTONI SHKRABA production','shorts','Acoustic afternoon','acoustic'),(8134961,'Woman Singing with Microphone','ANTONI SHKRABA production','shorts','Between the headphones','pop')]
def get(row):
 id,title,author,surface,name,genre=row
 dest=asset_output(f'Design/MusicSources/{id}.mp4')
 suffixes=['hd_720_1280_25fps','hd_1080_1920_25fps','hd_1280_720_25fps','hd_1920_1080_25fps','uhd_2160_4096_25fps','uhd_4096_2160_25fps','hd_1080_1920_24fps','hd_1920_1080_24fps','hd_1080_1920_30fps','hd_1920_1080_30fps']
 if id==8042838: suffixes=['uhd_2160_4096_25fps']
 url=None
 for suffix in suffixes:
  url=f'https://videos.pexels.com/video-files/{id}/{id}-{suffix}.mp4'
  if dest.exists() and dest.stat().st_size>100000: break
  r=subprocess.run(['curl','-L','--fail','--silent','--max-time','40',url,'-o',str(dest)])
  if r.returncode==0 and dest.stat().st_size>100000: break
 else:
  dest.unlink(missing_ok=True); print('FAILED',id,flush=True); return None
 data={'id':id,'sourceTitle':title,'author':author,'surface':surface,'title':name,'genre':genre,'sourceURL':'https://www.pexels.com/video/'+title.lower().replace(' ','-')+'-'+str(id)+'/', 'downloadURL':url,'license':'Pexels License','licenseURL':'https://www.pexels.com/license/'}
 print('DOWNLOADED',id,dest.stat().st_size,flush=True); return data
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool: results=list(pool.map(get,clips))
asset_output('Design/MusicSources/downloads.json').write_text(json.dumps([r for r in results if r],indent=2))
