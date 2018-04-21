from scipy.optimize import fsolve
import time


class GtoSolver:

    def __init__(self, pot, bet, rai):
        self.Pot = pot
        self.Bet = bet
        self.Raise = rai
        self.solved_game_1, self.solved_game_2, self.solved_game_3 = self.solve_equations()
        return

    @staticmethod
    def equations_2(var_tuple, pot, bet, rai):
        a, b, c, d, e, f, g, h, j, k, m, n = var_tuple
        return (
            pot*k - bet*(1-k),
            (pot+bet)*g + (pot+bet+rai)*j - (pot+bet)*h - rai,
            (pot+bet+rai)*j - (pot+2*bet)*h - (rai-bet),
            bet*g - bet*h - (pot+bet)*k + (pot+2*bet)*m,
            (bet+pot+rai)*k - (bet+pot+rai)*m + (bet-rai)*n - (bet-rai),
            (rai-pot)*m - rai*k + (bet-rai)*n + (pot-bet)*f - bet*g + (rai-pot)*j + bet*h,
            (pot+bet)*b - bet*d + bet*f - pot*g - bet,
            bet*d - (pot+bet)*b - (2*bet)*h + (pot+2*bet)*c - bet*f + bet,
            (pot+rai+bet)*b - (pot+rai+bet)*c - (rai-bet)*f + rai - bet,
            (pot+bet)*a + (rai+bet+pot)*e - (pot+bet)*d - rai*f,
            (rai+bet+pot)*e - (pot+2*bet)*d - (rai-bet)*f,
            (2*bet - 2*rai)*n + (rai-bet)*f + (rai-bet)*e
        )

    @staticmethod
    def equations_1(var_tuple, pot, bet):
        a, b, c, d, e, f = var_tuple
        return (
            d - bet/(pot+bet),
            (pot+bet)*e + bet*f - bet,
            e - f + d,
            (pot+bet)*a + bet*c - bet,
            (pot+bet)*b - bet*c - pot*e,
            b + c - 2*f
        )

    def solve_equations(self):
        starting_point = (0.04102564, 0.52564103, 0.54871795, 0.87179487, 0.91282051, 0.95384615, 0.13333333,
                          0.73333333, 0.86666667, 0.5, 0.53333333, 0.93333333)
        return (fsolve(self.equations_1, starting_point[:6], (self.Pot, self.Bet)),
                fsolve(self.equations_2, starting_point, (self.Pot, self.Bet, self.Raise)),
                fsolve(self.equations_1, starting_point[:6], (self.Pot + self.Bet*2, self.Raise-self.Bet)))

    def b_2_c_ratio(self, position_coef=0):
        early_position = (1-self.solved_game_1[2])/(1-self.solved_game_1[1])
        late_position = (1-self.solved_game_1[5])/(1-self.solved_game_1[3])
        return min([1, early_position*(1-position_coef) + late_position*position_coef])

    def cr_2_b_ratio(self):
        if self.solved_game_2[5] > 1 or self.solved_game_2[3] > 1:
            return 0
        return (1-self.solved_game_2[5])/(1-self.solved_game_2[3])

    def r_2_c_ratio(self, position_coef=0):
        '''
        total_length_of_betting_range = self.solved_game_2[5]-self.solved_game_2[3]+self.solved_game_2[0]
        raise_bet = self.Raise - self.Bet
        raise_pot = self.Pot + 2*self.Bet
        raise_value_range = raise_bet*total_length_of_betting_range/(raise_pot+raise_bet)
        calculated_raise_value_range = 1-self.solved_game_2[11]
        print("r_2_c_ratio:", calculated_raise_value_range/raise_value_range)
        return min([calculated_raise_value_range/raise_value_range, 1])
        '''
        early_position = (1 - self.solved_game_3[2]) / (1 - self.solved_game_3[1])
        late_position = (1 - self.solved_game_3[5]) / (1 - self.solved_game_3[3])
        return min([1, early_position*(1-position_coef) + late_position*position_coef])

    def raise_bluff_ratio(self):
        return self.solved_game_3[0]/(1-self.solved_game_3[2])

    def bluff_ratio(self):
        return self.solved_game_1[0]/(1-self.solved_game_1[2])

    def call_or_raise(self,
                      raising_value_range,
                      calling_value_range,
                      total_number_hands,
                      position_coef=0):

        raising_range = raising_value_range*self.r_2_c_ratio(position_coef=position_coef)

        return_array = []

        return_array += ["RAISE" for _ in range(int(raising_range))]
        return_array += ["CALL" for _ in range(int(calling_value_range - len(return_array) ))]

        number_of_bluff_raise_hands = raising_range * self.raise_bluff_ratio()
        return_array += ["RAISE" for _ in range(min( [int(number_of_bluff_raise_hands), total_number_hands] ))]
        return_array += ["FOLD" for _ in range(total_number_hands-len(return_array))]

        return return_array[:total_number_hands]

    def check_or_bet(self, value_range, total_number_hands, position_coef=0, cr=False, betting_round=3):

        betting_range = value_range*self.b_2_c_ratio(position_coef=position_coef)

        return_array = []

        if cr:
            return_array += ["CHECK" for _ in range( min([int(betting_range/2), int(betting_range * self.cr_2_b_ratio()) ]) )]
            return_array += ["BET" for _ in range(int(betting_range - len(return_array)))]
        else:
            return_array += ["BET" for _ in range(min( [int(betting_range), total_number_hands] ))]

        # Adding more bluffs to range on previous streets
        bluff_ratio = self.bluff_ratio()*(4-betting_round)

        if cr:
            bluffing_start_index = total_number_hands - betting_range * bluff_ratio * (1 - self.cr_2_b_ratio())
        else:
            bluffing_start_index = total_number_hands - betting_range * bluff_ratio

        return_array += ["CHECK" for _ in range(int(bluffing_start_index - len(return_array)))]
        return_array += ["BET" for _ in range(total_number_hands - len(return_array))]

        return return_array[:total_number_hands]

    def visualize(self, action_array, hand_position=None, max_num=60):

        _d = {
            "CHECK": "-",
            "CALL": "-",
            "FOLD": "_",
            "BET": "+",
            "RAISE": "+"
        }

        if len(action_array) > max_num:
            _action_array = [ action_array[int(i*len(action_array)/max_num)] for i in range(max_num) ]
        else:
            _action_array = action_array

        if hand_position is not None:
            if len(action_array) > max_num:
                _index = int( hand_position*max_num/len(action_array) )
            else:
                _index = int(hand_position)
            print( "_"*_index+"+"+"_"*(len(_action_array)-_index) )

        _print_string = ""
        for each in _action_array:
            _print_string += _d[each]
        print(_print_string)


if __name__ == "__main__":
    # -- Testing shit
    time_start = time.time()
    GS = GtoSolver(2, 2, 8)
    print(GS.solved_game_1)
    print(GS.solved_game_2)
    print(GS.solved_game_3)
    print("Time taken:", time.time() - time_start)
    print("Bet to check ratio:", GS.b_2_c_ratio())
    print("CR to bet ratio:", GS.cr_2_b_ratio())
    print("CR bluff ratio:", GS.raise_bluff_ratio())
    print("Raise to call ratio:", GS.r_2_c_ratio())

    cob = GS.check_or_bet(50, 100, cr=True, position_coef=1)
    GS.visualize(cob)

    cor = GS.call_or_raise(10, 50, 100)
    GS.visualize(cor, 30)