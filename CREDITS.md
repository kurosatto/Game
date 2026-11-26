# Credits

## Music

All music comes from [OpenGameArt.org](https://opengameart.org). The tracks were
trimmed into seamless loops and loudness-matched (eras -20 LUFS, bosses -19,
menu -22, peaks under -3 dBFS so nothing clips) (`tools/make_music_loops.py`);
nothing else was changed. The game plays a random track from each pool (menu, explore for floors, boss)
while the favourites are being picked. The same list is shown in-game under
**Main menu → MUSIC CREDITS** (`data/MusicCredits.gd`).

| # | Pool | Track | Artist | Licence | Source |
|---|---|---|---|---|---|
| 1 | menu | First Light Particles | Yoiyami | CC0 | https://opengameart.org/content/first-light-particles-%E2%80%93-cc0-atmospheric-pianoambient-track |
| 2 | menu | Snowfall | Kistol | CC0 | https://opengameart.org/content/snowfall |
| 3 | menu | Mysterious Winds | athor | CC0 | https://opengameart.org/content/mysterious-winds |
| 4 | menu | Core Theme: Deep Blue | Yoiyami | CC0 | https://opengameart.org/content/yoiyami-core-theme-%E2%80%93-deep-blue-ambient-piano |
| 5 | menu | Underwater Ambient Pad | isaiah658 | CC0 | https://opengameart.org/content/underwater-ambient-pad |
| 6 | explore | Nautilus | poinl | CC0 | https://opengameart.org/content/nautilus |
| 7 | explore | Underwater Theme II | Cleyton Kauffman | CC0 | https://opengameart.org/content/underwater-theme-ii |
| 8 | explore | Eyes of the Ocean | Tsorthan Grove | CC0 | https://opengameart.org/content/eyes-of-the-ocean |
| 9 | explore | I Think I'd Stay | emmntt | CC0 | https://opengameart.org/content/i-think-id-stay-jungle-chill |
| 10 | explore | The Great Oasis | Alexandr Zhelanov | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) | https://opengameart.org/content/tribal-music |
| 11 | explore | Endless Expanse | Alexandr Zhelanov | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) | https://opengameart.org/content/tribal-music |
| 12 | explore | Exploration Theme | Cleyton Kauffman | CC0 | https://opengameart.org/content/exploration-theme |
| 13 | explore | Krakatoa | Kistol | CC0 | https://opengameart.org/content/krakatoa |
| 14 | explore | Parasite | Kistol | CC0 | https://opengameart.org/content/parasite |
| 16 | explore | Safety (Tribe version) | fupi | CC0 | https://opengameart.org/content/safety-2-versions |
| 17 | explore | Revenge of the Jungle | oglsdl | CC0 | https://opengameart.org/content/revenge-of-the-jungle |
| 18 | explore | Unexplored | bo-jingles (TAD) | CC0 | https://opengameart.org/content/unexplored-expansion |
| 19 | explore | Ocean Trance | mintodog | CC0 | https://opengameart.org/content/ocean-trance |
| 20 | boss | Warped | Alexander Ehlers | CC0 | https://opengameart.org/content/free-music-pack |
| 21 | boss | Waking the Devil | Alexander Ehlers | CC0 | https://opengameart.org/content/free-music-pack |
| 22 | boss | Final Hour | isaiah658 | CC0 | https://opengameart.org/content/final-hour |
| 23 | boss | Life of the Tribe | Alexandr Zhelanov | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) | https://opengameart.org/content/tribal-music |
| 24 | boss | Predynastic Dawn | bobjt | CC0 | https://opengameart.org/content/predynastic-dawn |
| 25 | boss | Fast Fight (looped) | bonsaiheldin, loop by xcvg | CC0 | https://opengameart.org/content/fast-fight-battle-music-looped |
| 26 | boss | Jungle Battle Loop | omfgdude | CC0 | https://opengameart.org/content/jungle-battle-loop |
| 27 | boss | Epic at the Jungle | indieteur | CC0 | https://opengameart.org/content/epic-at-the-jungle |
| 28 | boss | Tribal Chaos | Tricks n Traps | CC0 | https://opengameart.org/content/t-t-free-cyberpunk-pack |
| 29 | boss | Flags | Alexander Ehlers | CC0 | https://opengameart.org/content/free-music-pack |

CC0 tracks need no credit, but the artists are listed anyway. The
CC-BY 4.0 tracks by Alexandr Zhelanov (https://www.youtube.com/c/AlexandrZhelanovsMusic)
must keep this credit wherever the game is shipped.

The old procedural soundtrack can still be rebuilt with `generate_soundtrack.py`
(it now writes to `assets/music_procedural/`, which the game does not load).
