from pathlib import Path
import os,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
SCRIPTS=ROOT/"Eventdisplay_AnalysisScripts_VTS/scripts"
def exe(p,s):
 p.write_text("#!/bin/bash\n"+s);p.chmod(0o755)
with tempfile.TemporaryDirectory() as td:
 d=Path(td);(d/'bin').mkdir();(d/'aux').mkdir();(d/'msc').mkdir();(d/'dl3').mkdir();(d/'aux/IRFMINORVERSION').write_text('v492.0\n');
 # rsync records actual membership and destination, leaving fixture sources intact.
 exe(d/'bin/rsync','printf "DEST:%s\\n" "${!#}" >> "$RSYNC_TRACE"\nif [[ "$*" == *--files-from=-* ]];then cat >> "$RSYNC_TRACE";else printf "%s\\n" "$@" >> "$RSYNC_TRACE";fi\n')
 env=os.environ.copy();env.update(PATH=str(d/'bin')+':'+env['PATH'],VERITAS_DATA_DIR=td,VERITAS_EVNDISP_AUX_DIR=str(d/'aux'),VERITAS_ANALYSIS_TYPE='AP_DISP',RSYNC_TRACE=str(d/'rsync.trace'))
 for n in [99999,100000,119999,120000,130000]:
  (d/f'msc/{n}.mscw.root').write_text('root');(d/f'msc/{n}.xgb_gh.root').write_text('sidecar');(d/f'dl3/{n}.fits.gz').write_text('fits');(d/f'dl3/{n}.log').write_text('success')
 p=SCRIPTS/'preprocessing/prepro_move_preprocessed_files.sh';res=subprocess.run(['bash',str(p),'msc'],env=env,cwd=d,stdout=subprocess.PIPE,text=True,stderr=subprocess.STDOUT);assert res.returncode==0,res.stdout
 trace=(d/'rsync.trace').read_text();assert '/12/' in trace and '/13/' in trace and trace.count('99999.mscw.root')==1 and trace.count('100000.mscw.root')==1,trace
 p=SCRIPTS/'preprocessing/prepro_move_v2dl3_files.sh'
 # Actual interface takes file type then IRF mode.
 for args in [['dl3','pointlike'],['dl3','pointlike',str(d/'dl3/120000.fits.gz'),str(d/'dl3/130000.fits.gz')]]:
  res=subprocess.run(['bash',str(p),*args],env=env,cwd=d,stdout=subprocess.PIPE,text=True,stderr=subprocess.STDOUT);assert res.returncode==0,res.stdout
 print('PASS archive 5/6-digit prefix routing including 12,13 and XGB sidecars; explicit DL3 batch')
