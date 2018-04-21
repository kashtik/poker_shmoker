import numpy
import eval7
from Ranges import Ranges


class Game:

    def __init__(self, game_state):
        print("Poker eval starting...")

        # -- Ranges object
        self.player_ranges = Ranges()

        # -- Resetting params
        self.board = []
        self.adjusted = []
        self.pot = 0
        self.big_blind = 0
        self.small_blind = 0

        self.button = None
        self.players = None
        self.game_state_history = None
        self.strategy = None
        self.player_bets = None
        self.hero_hand = None

        print("Setting state...")
        self.game_state_history = game_state
        self.betting_round = 0
        self.adjusted = [False for _ in range(0, len(self.game_state_history))]

    def adjust_ranges(self):

        if not self.adjusted[0]:
            # Initial reset - Button, Blinds, How many players
            self.button = self.game_state_history[0][1]

            self.players = self.game_state_history[1]

            self.player_bets = [0 for _ in range(0, len(self.players))]

            self.small_blind = self.game_state_history[2][3]
            self.player_bets[self.game_state_history[2][0]] = self.small_blind

            self.big_blind = self.game_state_history[3][3]
            self.player_bets[self.game_state_history[3][0]] = self.big_blind

            # First 5 lines are adjusted: Button, Players, preflop
            self.adjusted[0:4] = [True for _ in range(0, 4)]

            self.player_ranges.sort([], self.players)

        for i, action in enumerate(self.game_state_history[4:]):

            if not self.adjusted[i+4]:

                if action[0] == "board":
                    self.betting_round += 1
                    self.board = [eval7.Card(c) for c in action[1]] # Board is the next line after stage indicator
                    self.player_ranges.filter(self.board)
                    self.player_ranges.sort(self.board, self.players)
                    self.pot += sum(self.player_bets) # collecting the pot - money/ not weed
                    self.player_bets = [0 for _ in range(0, len(self.players))] # resetting bets to 0 - everything went to pot
                    self.adjusted[i + 4] = True
                    continue

                print(action)
                player, player_name, move, bet_size = tuple(action)

                if move == "folds":
                    self.players[player] = 0
                    self.adjusted[i + 4] = True
                    continue

                self.strategy.adjust_range(self)
                self.player_bets[player] = bet_size
                self.adjusted[i+4] = True

    def latest_action_index(self):
        ind = self.adjusted.index(False)
        return ind

    def use_strategy(self, strategy):
        self.strategy = strategy

    def move(self, hero_hand=None):
        if hero_hand is None:
            raise Exception("Give hero hand for move")

        hh = [eval7.Card(c) for c in hero_hand]
        self.hero_hand = hh

        return self.strategy.move(self)


if __name__ == "__main__":

    class Strat:

        def adjust_range(self, game_engine,action,i):
            print(action, i, game_engine.latest_action_index(), game_engine.game_state_history[game_engine.latest_action_index()])
            #print("Pot:", game_engine.pot, "Participants:", game_engine.players, "Adjusted:", game_engine.adjusted, "Game round:", game_engine.betting_round)
            return

        def move(self, game_engine):
            print("doing move")
            return

    print("Testing")
    board = ['Jh', '5s', 'Ts']
    game_state = [
                ["button_pos", 8],
                [1, 1, 1, 1, 1, 1, 1, 1, 1],
                [0, 'player1', 'bets', 10],
                [1, 'player2', 'bets', 20],
                [2, 'player1', 'folds', 100],
                [3, 'player1', 'folds', 100],
                [4, 'player1', 'folds', 100],
                [5, 'player1', 'folds', 100],
                [6, "player6", "folds", 60],
                [7, "player6", "folds", 100],
                [8, "player6", "bets", 60],
                [0, 'player1', 'calls', 60],
                [1, 'player2', 'calls', 60],

                ["board", board],
                [0, 'player1', 'bets', 200],
                [1, 'player1', 'calls', 200],
                [8, "player1", "calls", 200],
                ["board", board+["3d"]],
                [8, "player1", "bets", 1200],
                #[0, "plauer1", "calls", 600],
                #[1, "plauyer", "calls", 600]
            ]

    strat = Strat()

    game = Game(game_state)
    game.use_strategy(strat)
    game.adjust_ranges()
    game.move(hero_hand=["As", "Ac"])
    game.adjust_ranges()
