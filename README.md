# Reversi AI — Minimax Search in SWI-Prolog

A fully playable Reversi (Othello) AI built for CS152: Harnessing Artificial Intelligence Algorithms at Minerva University. All game logic and adversarial search are implemented in SWI-Prolog; a Jupyter notebook provides an interactive ipywidgets frontend via PySwip.

---

## How It Works

The game engine is written entirely in Prolog. Board state is a flat 64-atom list. Move legality is determined by a recursive ray-scan predicate that checks all eight directions for valid bracketing sequences. The AI uses **negamax alpha-beta pruning** to search the game tree to a configurable depth and selects the move maximising a three-component heuristic:

- **Positional weights** — corners score 100, X-squares -20, C-squares -10, edges 10
- **Mobility** — normalised difference in legal move counts between players
- **Piece count** — disc difference weighted by board fill (grows toward endgame)

A Python layer (PySwip) bridges the Prolog engine to an ipywidgets board rendered in Jupyter.

---

## Files

| File | Description |
|---|---|
| `reversi.pl` | Complete Prolog game engine: board logic, move generation, heuristic evaluation, negamax alpha-beta search |
| `reversi_ui.py` | Python/PySwip bridge and ipywidgets frontend (used if running standalone) |
| `reversi.ipynb` | Self-contained Jupyter notebook — installs dependencies, embeds Prolog source, runs the game and analysis |

---

## Quickstart

The notebook is fully self-contained. Open `reversi.ipynb` and run all cells top to bottom.

```
jupyter notebook reversi.ipynb
```

Cell 1 will install `pyswip`, `ipywidgets`, and SWI-Prolog automatically if they are not already present (Linux/Colab). On macOS, install SWI-Prolog manually first:

```
brew install swi-prolog
```

---

## Playing

- You play **Black** and move first
- Click any **yellow-highlighted** square to place your disc
- The AI responds automatically as **White**
- Press **New Game** to restart

---

## Adjusting Difficulty

Search depth is set by a single fact in `reversi.pl`:

```prolog
search_depth(4).
```

| Depth | Approx. response time |
|---|---|
| 2 | < 0.1s |
| 3 | < 0.6s |
| 4 | < 3s (default) |
| 5 | up to 12s |

---

## Dependencies

- SWI-Prolog
- Python 3.8+
- `pyswip`
- `ipywidgets`
- `matplotlib` (analysis cells only)

---

## Project Context

Built as the CS152 final project. Targets the `#search` and `#aicoding` learning outcomes. The full write-up is in `cs152_final_report.docx`.
