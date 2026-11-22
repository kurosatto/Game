# Cut a downloaded music track into a seamless loop for assets/music/.
# Finds the point where the music best matches an earlier point (skipping
# the intro), crossfades there, matches loudness and writes Ogg Vorbis.
# Usage: python tools/make_music_loops.py <source> <out.ogg> [json options]
#   e.g. {"native": true} for tracks that already loop, {"maxlen": 170, "lufs": -15}
# Make a seamless loop: find where the music best matches its opening, crossfade there.
import sys, subprocess, numpy as np, json
SR=44100
def load(p):
    raw=subprocess.run(["ffmpeg","-nostdin","-v","quiet","-i",p,"-ac","2","-ar",str(SR),"-f","f32le","-"],capture_output=True).stdout
    return np.frombuffer(raw,dtype=np.float32).reshape(-1,2).copy()
def feats(m, hop=1024, n=4096):
    fr=(len(m)-n)//hop
    idx=np.arange(n)[None,:]+hop*np.arange(fr)[:,None]
    S=np.abs(np.fft.rfft(m[idx]*np.hanning(n),axis=1))[:, :1200]
    # log band energies (48 bands)
    edges=np.unique(np.geomspace(2,1200,49).astype(int))
    B=np.stack([S[:,a:b].sum(1) for a,b in zip(edges[:-1],edges[1:])],1)
    B=np.log1p(B*20)
    return B, hop
def main(src,dst,native=False,maxstart=30.0,maxlen=200.0,minlen=60.0,xf=1.5,start=None,end=None,lufs=-16.0):
    y=load(src); m=y.mean(1)
    info={}
    # leading silence
    env=np.abs(m); thr=10**(-45/20)
    h0=int(np.argmax(env>thr)) if start is None else int(start*SR)
    if native:
        yy=y[h0:] if end is None else y[h0:int(end*SR)]
        # trim digital silence at the tail, then a 60 ms seam crossfade to kill clicks
        nz=np.where(np.abs(yy).max(1)>1e-4)[0]; yy=yy[:nz[-1]+1]
        X=int(0.06*SR); t=np.linspace(0,1,X)[:,None]
        seg=yy[X:].copy(); seg[-X:]=yy[-X:]*np.cos(t*np.pi/2)+yy[:X]*np.sin(t*np.pi/2)
        info['loop']='native'
    else:
        B,hop=feats(m)
        win=int(5*SR/hop)
        rms=np.sqrt(np.convolve(m**2,np.ones(SR//4)/(SR//4),'same')[::hop]+1e-12)
        med=np.median(rms[rms>thr])
        loud=np.where(rms>med*10**(-10/20))[0]
        last=loud[-1]
        Z=np.stack([B[i:i+win].ravel() for i in range(0,len(B)-win)])
        Z=(Z-Z.mean(1,keepdims=True))/(Z.std(1,keepdims=True)+1e-9)
        f0=h0//hop
        starts=range(f0, f0+int(maxstart*SR/hop), max(1,int(0.25*SR/hop)))
        best=(-9,0,0)
        for st in starts:
            lo=st+int(minlen*SR/hop); hi=min(last-win-int(xf*SR/hop), st+int(maxlen*SR/hop), len(Z)-1)
            if hi<=lo: continue
            sc=(Z[lo:hi]@Z[st])/Z.shape[1] + 0.03*np.arange(hi-lo)/(hi-lo)
            k=int(np.argmax(sc))
            if sc[k]>best[0]: best=(float(sc[k]),st,lo+k)
        h0=best[1]*hop; E=best[2]*hop
        ref=m[h0:h0+SR//2]
        sh=int(0.03*SR); bs=(-1e9,0)
        for d in range(-sh,sh,4):
            c=np.dot(m[E+d:E+d+len(ref)],ref)
            if c>bs[0]: bs=(c,d)
        E+=bs[1]
        X=int(xf*SR)
        seg=y[h0+X:E+X].copy()
        t=np.linspace(0,1,X)[:,None]
        fo=np.cos(t*np.pi/2); fi=np.sin(t*np.pi/2)
        seg[-X:]=y[E:E+X]*fo + y[h0:h0+X]*fi
        info.update(loop='auto',score=round(best[0],3),start=round(h0/SR,2),end=round(E/SR,2))
    info['len']=round(len(seg)/SR,1)
    tmp=dst+'.wav.f32'
    seg.astype(np.float32).tofile(tmp)
    # loudness normalise (linear, two-pass measured), then vorbis
    meas=subprocess.run(["ffmpeg","-nostdin","-hide_banner","-f","f32le","-ar",str(SR),"-ac","2","-i",tmp,"-af","ebur128","-f","null","-"],capture_output=True,text=True).stderr
    I=float([l for l in meas.splitlines() if l.strip().startswith('I:')][-1].split()[1])
    gain=lufs-I
    peak=np.abs(seg).max()*10**(gain/20)
    if peak>0.7: gain-=20*np.log10(peak/0.7)  # keep peaks under -3 dBFS so the encoder never clips
    subprocess.run(["ffmpeg","-nostdin","-v","error","-y","-f","f32le","-ar",str(SR),"-ac","2","-i",tmp,"-af",f"volume={gain:.2f}dB","-c:a","libvorbis","-q:a","3",dst],check=True)
    import os; os.remove(tmp)
    info['gain_db']=round(float(gain),1); info['kb']=os.path.getsize(dst)//1024
    print(json.dumps({os.path.basename(dst):info}))
if __name__=='__main__':
    a=json.loads(sys.argv[3]) if len(sys.argv)>3 else {}
    main(sys.argv[1],sys.argv[2],**a)
