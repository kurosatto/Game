# Credits

## Music

All music comes from [OpenGameArt.org](https://opengameart.org). The tracks were
trimmed into seamless loops and loudness-matched (eras -20 LUFS, bosses -19,
menu -22, peaks under -3 dBFS so nothing clips) (`tools/make_music_loops.py`);
nothing else was changed. The same list is shown in-game under
**Main menu → MUSIC CREDITS** (`data/MusicCredits.gd`).

| Where it plays | Track | Artist | Licence | Source |
|---|---|---|---|---|
| Main menu | First Light Particles | Yoiyami | CC0 | https://opengameart.org/content/first-light-particles-%E2%80%93-cc0-atmospheric-pianoambient-track |
| Ediacaran | Nautilus | poinl | CC0 | https://opengameart.org/content/nautilus |
| Cambrian | Krakatoa | Kistol | CC0 | https://opengameart.org/content/krakatoa |
| Ordovician | Parasite | Kistol | CC0 | https://opengameart.org/content/parasite |
| Carboniferous | Tribal | Of Far Different Nature | CC0 | https://opengameart.org/content/tribal |
| Permian | Endless Expanse | Alexandr Zhelanov | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) | https://opengameart.org/content/tribal-music |
| Ediacaran boss | Warped | Alexander Ehlers | CC0 | https://opengameart.org/content/free-music-pack |
| Cambrian boss | Waking the Devil | Alexander Ehlers | CC0 | https://opengameart.org/content/free-music-pack |
| Ordovician boss | Final Hour | isaiah658 | CC0 | https://opengameart.org/content/final-hour |
| Carboniferous boss | Life of the Tribe | Alexandr Zhelanov | [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) | https://opengameart.org/content/tribal-music |
| Permian boss | Predynastic Dawn | bobjt | CC0 | https://opengameart.org/content/predynastic-dawn |

CC0 tracks need no credit, but the artists are listed anyway. The two
CC-BY 4.0 tracks by Alexandr Zhelanov (https://www.youtube.com/c/AlexandrZhelanovsMusic)
must keep this credit wherever the game is shipped.

The old procedural soundtrack can still be rebuilt with `generate_soundtrack.py`
(it now writes to `assets/music_procedural/`, which the game does not load).
