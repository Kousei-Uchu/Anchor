import { Player } from '@remotion/player';
import { DURATION, FPS, Promo } from '../promo/Promo';

/** The promo video, playing live in the page (no video file). Picture and sound come from src/promo/music.json. */
export default function PromoPlayer() {
  return (
    <Player
      component={Promo}
      durationInFrames={DURATION}
      fps={FPS}
      compositionWidth={1080}
      compositionHeight={1920}
      initialFrame={80}
      controls
      loop
      clickToPlay
      doubleClickToFullscreen
      showVolumeControls
      allowFullscreen
      acknowledgeRemotionLicense
      spaceKeyToPlayOrPause={false}
      style={{ width: '100%', aspectRatio: '1080 / 1920', borderRadius: 34 }}
      numberOfSharedAudioTags={2}
    />
  );
}
