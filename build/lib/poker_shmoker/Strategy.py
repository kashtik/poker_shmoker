import numpy
import eval7
import math
import random
from poker_shmoker.GTOSolver import GtoSolver
from poker_shmoker.GameEngine import Game


class Strategy:
    def __init__(self, opt_range_num_param_i=20, opt_range_num_param_ii=20):
        self.NUM_PARAM_I = opt_range_num_param_i
        self.NUM_PARAM_II = opt_range_num_param_ii

    def move(self, game_state):
        # Getting needed variables

        last_action_player_id = len(game_state.game_state_history)

        hero_id = ((game_state.players[last_action_player_id:] +
                    game_state.players[:last_action_player_id])[1:].index(1)) % len(game_state.players)
        maximum_bet = max(game_state.player_bets)
        hand_position = self.get_hand_position(game_state, player_id=hero_id)
        position_coefficient = self.get_position_coefficient(game_state, player_id=hero_id)
        pot = game_state.pot
        board = game_state.board

        players = game_state.players[hero_id:] + game_state.players[:hero_id]
        ranges = game_state.player_ranges[hero_id:] + game_state.player_ranges[:hero_id]
        player_bets = game_state.player_bets[hero_id:] + game_state.player_bets[:hero_id]

        print(players);

        ranges = [value for key, value in enumerate(ranges) if players[key] != 0]
        player_bets = [value for key, value in enumerate(player_bets) if players[key] != 0]

        if pot == 0:
            # Preflop
            if maximum_bet > game_state.big_blind:
                # Call or raise
                raise_amnt = maximum_bet*3

                raise_value_range = self.eval7_wrapper_opt_range(pot, raise_amnt, ranges, player_bets, board)
                call_value_range = self.eval7_wrapper_opt_range(pot, maximum_bet, ranges, player_bets, board)

                print("Preflop call or raise: hand_position=", hand_position, "/", len(game_state.player_ranges[hero_id]), "raise_value_range=", raise_value_range, "call_value_range=", call_value_range )

                if hand_position < raise_value_range/2:
                    return ["bet", raise_amnt]
                elif hand_position < call_value_range:
                    return ["call", maximum_bet]
                else:
                    return ["fold", 0]

            if maximum_bet == game_state.big_blind:
                # Raise only
                raise_amnt = maximum_bet * 3

                raise_value_range = self.eval7_wrapper_opt_range(pot, raise_amnt, ranges, player_bets, board)
                print("Preflop raise only: hand_position=", hand_position, "/", len(game_state.player_ranges[hero_id]), "raise_value_range=", raise_value_range )

                if hand_position < raise_value_range:
                    return ["bet", raise_amnt]
                else:
                    return ["fold", 0]

        else:
            # Flop and etc
            if maximum_bet == 0:
                # Check or bet
                bet_multiplier = random.choice([0.75, 1])
                hero_bet = pot*bet_multiplier

                bet_value_range = self.eval7_wrapper_opt_range(pot, hero_bet, ranges, player_bets, board)

                gs = GtoSolver(pot, hero_bet, hero_bet*3)
                action_array = gs.check_or_bet(bet_value_range, len(game_state.player_ranges[hero_id]),
                                               position_coef=position_coefficient, cr=True,
                                               betting_round=game_state.betting_round)
                print("Check or Bet action: hand_position=", hand_position, "/", len(game_state.player_ranges[hero_id]), "bet_value_range=", bet_value_range)
                gs.visualize(action_array, hand_position)
                if action_array[hand_position] == "BET":
                    return ["bet", hero_bet]
                else:
                    return ["call", 0]

            else:
                # Call or Raise
                raise_amnt = maximum_bet*3

                raise_value_range = self.eval7_wrapper_opt_range(pot, raise_amnt, ranges, player_bets, board)

                if maximum_bet/pot < 0.5:
                    call_value_range = len(game_state.player_ranges[hero_id])
                else:
                    call_value_range = self.eval7_wrapper_opt_range(pot, maximum_bet, ranges, player_bets, board)

                gs = GtoSolver(pot, maximum_bet, raise_amnt)

                action_array = gs.call_or_raise(raise_value_range, call_value_range,
                                                len(game_state.player_ranges[hero_id]),
                                                position_coef=position_coefficient)

                print("Call or Raise action: hand_position=", hand_position, "/",
                      len(game_state.player_ranges[hero_id]), "raise_value_range=",
                      raise_value_range, "call_value_range=", call_value_range)

                gs.visualize(action_array, hand_position)

                if action_array[hand_position] == "RAISE":
                    return ["bet", raise_amnt]
                elif action_array[hand_position] == "CALL":
                    return ["call", maximum_bet]
                else:
                    return ["fold", 0]

        raise Exception("Move something went wrong went too far")

    def adjust_range(self, game_state):
        '''
        Adjusting players range depending on the action they took
        Should adjust the actual range
        '''
        action = game_state.game_state_history[game_state.latest_action_index()]
        bet = action[3]
        player_id = action[0]
        pot = game_state.pot
        maximum_bet = max(game_state.player_bets)
        board = list(game_state.board)
        position_coefficient = self.get_position_coefficient(game_state)

        players = game_state.players[player_id:] + game_state.players[:player_id]
        ranges = game_state.player_ranges[player_id:] + game_state.player_ranges[:player_id]
        player_bets = game_state.player_bets[player_id:] + game_state.player_bets[:player_id]

        print("players:", players)

        ranges = [value for key, value in enumerate(ranges) if players[key] != 0]
        player_bets = [value for key, value in enumerate(player_bets) if players[key] != 0]

        range_length = len(game_state.player_ranges[player_id])
        # -- Preflop handling
        if pot == 0:
            if bet > maximum_bet:
                # Preflop Raize
                raise_value_range = self.eval7_wrapper_opt_range(pot, bet, ranges, player_bets, board)

                game_state.player_ranges[player_id] = game_state.player_ranges[player_id][:int(raise_value_range)]
                return

            if bet == maximum_bet:
                # Preflop Call
                call_value_range = self.eval7_wrapper_opt_range(pot, maximum_bet, ranges, player_bets, board)

                game_state.player_ranges[player_id] = game_state.player_ranges[player_id][:int(call_value_range)]
                return


        # -- Must be later than preflop
        # Check [call, 0] or [bet, 0]
        if bet == 0:
            assumed_bet = pot * 0.75

            value_range = self.eval7_wrapper_opt_range(pot, assumed_bet, ranges, player_bets, board)

            gs = GtoSolver(pot, assumed_bet, assumed_bet*3)
            action_array = gs.check_or_bet(value_range, len(game_state.player_ranges[player_id]),
                                           position_coef=position_coefficient, cr=True,
                                           betting_round=game_state.betting_round)

            game_state.player_ranges[player_id] = [ game_state.player_ranges[player_id][i] for i, val in enumerate(action_array) if
                                                    val == "CHECK" ]

            # gs.visualize(action_array)
            return

        # Bet
        if bet > maximum_bet == 0:

            value_range = self.eval7_wrapper_opt_range(pot, bet, ranges, player_bets, board)

            gs = GtoSolver(pot, bet, bet*3)
            action_array = gs.check_or_bet(value_range, len(game_state.player_ranges[player_id]),
                                           position_coef=position_coefficient, cr=True,
                                           betting_round=game_state.betting_round)

            game_state.player_ranges[player_id] = [ game_state.player_ranges[player_id][i] for i, val in enumerate(action_array) if
                                              val == "BET" ]
            # gs.visualize(action_array)
            return

        # Call
        if bet == maximum_bet and maximum_bet > 0:
            call_value_range = self.eval7_wrapper_opt_range(pot, bet,
                                                            ranges, player_bets, board)
            raise_value_range = self.eval7_wrapper_opt_range(pot, bet*3,
                                                             ranges, player_bets, board)

            gs = GtoSolver(pot, bet, bet*3)

            action_array = gs.call_or_raise(raise_value_range, call_value_range, len(game_state.player_ranges[player_id]),
                                            position_coef=position_coefficient)

            game_state.player_ranges[player_id] = [ game_state.player_ranges[player_id][i] for i, val in enumerate(action_array) if
                                              val == "CALL" ]
            # gs.visualize(action_array)
            return

        # Raise
        if bet > maximum_bet > 0:

            call_value_range = self.eval7_wrapper_opt_range(pot, bet, ranges,
                                                            player_bets, board)
            raise_value_range = self.eval7_wrapper_opt_range(pot, bet, ranges,
                                                             player_bets, board)

            gs = GtoSolver(pot, maximum_bet, bet)
            action_array = gs.call_or_raise(raise_value_range, call_value_range, len(game_state.player_ranges[player_id]),
                                            position_coef=position_coefficient)

            game_state.player_ranges[player_id] = [game_state.player_ranges[player_id][i] for i, val in enumerate(action_array) if
                                             val == "RAISE"]
            # gs.visualize(action_array)
            return

        raise Exception("Adjust range act", action, "falls into no categories")

    @staticmethod
    def get_position_coefficient(game_state, player_id=None):
        if player_id is None:
            player_id = game_state.game_state_history[game_state.latest_action_index()][0]

        players = list(game_state.players)
        players[player_id] = 2

        button_plus_one = (game_state.button+1) % len(players)

        players_after_button = players[button_plus_one:]+players[:button_plus_one]
        villains_before_player = sum([1 for i in range(0, players_after_button.index(2)) if players_after_button[i] != 0])
        total_villains = sum([i for i in players_after_button if i != 2])

        return villains_before_player/total_villains

    @staticmethod
    def get_hand_position(game_state, player_id=None):
        if player_id is None:
            player_id = game_state.game_state_history[game_state.latest_action_index()][0]

        hero_range = [each[0] for each in game_state.player_ranges[player_id]]

        if game_state.hero_hand not in hero_range or game_state.hero_hand.reverse() not in hero_range:
            game_state.player_ranges[player_id].append([game_state.hero_hand, 1])
            game_state.player_ranges.sort(board=game_state.board,
                                          has_cards=game_state.players)

        hero_range = [each[0] for each in game_state.player_ranges[player_id]]

        try:
            return hero_range.index(game_state.hero_hand)
        except:
            return hero_range.index(game_state.hero_hand.reverse())

    def eval7_wrapper_opt_range(self, pp, cmb, rngs, pb, brd):
        """
        :param pp: previous pot
        :param cb: current maximum bet
        :param rngs: ranges
        :param pb: player bets
        :param brd: board
        :return:
        """

        rngs = list(rngs)
        print(pp, cmb, [len(each) for each in rngs], pb, brd)
        res = eval7.py_optimal_ranges_calculator(pp, cmb, rngs, pb, brd, 0, self.NUM_PARAM_I, self.NUM_PARAM_II)

        numpy_res = numpy.array(res)
        print(numpy_res)
        #return_value = numpy.mean( [ numpy_res[each] for each in argrelextrema(numpy_res, numpy.less)] )

        #if math.isnan(return_value):
        return_value = numpy.mean(numpy_res)

        if math.isnan(return_value):
            return 0
        return return_value


if __name__ == "__main__":
    hero_hand = ["Ah", "As"]
    print("Hero hand:", hero_hand)
    board = ['Jh', '5s', 'Ts']
    """
     game_state_history =    [

                            ["Button_pos", 8],
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
                            ["board", board+["3d"]]
                            #[8, "player1", "bets", 1200],
                            #[0, "plauer1", "calls", 600],
                            #[1, "plauyer", "calls", 600]
            ]
    """
    game_state_history = [
        ["button_pos", 4],
        [1,0,0,0,1,0,0,0,0],
        [4, "player", "bets", 10],
        [0, "player", "bet", 20]
    ]


    game = Game(game_state_history)
    strat = Strategy()
    game.use_strategy(strat)
    game.adjust_ranges()
    print(game.move(hero_hand))