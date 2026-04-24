% ============================================================
%  Reversi (Othello) - Game Logic & AI in Prolog
%  CS152 Final Project
% ============================================================

% Board: flat list of 64 atoms. b=blank, w=white, k=black.
% Cell index = Row*8 + Col  (0-indexed, row-major).

% Board construction

blank_board(B) :- length(B, 64), maplist(=(b), B).

initial_board(Board) :-
    blank_board(B0),
    set_cell(27, w, B0, B1),
    set_cell(28, k, B1, B2),
    set_cell(35, k, B2, B3),
    set_cell(36, w, B3, Board).

% set_cell(+Idx, +Val, +In, -Out)
set_cell(0, V, [_|T], [V|T]) :- !.
set_cell(I, V, [H|T], [H|R]) :-
    I > 0, I1 is I - 1,
    set_cell(I1, V, T, R).

% get_cell(+Idx, +Board, -Val)
get_cell(0, [H|_], H) :- !.
get_cell(I, [_|T], V) :-
    I > 0, I1 is I - 1,
    get_cell(I1, T, V).

opponent(w, k).
opponent(k, w).

% 8 directions (dr, dc)
dir( 0, 1). dir( 0,-1). dir( 1, 0). dir(-1, 0).
dir( 1, 1). dir( 1,-1). dir(-1, 1). dir(-1,-1).

% Ray scan: collect opponent pieces bracketed by Player
% ray(+Board, +Opp, +Player, +R, +C, +DR, +DC, +Acc, -Flips)
ray(Board, Opp, Player, R, C, DR, DC, Acc, Flips) :-
    R >= 0, R < 8, C >= 0, C < 8,
    Pos is R*8 + C,
    get_cell(Pos, Board, V),
    (   V = Opp
    ->  R1 is R+DR, C1 is C+DC,
        ray(Board, Opp, Player, R1, C1, DR, DC, [Pos|Acc], Flips)
    ;   V = Player, Acc \= []
    ->  Flips = Acc
    ;   fail
    ).

% all_flips(+Board, +Player, +Row, +Col, -Flips)
all_flips(Board, Player, Row, Col, All) :-
    opponent(Player, Opp),
    findall(Fs,
        ( dir(DR,DC),
          R1 is Row+DR, C1 is Col+DC,
          ray(Board, Opp, Player, R1, C1, DR, DC, [], Fs) ),
        Lists),
    flatten(Lists, All).

% Valid moves
valid_move(Board, Player, R, C) :-
    R >= 0, R < 8, C >= 0, C < 8,
    Pos is R*8 + C,
    get_cell(Pos, Board, b),
    all_flips(Board, Player, R, C, Fs),
    Fs \= [].

valid_moves(Board, Player, Moves) :-
    findall(R-C,
        ( between(0,7,R), between(0,7,C),
          valid_move(Board, Player, R, C) ),
        Moves).

% Apply a move
flip_all([], _, B, B).
flip_all([H|T], P, B, Out) :-
    set_cell(H, P, B, B1),
    flip_all(T, P, B1, Out).

apply_move(Board, Player, R, C, NB) :-
    all_flips(Board, Player, R, C, Fs),
    Pos is R*8 + C,
    set_cell(Pos, Player, Board, B1),
    flip_all(Fs, Player, B1, NB).

% Piece counting
count_pieces(Board, P, N) :-
    include(=(P), Board, Ps),
    length(Ps, N).

% Positional weight table
% Corners=100, X-squares=-20, C-squares=-10, edges=10, near-edge=5, rest=3
cell_w(R, C, W) :-
    ( corner(R,C) -> W = 100
    ; xsq(R,C)   -> W = -20
    ; csq(R,C)   -> W = -10
    ; edge(R,C)  -> W = 10
    ; ne(R,C)    -> W = 5
    ;                W = 3
    ).

corner(0,0). corner(0,7). corner(7,0). corner(7,7).
xsq(1,1). xsq(1,6). xsq(6,1). xsq(6,6).
csq(0,1). csq(1,0). csq(0,6). csq(6,0).
csq(7,1). csq(1,7). csq(7,6). csq(6,7).
edge(0,_). edge(7,_). edge(_,0). edge(_,7).
ne(1,C) :- between(1,6,C).
ne(6,C) :- between(1,6,C).
ne(R,1) :- between(1,6,R).
ne(R,6) :- between(1,6,R).

pos_score(Board, P, S) :- pos_score_(Board, P, 0, S).
pos_score_([], _, _, 0).
pos_score_([H|T], P, Idx, S) :-
    Idx1 is Idx + 1,
    pos_score_(T, P, Idx1, S1),
    ( H = P ->
        R is Idx // 8, C is Idx mod 8,
        cell_w(R, C, W), S is S1 + W
    ;   S is S1
    ).

% Heuristic evaluation (from Player perspective)

evaluate(Board, Player, Score) :-
    opponent(Player, Opp),
    pos_score(Board, Player, PP),
    pos_score(Board, Opp,    PO),
    valid_moves(Board, Player, ML), length(ML, MP),
    valid_moves(Board, Opp,    OL), length(OL, MO),
    ( MP+MO =:= 0 -> Mob = 0
    ; Mob is 100 * (MP - MO) / (MP + MO)
    ),
    count_pieces(Board, Player, CP),
    count_pieces(Board, Opp,    CO),
    PW is (CP + CO) / 64,
    Score is (PP - PO) + Mob + (CP - CO) * PW * 10.

% Search depth: change this value to adjust AI difficulty
:- dynamic search_depth/1.
search_depth(4).

% Negamax with alpha-beta pruning
% ab(+Board, +Player, +Depth, +Alpha, +Beta, -Score)
% Score is from the perspective of Player (negamax convention).

ab(Board, Player, 0, _, _, S) :-
    !,
    evaluate(Board, Player, S).

ab(Board, Player, D, A, B, S) :-
    D > 0,
    valid_moves(Board, Player, Moves),
    ( Moves = [] ->
        opponent(Player, Opp),
        valid_moves(Board, Opp, OM),
        ( OM = [] ->
            % Terminal: no moves for either player
            count_pieces(Board, Player, CP),
            count_pieces(Board, Opp, CO),
            ( CP > CO -> S = 100000
            ; CP < CO -> S = -100000
            ;             S = 0
            )
        ;   % Current player must pass
            D1 is D - 1,
            ab(Board, Opp, D1, -B, -A, S0),
            S is -S0
        )
    ;   ab_loop(Moves, Board, Player, D, A, B, S)
    ).

% ab_loop: iterate over moves, maintaining alpha bound
ab_loop([], _, _, _, A, _, A).
ab_loop([R-C|Rest], Board, Player, D, A, B, S) :-
    apply_move(Board, Player, R, C, NB),
    opponent(Player, Opp),
    D1 is D - 1,
    ab(NB, Opp, D1, -B, -A, CS),
    This is -CS,
    A2 is max(A, This),
    ( A2 >= B ->
        S = A2          % beta cut-off: prune remaining siblings
    ;   ab_loop(Rest, Board, Player, D, A2, B, S)
    ).

% Top-level best move
best_move(Board, Player, BestR, BestC, BestScore) :-
    search_depth(D),
    valid_moves(Board, Player, [First|Rest]),
    First = FR-FC,
    apply_move(Board, Player, FR, FC, NB0),
    opponent(Player, Opp),
    D1 is D - 1,
    ab(NB0, Opp, D1, -100000, 100000, S0),
    Init is -S0,
    pick(Rest, Board, Player, D, Init, FR, FC, BestScore, BestR, BestC).

pick([], _, _, _, BS, BR, BC, BS, BR, BC).
pick([R-C|Rest], Board, Player, D, Best, BR0, BC0, BS, FR, FC) :-
    apply_move(Board, Player, R, C, NB),
    opponent(Player, Opp),
    D1 is D - 1,
    ab(NB, Opp, D1, -100000, 100000, CS),
    This is -CS,
    ( This > Best ->
        pick(Rest, Board, Player, D, This, R,   C,   BS, FR, FC)
    ;   pick(Rest, Board, Player, D, Best, BR0, BC0, BS, FR, FC)
    ).

% Game over / winner
game_over(Board) :-
    valid_moves(Board, w, []),
    valid_moves(Board, k, []).

winner(Board, W) :-
    count_pieces(Board, w, WC),
    count_pieces(Board, k, KC),
    ( WC > KC -> W = w
    ; KC > WC -> W = k
    ;             W = draw
    ).
