import numpy
import eval7
from ShmokerCache import *
import itertools
import os

hs_cache = ShmokerCache(calc_rate=0.05, client_ip="127.0.0.1", refresh_type="average")


def load_all_hands():
    array_path = os.path.dirname(os.path.abspath(__file__)) + "/array_storage"
    all_possible_hands = [[eval7.Card(each[0]), eval7.Card(each[1])] for each in
                          numpy.load(array_path + "/sorted_starting_hands.npy")]
    return [[each, 1] for each in all_possible_hands]


class Ranges:

    def __init__(self):
        self.starting_range = load_all_hands()
        self.card_ranges = [self.starting_range for _ in range(0, 9)]

    def __setitem__(self, key, value):
        self.card_ranges[key] = value

    def __getitem__(self, item):
        return self.card_ranges[item]

    def sort(self, board=[], has_cards=None):

        if len(board) > 0:
            if isinstance(board[0], str):
                hands_2_score_dict = self.hands_2_scores(board=[eval7.Card(c) for c in board], has_cards=has_cards)
            else:
                hands_2_score_dict = self.hands_2_scores(board=board, has_cards=has_cards)
        else:
            hands_2_score_dict = self.hands_2_scores(board=[], has_cards=has_cards)

        def key_lookup(x):
            try:
                return hands_2_score_dict[tuple(x[0])]
            except:
                return hands_2_score_dict[tuple([x[0][1], x[0][0]])]

        for i in range(0, len(self.card_ranges)):
            self.card_ranges[i] = sorted(self.card_ranges[i],
                                         key=key_lookup,
                                         reverse=True)

    def hands_2_scores(self, **kwargs):
        return_dict = {}
        villain_ranges = [self.starting_range for each in kwargs["has_cards"] if each != 0]
        for each in self.starting_range:
            self.VR = villain_ranges # Have to do monkey shit and use length instead of villain ranges - Cache
            score = self.eval7_wrapper_hand_score(each[0], len(villain_ranges), kwargs["board"])
            return_dict[tuple(each[0])] = score
        return return_dict

    @hs_cache
    def eval7_wrapper_hand_score(self, hand, len_villain_ranges, board):
        return eval7.py_hand_vs_multi_range_monte_carlo(hand, self.VR, board, 2000)

    def filter(self, current_board):
        for i in range(0, len(self.card_ranges)):
            self.card_ranges[i] = [ hand for hand in self.card_ranges[i] if hand[0] not in current_board and hand[1] not in current_board ]


if __name__ == "__main__":
    ran = Ranges()
    ran[0] = [1, 2, 3]
    print(list(itertools.chain(([1, 2, 3], [1, 2, 3]))))
    print(ran[0])
    pass
