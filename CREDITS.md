# Credits

## Music

All music comes from [OpenGameArt.org](https://opengameart.org). The tracks were
trimmed into seamless loops and loudness-matched (eras -20 LUFS, bosses -19,
menu -22, peaks under -3 dBFS so nothing clips) (`tools/make_music_loops.py`);
nothing else was changed. The game plays a random track from each pool (menu, explore for floors, boss)
while the favourites are being picked. The same list is shown in-game under
**Main menu → MUSIC CREDITS** (`data/MusicCredits.gd`).

| Pool | Track | Artist | Licence | Source |
|---|---|---|---|---|
| menu | First Light Particles | Yoiyami | CC0 | https://opengameart.org/content/first-light-particles-%E2%80%93-cc0-atmospheric-pianoambient-track |
| menu | Snowfall | Kistol | CC0 | https://opengameart.org/content/snowfall |
| menu | Mysterious Winds | athor | CC0 | https://opengameart.org/content/mysterious-winds |
| menu | Core Theme: Deep Blue | Yoiyami | CC0 | https://opengameart.org/content/yoiyami-core-theme-%E2%80%93-deep-blue-ambient-piano |
| menu | Underwater Ambient Pad | isaiah658 | CC0 | https://opengameart.org/content/underwater-ambient-pad |
| explore | Nautilus | poinl | CC0 | https://opengameart.org/content/nautilus |
| explore | Underwater Theme II | Cleyton Kauffman | CC0 | https://opengameart.org/content/underwater-theme-ii |
| explore | Eyes of the Ocean | Tsorthan Grove | CC0 | https://opengameart.org/content/eyes-of-the-ocean |
| explore | I Think I'd Stay | emmntt | CC0 | https://opengameart.org/content/i-think-id-stay-jungle-chill |
| explore | The Great Oasis | Alexandr Zhelanov | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) | https://opengameart.org/content/tribal-music |
| explore | Endless Expanse | Alexandr Zhelanov | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) | https://opengameart.org/content/tribal-music |
| explore | Exploration Theme | Cleyton Kauffman | CC0 | https://opengameart.org/content/exploration-theme |
| explore | Krakatoa | Kistol | CC0 | https://opengameart.org/content/krakatoa |
| explore | Parasite | Kistol | CC0 | https://opengameart.org/content/parasite |
| explore | Tribal | Of Far Different Nature | CC0 | https://opengameart.org/content/tribal |
| explore | Green Forests | Alexandr Zhelanov | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) | https://opengameart.org/content/tribal-music |
| explore | Safety (Tribe version) | fupi | CC0 | https://opengameart.org/content/safety-2-versions |
| explore | Revenge of the Jungle | oglsdl | CC0 | https://opengameart.org/content/revenge-of-the-jungle |
| explore | Unexplored | bo-jingles (TAD) | CC0 | https://opengameart.org/content/unexplored-expansion |
| explore | Ocean Trance | mintodog | CC0 | https://opengameart.org/content/ocean-trance |
| boss | Warped | Alexander Ehlers | CC0 | https://opengameart.org/content/free-music-pack |
| boss | Waking the Devil | Alexander Ehlers | CC0 | https://opengameart.org/content/free-music-pack |
| boss | Final Hour | isaiah658 | CC0 | https://opengameart.org/content/final-hour |
| boss | Life of the Tribe | Alexandr Zhelanov | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) | https://opengameart.org/content/tribal-music |
| boss | Predynastic Dawn | bobjt | CC0 | https://opengameart.org/content/predynastic-dawn |
| boss | Fast Fight (looped) | bonsaiheldin, loop by xcvg | CC0 | https://opengameart.org/content/fast-fight-battle-music-looped |
| boss | Jungle Battle Loop | omfgdude | CC0 | https://opengameart.org/content/jungle-battle-loop |
| boss | Epic at the Jungle | indieteur | CC0 | https://opengameart.org/content/epic-at-the-jungle |
| boss | Tribal Chaos | Tricks n Traps | CC0 | https://opengameart.org/content/t-t-free-cyberpunk-pack |
| boss | Flags | Alexander Ehlers | CC0 | https://opengameart.org/content/free-music-pack |

CC0 tracks need no credit, but the artists are listed anyway. The
CC-BY 4.0 tracks by Alexandr Zhelanov (https://www.youtube.com/c/AlexandrZhelanovsMusic)
must keep this credit wherever the game is shipped.

The old procedural soundtrack can still be rebuilt with `generate_soundtrack.py`
(it now writes to `assets/music_procedural/`, which the game does not load).
