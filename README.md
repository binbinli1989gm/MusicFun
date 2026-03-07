### MusicFun

The MusicFun app is a midi generator base on PyTorch deployed on the iOS platform. The model is using music-transformer. 

Usage:

1.cd the folder Podfile file located
  </> Bash
  // If you install cocoapods
  brew install cocoapods 
  pod install


2. The missing GeneralUser-GS.sf2 could be download from https://www.schristiancollins.com/generaluser
  or you can deploy your own SoundFont bank for composing and playing MIDI files

3. Build your own music model
   The model pytorch lite accetped is different from pytoch model files likes .pt fromat.
   So it need to convert .pt format to .ptl format.
   The pt2ptl.py is aimed to convert the music-transformer model6v2.pt (https://github.com/spectraldoy/music-transformer) to music_transformer.ptl.
   Detail prameters is in the music-transformer source code folder if you want to explore it. 
   For converting, the recommended Python version is 3.10. 

 




  
