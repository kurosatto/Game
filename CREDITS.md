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
| 15 | explore | Green Forests | Alexandr Zhelanov | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) | https://opengameart.org/content/tribal-music |
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

## Combat sounds

Attack, hit and kill sounds are CC0 recordings from [OpenGameArt.org](https://opengameart.org),
trimmed, softened (rumble and harsh highs cut) and loudness-matched by
`tools/build_combat_sfx.py`. The same list is shown in-game on the credits page
(`data/SoundCredits.gd`).

| Pack | Artist | Licence | Source |
|---|---|---|---|
| 40 CC0 water / splash / slime SFX | rubberduck | CC0 | https://opengameart.org/content/40-cc0-water-splash-slime-sfx |
| 25 CC0 mud SFX | rubberduck | CC0 | https://opengameart.org/content/25-cc0-mud-sfx |
| 100 CC0 SFX | rubberduck | CC0 | https://opengameart.org/content/100-cc0-sfx |
| 75 CC0 breaking / falling / hit SFX | rubberduck | CC0 | https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx |
| 80 CC0 creature SFX #2 | rubberduck | CC0 | https://opengameart.org/content/80-cc0-creture-sfx-2 |
| Swishes sound pack | artisticdude | CC0 | https://opengameart.org/content/swishes-sound-pack |
| Bubble sound effects | bmaczero | CC0 | https://opengameart.org/content/bubble-sound-effects |
| Pop sounds | cogitollc | CC0 | https://opengameart.org/content/pop-sounds |
| Crunchy bite | fvcalderan | CC0 | https://opengameart.org/content/crunchy-bite |
| 7 eating crunches | StarNinjas | CC0 | https://opengameart.org/content/7-eating-crunches |
| 37 hits / punches | Independent.nu (qubodup) | CC0 | https://opengameart.org/content/37-hitspunches |
| 8 wet squish / slurp impacts | Independent.nu (qubodup) | CC0 | https://opengameart.org/content/8-wet-squish-slurp-impacts |
