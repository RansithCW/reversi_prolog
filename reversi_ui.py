"""
reversi_ui.py  -  Jupyter ipywidgets frontend for the Prolog Reversi engine.

Usage (in a Jupyter notebook):
    from reversi_ui import ReversiGame
    game = ReversiGame()
    game.show()
"""

import os, re, threading
from pyswip import Prolog
import ipywidgets as widgets
from IPython.display import display

_PROLOG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reversi.pl")

def _parse_moves(raw):
    """Parse list of R-C Prolog terms into (row, col) tuples."""
    moves = []
    for m in raw:
        nums = re.findall(r'\d+', str(m))
        moves.append((int(nums[0]), int(nums[1])))
    return moves

def _board_str(board):
    return '[' + ','.join(board) + ']'


class ReversiGame:
    """Human (black=k) vs AI (white=w). Black moves first."""

    SQ_A   = "#4a7c59"
    SQ_B   = "#55905f"
    HINT   = "#d4c84a"
    BG     = "#1e1e1e"
    HDR    = "#cccccc"

    def __init__(self):
        self._pl = Prolog()
        self._pl.consult(_PROLOG_FILE)
        self._init_state()
        self._build_ui()

    # Prolog bridge

    def _q1(self, goal):
        sols = list(self._pl.query(goal, maxresult=1))
        return sols[0] if sols else None

    def _valid_moves(self, board, player):
        sol = self._q1(f"valid_moves({_board_str(board)},{player},M)")
        if not sol:
            return []
        return _parse_moves(sol["M"])

    def _apply_move(self, board, player, r, c):
        sol = self._q1(f"apply_move({_board_str(board)},{player},{r},{c},NB)")
        return [str(x) for x in sol["NB"]] if sol else board

    def _best_move(self, board, player):
        sol = self._q1(f"best_move({_board_str(board)},{player},BR,BC,_)")
        if not sol:
            return None
        return int(sol["BR"]), int(sol["BC"])

    def _game_over(self, board):
        return bool(list(self._pl.query(f"game_over({_board_str(board)})", maxresult=1)))

    def _winner(self, board):
        sol = self._q1(f"winner({_board_str(board)},W)")
        return str(sol["W"]) if sol else "draw"

    def _count(self, board, p):
        return board.count(p)

    # State

    def _init_state(self):
        sol = self._q1("initial_board(B)")
        self._board  = [str(x) for x in sol["B"]]
        self._human  = "k"
        self._ai     = "w"
        self._turn   = "k"
        self._valid  = self._valid_moves(self._board, self._turn)
        self._ended  = False

    # UI construction

    def _build_ui(self):
        self._btns = []
        cells = []
        for r in range(8):
            row = []
            for c in range(8):
                btn = widgets.Button(
                    layout=widgets.Layout(width="54px", height="54px", margin="1px",
                                         border="none"))
                btn.on_click(self._make_handler(r, c))
                row.append(btn)
                cells.append(btn)
            self._btns.append(row)

        self._grid = widgets.GridBox(
            children=cells,
            layout=widgets.Layout(
                grid_template_columns="repeat(8, 56px)",
                grid_template_rows="repeat(8, 56px)",
                background_color=self.BG,
                padding="4px"))

        self._status = widgets.HTML()
        self._score  = widgets.HTML()

        new_btn = widgets.Button(description="New Game",
                                 button_style="warning",
                                 layout=widgets.Layout(width="110px", margin="6px 0 0 0"))
        new_btn.on_click(lambda _: self._new_game())

        title = widgets.HTML(
            f"<h3 style='color:{self.HDR};margin:4px 0 8px 0'>"
            "Reversi &nbsp;|&nbsp; You = &#9679; Black &nbsp;vs&nbsp; AI = &#9675; White</h3>")

        self._ui = widgets.VBox(
            [title, self._grid, self._score, self._status, new_btn],
            layout=widgets.Layout(background_color=self.BG, padding="14px", width="510px"))

    def _make_handler(self, r, c):
        def h(_): self._on_click(r, c)
        return h

    # Rendering

    def _render(self):
        hint_set = set(self._valid) if self._turn == self._human and not self._ended else set()
        for r in range(8):
            for c in range(8):
                pos  = r * 8 + c
                cell = self._board[pos]
                btn  = self._btns[r][c]
                sq   = self.SQ_A if (r + c) % 2 == 0 else self.SQ_B

                if cell == "k":
                    btn.description = "\u26ab"          # black circle
                    btn.style.button_color = "#111111"
                elif cell == "w":
                    btn.description = "\u26aa"          # white circle
                    btn.style.button_color = "#eeeeee"
                elif (r, c) in hint_set:
                    btn.description = "\u00b7"
                    btn.style.button_color = self.HINT
                else:
                    btn.description = ""
                    btn.style.button_color = sq

        bk = self._count(self._board, "k")
        wh = self._count(self._board, "w")
        self._score.value = (
            f"<span style='color:#aaa;font-size:14px'>"
            f"&#9679; Black: <b>{bk}</b> &nbsp;|&nbsp; "
            f"&#9675; White: <b>{wh}</b></span>")

    def _set_status(self, msg, col="#99ddaa"):
        self._status.value = f"<span style='color:{col};font-size:13px'>{msg}</span>"

    # Game flow

    def _on_click(self, r, c):
        if self._ended or self._turn != self._human:
            return
        if (r, c) not in self._valid:
            self._set_status("Invalid move - choose a highlighted square.", "#ffaa44")
            return
        self._board = self._apply_move(self._board, self._human, r, c)
        self._advance()

    def _advance(self):
        if self._game_over(self._board):
            self._finish(); return

        # Switch sides
        self._turn = self._ai if self._turn == self._human else self._human
        self._valid = self._valid_moves(self._board, self._turn)

        if not self._valid:
            who = "AI" if self._turn == self._ai else "You"
            self._set_status(f"{who} has no moves - passing.", "#ffdd88")
            self._turn = self._human if self._turn == self._ai else self._ai
            self._valid = self._valid_moves(self._board, self._turn)
            if not self._valid:
                self._render(); self._finish(); return

        self._render()

        if self._turn == self._ai:
            self._set_status("AI is thinking...", "#88bbff")
            threading.Thread(target=self._ai_turn, daemon=True).start()
        else:
            self._set_status("Your turn (&#9679;) - click a highlighted square.")

    def _ai_turn(self):
        move = self._best_move(self._board, self._ai)
        if move is None:
            self._advance(); return
        r, c = move
        self._board = self._apply_move(self._board, self._ai, r, c)
        self._advance()

    def _finish(self):
        self._ended = True
        self._valid = []
        self._render()
        w  = self._winner(self._board)
        bk = self._count(self._board, "k")
        wh = self._count(self._board, "w")
        if w == "k":
            self._set_status(f"You win!  Black {bk} - {wh} White", "#88ff88")
        elif w == "w":
            self._set_status(f"AI wins!  White {wh} - {bk} Black", "#ff8888")
        else:
            self._set_status(f"Draw!  {bk} - {wh}", "#ffdd88")

    def _new_game(self):
        self._init_state()
        self._ended = False
        self._render()
        self._set_status("Your turn (&#9679;) - click a highlighted square.")

    # Public

    def show(self):
        self._render()
        self._set_status("Your turn (&#9679;) - click a highlighted square.")
        display(self._ui)
