# Copyright 2014 Anonymous7 from Reddit, Julian Andrews
#
# This software may be modified and distributed under the terms
# of the MIT license.  See the LICENSE file for details.

import cython
from wh_rand cimport wh_randint
from eval7 cimport cy_evaluate
from cards cimport cards_to_mask
from libc.math cimport round as rnd
from libc.math cimport abs as fabs



cdef extern from "stdlib.h":
    ctypedef unsigned long size_t
    void *malloc(size_t n_bytes)
    void free(void *ptr)

cdef cython.int c_round(
    cython.float n):
    return int(n)

cdef cython.ulonglong card_masks_table[52]


cdef cython.uint load_card_masks():
    for i in range(52):
        card_masks_table[i] = 1 << i
    return 0


load_card_masks()


cdef cython.uint filter_options(cython.ulonglong *source, 
        cython.ulonglong *target, 
        cython.uint num_options, 
        cython.ulonglong dead):
    """
    Removes all options that share a dead card
    Returns total number of options kept
    """
    cdef cython.ulonglong options
    cdef cython.uint total = 0
    for 0 <= s < num_options:
        option = source[s]
        if option & dead == 0:
            target[total] = option
            total += 1
    return total


cdef cython.ulonglong deal_card(cython.ulonglong dead):
    cdef cython.uint cardex
    cdef cython.ulonglong card
    while True:
        cardex = wh_randint(52)
        card = card_masks_table[cardex]
        if dead & card == 0:
            return card


cdef cython.float hand_vs_range_monte_carlo(cython.ulonglong hand, 
        cython.ulonglong *options, 
        cython.int num_options, 
        cython.ulonglong start_board, 
        cython.int num_board, 
        cython.int iterations):
    """
    Return equity of hand vs range.
    Note that only unweighted ranges are supported.
    Note that only heads-up evaluations are supported.
    
    hand is a two-card hand mask
    options is an array of num_options options for opponent's two-card hand
    board is a hand mask of the board; num_board says how many cards are in it
    """
    cdef cython.uint count = 0
    cdef cython.uint option_index = 0
    cdef cython.ulonglong option
    cdef cython.ulonglong dealt
    cdef cython.uint hero
    cdef cython.uint villain
    cdef cython.ulonglong board
    for 0 <= i < iterations:
        # choose an option for opponent's hand
        option = options[option_index]
        option_index += 1
        if option_index >= num_options:
            option_index = 0
        # deal the rest of the board
        dealt = hand | option
        board = start_board
        for j in range(5 - num_board):
            board |= deal_card(board | dealt)
        hero = cy_evaluate(board | hand, 7)
        villain = cy_evaluate(board | option, 7)
        if hero > villain:
            count += 2
        elif hero == villain:
            count += 1
    return 0.5 * <cython.double>count / <cython.double>iterations


def py_hand_vs_range_monte_carlo(py_hand, py_villain, py_board, 
       py_iterations):
    cdef cython.ulonglong hand = cards_to_mask(py_hand)
    cdef cython.int num_options = len(py_villain)
    cdef cython.ulonglong *options = <cython.ulonglong*>malloc(
            sizeof(cython.ulonglong) * num_options)
    cdef cython.ulonglong start_board = cards_to_mask(py_board)
    cdef cython.int num_board = len(py_board)
    cdef cython.int iterations = py_iterations
    cdef cython.float equity  # DuplicatedSignature
    cdef cython.ulonglong mask
    for index, option in enumerate(py_villain):
        options[index] = cards_to_mask(option[0])
        # This strips and ignores the weight.
    num_options = filter_options(options, options, num_options, 
            start_board | hand)
    equity = hand_vs_range_monte_carlo(hand, options, num_options, 
            start_board, num_board, iterations)
    free(options)
    return equity

cdef cython.float hand_vs_multi_range_monte_carlo(cython.ulonglong hand, 
        cython.ulonglong **options, 
        cython.int *num_options,
        cython.int num_villain,
        cython.ulonglong start_board, 
        cython.int num_board, 
        cython.int iterations):
    #print("Doing simulation itself")
    cdef cython.uint count = 0
    cdef cython.uint count_addition
    cdef cython.ulonglong *option = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*num_villain)
    cdef cython.ulonglong dealt
    cdef cython.uint hero
    cdef cython.uint *villain = <cython.uint*>malloc(sizeof(cython.uint)*num_villain)
    cdef cython.ulonglong board
    for 0 <= i < iterations:
        dealt = hand
        for 0 <= j < num_villain:
            #print(num_options[j])
            option[j] = options[j][wh_randint(num_options[j])]
            dealt |= option[j]
        board = start_board
        for j in range(5-num_board):
            board |= deal_card(board | dealt)
        hero = cy_evaluate(board | hand, 7)
        count_addition = 2
        for 0 <= j < num_villain:
            villain[j] = cy_evaluate(board | option[j], 7)
            if hero < villain[j]:
                count_addition = 0
            elif hero == villain[j]:
                count_addition = 1
        count += count_addition
    free(villain)
    free(option)
    return 0.5 * <cython.double>count / <cython.double>iterations

def py_hand_vs_multi_range_monte_carlo(py_hand, py_villain, py_board, py_iterations):
    cdef cython.ulonglong hand = cards_to_mask(py_hand)
    cdef cython.int num_villain = len(py_villain)
    cdef cython.int *num_options = <cython.int*>malloc(sizeof(cython.int)*num_villain)
    cdef cython.int max_length = max([len(each) for each in py_villain])
    
    # Array of lengths
    for i in range(0, len(py_villain)):
        num_options[i] = len(py_villain[i])
    
    # Making array of options
    cdef cython.ulonglong ** options = <cython.ulonglong**>malloc(
            sizeof(cython.ulonglong*)*max_length)
    for i in range(0, num_villain):
        options[i] = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*max_length)
        
    for i in range(0, len(py_villain)):
        for j in range(0, len(py_villain[i])):
            options[i][j] = cards_to_mask(py_villain[i][j][0])

    cdef cython.ulonglong start_board = cards_to_mask(py_board)
    cdef cython.int num_board = len(py_board)
    cdef cython.int iterations = py_iterations
    cdef cython.float equity  # DuplicatedSignature
    cdef cython.ulonglong mask
    equity = hand_vs_multi_range_monte_carlo(hand, options, num_options, num_villain, start_board, num_board, iterations)
    free(options)
    free(num_options)
    return equity
	
cdef cython.float hand_vs_range_exact(cython.ulonglong hand, 
        cython.ulonglong *options, 
        cython.int num_options, 
        cython.ulonglong complete_board):
    # I think it might be okay (good) not to randomly sample options, but
    # instead to evenly sample them. (Still with a randomly sampled board, of
    # course.) This'll make the results converge faster. We can only do this
    # because we know that every option is equally likely (unlike, for example,
    # range vs. range equity calculation).
    cdef cython.uint wins = 0
    cdef cython.uint ties = 0
    cdef cython.ulonglong option  # @DuplicatedSignature
    cdef cython.uint hero = cy_evaluate(complete_board | hand, 7)
    cdef cython.uint villain  # @DuplicatedSignature
    for i in range(num_options):
        # choose an option for opponent's hand
        option = options[i]
        villain = cy_evaluate(complete_board | option, 7)
        if hero > villain:
            wins += 1
        elif hero == villain:
            ties += 1
    return (wins + 0.5 * ties) / <cython.double>num_options


def py_hand_vs_range_exact(py_hand, py_villain, py_board):
    cdef cython.ulonglong hand = cards_to_mask(py_hand)  # @DuplicatedSignature
    cdef cython.int num_options = len(py_villain)  # @DuplicatedSignature
    cdef cython.ulonglong *options = <cython.ulonglong*>malloc(
            sizeof(cython.ulonglong) * num_options)  # @DuplicatedSignature
    cdef cython.ulonglong complete_board = cards_to_mask(py_board)
    cdef cython.float equity
    cdef cython.ulonglong mask  # @DuplicatedSignature
    cdef cython.ulonglong dead = complete_board | hand  
    for index, option in enumerate(py_villain):
        options[index] = cards_to_mask(option[0])
        # This strips and ignores the weight
    num_options = filter_options(options, options, num_options, 
            complete_board | hand)
    equity = hand_vs_range_exact(hand, options, num_options, complete_board)
    free(options)
    return equity


cdef void all_hands_vs_range(cython.ulonglong *hands, 
        cython.uint num_hands,
        cython.ulonglong *all_options, 
        cython.uint num_options,
        cython.ulonglong board, 
        cython.uint num_board,
        cython.long iterations, 
        cython.float *result):
    """
    Return equity of each hand, versus range.
    Note that only unweighted ranges are supported.
    Note that only heads-up evaluations are supported.
    
    hands are two-card hand mask; num_hands is how many
    options is an array of num_options options for opponent's two-card hand
    board is a hand mask of the board; num_board says how many cards are in it
    iterations is iterations to perform
    result is a preallocated array in which to put results (order corresponds
        to order of hands)
    """
    cdef cython.float equity  # @DuplicatedSignature
    cdef cython.ulonglong hand
    cdef cython.uint current_num_options
    cdef cython.ulonglong *options = <cython.ulonglong *>malloc(
            sizeof(cython.ulonglong) * num_options)
    for 0 <= i < num_hands:
        hand = hands[i]
        # Have to do card removal effects at this point - on a hand by hand basis.
        current_num_options = filter_options(all_options, options, 
                num_options, board | hand)
        if current_num_options == 0:
            result[i] = -1  # Villain's range makes this hand impossible for hero.
            continue
        if num_board == 5 and current_num_options <= iterations:
            equity = hand_vs_range_exact(hand, options, current_num_options, 
                    board)
        else:
            equity = hand_vs_range_monte_carlo(hand, options, 
                    current_num_options, board, num_board, iterations)
        result[i] = equity
    free(options)
        

def py_all_hands_vs_range(py_hero, py_villain, py_board, py_iterations):
    """
    Return dict mapping hero's hand to equity against villain's range on this board.
    
    hero and villain are ranges.
    board is a list of cards.
    
    TODO: consider randomising the order of opponent's hands at this point
    so that the evenly distributed sampling in hand_vs_range is unbiased.

    Board pre-filtering has been disabled. This is inefficient, and will 
    be addressed by a planned refactoring.
    """
    cdef cython.ulonglong *hands = <cython.ulonglong *>malloc(
            sizeof(cython.ulonglong) * len(py_hero))
    cdef cython.uint num_hands
    cdef cython.ulonglong *options = <cython.ulonglong *>malloc(
            sizeof(cython.ulonglong) * len(py_villain))
    cdef cython.uint num_options
    cdef cython.ulonglong board  # @DuplicatedSignature
    cdef cython.uint num_board
    cdef cython.long iterations = <cython.long>py_iterations
    cdef cython.float *result = <cython.float *>malloc(
            sizeof(cython.float) * len(py_hero))
   
    num_hands = 0
    for hand, weight in py_hero:
        hands[num_hands] = cards_to_mask(hand)
        num_hands += 1
        
    num_options = 0
    for option, weight in py_villain:
        options[num_options] = cards_to_mask(option)
        num_options += 1
        
    board = cards_to_mask(py_board)
    num_board = len(py_board)

    all_hands_vs_range(hands, num_hands, options, num_options, board, 
            num_board, iterations, result)
    
    py_result = {}
    for i, (hand, weight) in enumerate(py_hero):
        if result[i] != -1:
            py_result[hand] = result[i]
    free(hands)
    free(options)
    free(result)
    
    return py_result

cdef void all_hands_vs_multi_range(cython.ulonglong *hero, 
        cython.int num_hero,
        cython.ulonglong **villain, 
        cython.int num_villain,
        cython.int *iter_num_villain,
        cython.ulonglong board, 
        cython.int num_board,
        cython.int iterations, 
        cython.float *result):
    """
    Return equity of each hand, versus range.
    Note that only unweighted ranges are supported.
    Note that only heads-up evaluations are supported.
    
    hands are two-card hand mask; num_hands is how many
    options is an array of num_options options for opponent's two-card hand
    board is a hand mask of the board; num_board says how many cards are in it
    iterations is iterations to perform
    result is a preallocated array in which to put results (order corresponds
        to order of hands)
    """
    cdef cython.float equity  # @DuplicatedSignature
    cdef cython.ulonglong hand
    cdef cython.uint current_num_options
    for 0<= i < num_hero:
        hand = hero[i]
        equity = hand_vs_multi_range_monte_carlo(hand, villain, iter_num_villain, num_villain, board, num_board, iterations)
        result[i] = equity

    

def py_all_hands_vs_multi_range(py_hero, py_villain, py_board, py_iterations):
    cdef cython.int num_hero = len(py_hero)
    cdef cython.ulonglong *hero = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*num_hero)
    for 0 <= i < num_hero:
        hero[i] = cards_to_mask(py_hero[i][0])
    
    # Creating villain hands
    cdef cython.int num_villain = len(py_villain)
    cdef cython.int *iter_num_villain = <cython.int*>malloc(sizeof(cython.int)*num_villain)
    cdef cython.uint max_length_villain = max([len(each) for each in py_villain])
    cdef cython.ulonglong **villain = <cython.ulonglong**>malloc(sizeof(cython.ulonglong*)*num_villain)
    for 0 <= i < num_villain:
        villain[i] = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*max_length_villain)
        iter_num_villain[i] = len(py_villain[i])
        for j in range(0, len(py_villain[i])):
            villain[i][j] = cards_to_mask(py_villain[i][j][0])
    
    # Creating board
    cdef cython.ulonglong board = cards_to_mask(py_board)
    cdef cython.uint num_board = len(py_board)
    
    # Creating iterations and result holder
    cdef cython.int iterations = py_iterations
    cdef cython.float *result = <cython.float*>malloc(sizeof(cython.float)*num_hero)
    
    # Launching the C code to get the result
    all_hands_vs_multi_range(hero, num_hero, villain, num_villain, iter_num_villain, board, 
            num_board, iterations, result)
            
    py_result = []
    
    for i, (hand, weight) in enumerate(py_hero):
        py_result.append([hand, result[i]])
    
    free(hero)
    free(villain)
    free(result)
    free(iter_num_villain)
    return py_result

cdef cython.float ev_hand_vs_multirange(
        cython.ulonglong hero,
        cython.float hero_bet,
        cython.int num_villain_old,
        cython.int num_villain_new,
        cython.int *iter_villain_old,
        cython.int *iter_villain_new,
        cython.ulonglong **villain_old,
        cython.ulonglong **villain_new,
        cython.float *players_bets,
        cython.ulonglong start_board,
        cython.int num_board,
        cython.float rake,
        cython.int iterations,
        cython.float pot,
        cython.float bet
        ):
    """
    Method to get the ev of certain bet if we know the starting ranges
    and the final ranges of people on the board
    """
    cdef cython.int hero_won
    cdef cython.float expected_value_result
    cdef cython.float count_addition
    cdef cython.ulonglong *option = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*num_villain_old)
    cdef cython.ulonglong *villain = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*num_villain_old)
    cdef cython.ulonglong dealt
    cdef cython.ulonglong board
    cdef cython.int ran_gen
    cdef cython.uint hero_score
    cdef cython.uint villain_score
    cdef cython.float current_pot
    cdef cython.int participants_counter
    cdef cython.int total_participants
    expected_value_result = 0
    for 0 <= i < iterations:
        current_pot = pot + bet
        dealt = hero
        total_participants = 0
        hero_won = 1
        for 0 <= j < num_villain_old:
            current_pot += players_bets[j]
            ran_gen = wh_randint(iter_villain_old[j])
            if ran_gen < iter_villain_new[j]:
                total_participants += 1
                villain[j] = villain_new[j][ran_gen]
                dealt |= villain[j]
                current_pot += bet-players_bets[j]
            else:
                villain[j] = 0
        board = start_board
        for j in range(5-num_board):
            board |= deal_card(board | dealt)
        hero_score = cy_evaluate(board | hero, 7)
        count_addition = current_pot- bet+hero_bet
        participants_counter = 1
        for 0 <= j < num_villain_old:
            if villain[j] == 0:
                continue
            else:
                participants_counter += 1
                villain_score = cy_evaluate(board | villain[j], 7)
                if hero_score < villain_score:
                    count_addition = -bet+hero_bet
                    hero_won = 0
                    break
                elif hero_score == villain_score:
                    count_addition = current_pot/participants_counter-bet+hero_bet
        if hero_won == 1:
            count_addition *= 1-rake
        expected_value_result += count_addition 
    free(villain)
    free(option)
    return expected_value_result/iterations

def py_ev_hand_vs_multi_range(py_pot, py_bet_size, py_hero, py_hero_bet, py_villain_old, py_villain_new, py_players_bets, py_board, py_rake, py_iterations):
    assert len(py_villain_old)==len(py_villain_new) and len(py_villain_new) == len(py_players_bets)
    cdef cython.ulonglong hero = cards_to_mask(py_hero)
    cdef cython.int num_villain_old = len(py_villain_old)
    cdef cython.int num_villain_new = len(py_villain_new)
    cdef cython.int max_length_villain_old = max([len(each) for each in py_villain_old])
    cdef cython.int max_length_villain_new = max([len(each) for each in py_villain_new])
    cdef cython.int *iter_villain_old = <cython.int*>malloc(sizeof(cython.int)*num_villain_old)
    cdef cython.int *iter_villain_new = <cython.int*>malloc(sizeof(cython.int)*num_villain_new)
    cdef cython.float rake = py_rake
    cdef cython.ulonglong **villain_old = <cython.ulonglong**>malloc(sizeof(cython.ulonglong*)*num_villain_old)
    for 0<=i<num_villain_old:
        villain_old[i] = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*max_length_villain_old)
        iter_villain_old[i] = len(py_villain_old[i])
        for j in range(0, len(py_villain_old[i])):
            villain_old[i][j] = cards_to_mask(py_villain_old[i][j][0])
    cdef cython.ulonglong **villain_new = <cython.ulonglong**>malloc(sizeof(cython.ulonglong*)*num_villain_new)
    for 0<=i<num_villain_new:
        villain_new[i] = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*max_length_villain_new)
        iter_villain_new[i] = len(py_villain_new[i])
        for j in range(0, len(py_villain_new[i])):
            villain_new[i][j] = cards_to_mask(py_villain_new[i][j][0])
    cdef cython.ulonglong board = cards_to_mask(py_board)
    cdef cython.int iterations = py_iterations
    cdef cython.int num_board = len(py_board)
    cdef cython.float pot = py_pot
    cdef cython.float bet = py_bet_size
    cdef cython.float hero_bet = py_hero_bet
    cdef cython.float *players_bets = <cython.float*>malloc(sizeof(cython.float)*len(py_players_bets))
    for 0 <= i < len(py_players_bets):
        players_bets[i] = py_players_bets[i]
    
    result_ev = ev_hand_vs_multirange(
        hero, 
        hero_bet,
        num_villain_old,
        num_villain_new,
        iter_villain_old,
        iter_villain_new,
        villain_old,
        villain_new,
        players_bets,
        board,
        num_board,
        rake,
        iterations,
        pot,
        bet
    )
    
    free(iter_villain_old)
    free(iter_villain_new)
    free(villain_old)
    free(villain_new)
    free(players_bets)
    return result_ev

cdef cython.float ev_hand_vs_multirange_proba(
        cython.ulonglong hero,
        cython.float hero_bet,
        cython.int num_villain,
        cython.int *iter_villain,
        cython.ulonglong **villain_input,
        cython.int *proba,
        cython.float *players_bets,
        cython.ulonglong start_board,
        cython.int num_board,
        cython.int iterations,
        cython.float pot,
        cython.float bet
        ):
    """
    Method to get the ev of certain bet if we know the starting ranges
    and the final ranges of people on the board
    """
    cdef cython.float expected_value_result
    cdef cython.float count_addition
    cdef cython.ulonglong *villain = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*num_villain)
    cdef cython.ulonglong dealt
    cdef cython.ulonglong board
    cdef cython.int ran_gen
    cdef cython.uint hero_score
    cdef cython.uint villain_score
    cdef cython.float current_pot
    cdef cython.int participants_counter
    cdef cython.int total_participants
    
    for 0 <= i < iterations:
        current_pot = pot + bet
        dealt = hero
        total_participants = 0
        for 0 <= j < num_villain:
            current_pot += players_bets[j]
            ran_gen = wh_randint(100)
            if ran_gen <= proba[j]:
                total_participants += 1
                villain[j] = villain_input[j][wh_randint(iter_villain[j])]
                dealt |= villain[j]
                current_pot += bet-players_bets[j]
            else:
                villain[j] = 0
        board = start_board
        for j in range(5-num_board):
            board |= deal_card(board | dealt)
        hero_score = cy_evaluate(board | hero, 7)
        count_addition = current_pot- bet+hero_bet
        participants_counter = 1
        for 0 <= j < num_villain:
            if villain[j] == 0:
                continue
            participants_counter += 1
            villain_score = cy_evaluate(board | villain[j], 7)
            if hero_score < villain_score:
                count_addition = -bet+hero_bet
                break
            elif hero_score == villain_score:
                count_addition = current_pot/participants_counter-bet+hero_bet
        expected_value_result += count_addition
    free(villain)

    return expected_value_result/iterations

def py_ev_hand_vs_multi_range_proba(py_pot, py_bet_size, py_hero, py_hero_bet, py_villain, py_proba, py_players_current_bets, py_board, py_iterations):
    assert len(py_villain) == len(py_proba) and len(py_proba) == len(py_players_current_bets)
    cdef cython.ulonglong hero = cards_to_mask(py_hero)
    cdef cython.int num_villain = len(py_villain)
    cdef cython.int max_length_villain = max([len(each) for each in py_villain])
    cdef cython.int *iter_villain = <cython.int*>malloc(sizeof(cython.int)*num_villain)
    cdef cython.ulonglong **villain = <cython.ulonglong**>malloc(sizeof(cython.ulonglong*)*num_villain)
    for 0<=i<num_villain:
        villain[i] = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*max_length_villain)
        iter_villain[i] = len(py_villain[i])
        for j in range(0, len(py_villain[i])):
            villain[i][j] = cards_to_mask(py_villain[i][j][0])
    cdef cython.ulonglong board = cards_to_mask(py_board)
    cdef cython.int iterations = py_iterations
    cdef cython.int num_board = len(py_board)
    cdef cython.float pot = py_pot
    cdef cython.float bet = py_bet_size
    cdef cython.float hero_bet = py_hero_bet
    cdef cython.float *players_bets = <cython.float*>malloc(sizeof(cython.float)*len(py_players_current_bets))
    for 0 <= i < len(py_players_current_bets):
        players_bets[i] = py_players_current_bets[i]
    cdef cython.int *proba = <cython.int*>malloc(sizeof(cython.int)*len(py_proba))
    for 0 <= i < len(py_villain):
        proba[i] = round(py_proba[i]*100)
    
    result_ev = ev_hand_vs_multirange_proba(
        hero, 
        hero_bet,
        num_villain,
        iter_villain,
        villain,
        proba,
        players_bets,
        board,
        num_board,
        iterations,
        pot,
        bet
    )
    
    free(iter_villain)
    free(villain)
    free(proba)
    free(players_bets)
    return result_ev

cdef cython.float range_vs_multi_range_monte_carlo(cython.ulonglong* hero,
		cython.int num_hero,
        cython.ulonglong **options, 
        cython.int *num_options,
        cython.int num_villain,
        cython.ulonglong start_board, 
        cython.int num_board, 
        cython.int iterations):
    #print("Doing simulation itself")
    cdef cython.uint count = 0
    cdef cython.uint count_addition
    cdef cython.ulonglong *option = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*num_villain)
    cdef cython.ulonglong dealt
    cdef cython.ulonglong hero_hand
    cdef cython.uint hero_score
    cdef cython.uint *villain = <cython.uint*>malloc(sizeof(cython.uint)*num_villain)
    cdef cython.ulonglong board
    for 0 <= i < iterations:
        #print("Iteration:", i)
        hero_hand = hero[wh_randint(num_hero)]
        dealt = hero_hand
        for 0 <= j < num_villain:
            option[j] = options[j][wh_randint(num_options[j])]
            dealt |= option[j]
        board = start_board
        for j in range(5-num_board):
            board |= deal_card(board | dealt)
        hero_score = cy_evaluate(board | hero_hand, 7)
        count_addition = 2
        for 0 <= j < num_villain:
            villain[j] = cy_evaluate(board | option[j], 7)
            if hero_score < villain[j]:
                count_addition = 0
            elif hero_score == villain[j]:
                count_addition = 1
        count += count_addition
    free(villain)
    free(option)
    return 0.5 * <cython.double>count / <cython.double>iterations

def py_range_vs_multi_range_monte_carlo(py_hero, py_villain, py_board, py_iterations):
    cdef cython.int len_hero = len(py_hero)
    cdef cython.ulonglong* hero = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*len_hero)
    for i in range(0, len(py_hero)):
        hero[i] = cards_to_mask(py_hero[i][0])
    
    cdef cython.int num_villain = len(py_villain)
    cdef cython.int *num_options = <cython.int*>malloc(sizeof(cython.int)*num_villain)
    cdef cython.int max_length = max([len(each) for each in py_villain])
    
    # Array of lengths
    for i in range(0, len(py_villain)):
        num_options[i] = len(py_villain[i])
        #print(num_options[i], len(py_villain[i]))
    
    # Making array of options
    cdef cython.ulonglong ** options = <cython.ulonglong**>malloc(
            sizeof(cython.ulonglong*)*max_length)
    for i in range(0, num_villain):
        options[i] = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*num_options[i])
        
    for i in range(0, len(py_villain)):
        for j in range(0, len(py_villain[i])):
            options[i][j] = cards_to_mask(py_villain[i][j][0])

    cdef cython.ulonglong start_board = cards_to_mask(py_board)
    cdef cython.int num_board = len(py_board)
    cdef cython.int iterations = py_iterations
    cdef cython.float equity  # DuplicatedSignature
    cdef cython.ulonglong mask
    #print("Villain ranges:", len(py_villain))
    #print("Hero ranges:", len(py_hero))
    equity = range_vs_multi_range_monte_carlo(hero, len_hero, options, num_options, num_villain, start_board, num_board, iterations)
    free(options)
    free(num_options)
    free(hero)
    return equity

#####################################################################
#################### Range EV Calculations ##########################
#####################################################################

cdef cython.float ev_range_vs_multirange(
		cython.int num_hero,
        cython.ulonglong *hero,
        cython.float hero_bet,
        cython.int num_villain_old,
        cython.int num_villain_new,
        cython.int *iter_villain_old,
        cython.int *iter_villain_new,
        cython.ulonglong **villain_old,
        cython.ulonglong **villain_new,
        cython.float *players_bets,
        cython.ulonglong start_board,
        cython.int num_board,
        cython.int iterations,
        cython.float pot,
        cython.float bet,
        cython.float rake
        ):
    """
    Method to get the ev of certain bet if we know the starting ranges
    and the final ranges of people on the board
    """
    cdef cython.float expected_value_result = 0
    cdef cython.float count_addition
    cdef cython.ulonglong *option = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*num_villain_old)
    cdef cython.ulonglong *villain = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*num_villain_old)
    cdef cython.ulonglong dealt
    cdef cython.ulonglong board
    cdef cython.int ran_gen
    cdef cython.uint hero_score
    cdef cython.uint villain_score
    cdef cython.float current_pot
    cdef cython.int participants_counter
    cdef cython.int total_participants
    cdef cython.ulonglong hero_hand
    cdef cython.int hero_won
    for 0 <= i < iterations:
        current_pot = pot + bet
        hero_hand = hero[wh_randint(num_hero)]
        dealt = hero_hand
        total_participants = 0
        hero_won = 1
        for 0 <= j < num_villain_old:
            current_pot += players_bets[j]
            ran_gen = wh_randint(iter_villain_old[j])
            if ran_gen < iter_villain_new[j]:
                total_participants += 1
                villain[j] = villain_new[j][ran_gen]
                dealt |= villain[j]
                current_pot += bet-players_bets[j]
            else:
                villain[j] = 0
        board = start_board
        for j in range(5-num_board):
            board |= deal_card(board | dealt)
        hero_score = cy_evaluate(board | hero_hand, 7)
        count_addition = current_pot- bet+hero_bet
        participants_counter = 1
        for 0 <= j < num_villain_old:
            if villain[j] == 0:
                continue
            else:
                participants_counter += 1
                villain_score = cy_evaluate(board | villain[j], 7)
                if hero_score < villain_score:
                    count_addition = -bet+hero_bet
                    hero_won = 0
                    break
                elif hero_score == villain_score:
                    count_addition = current_pot/participants_counter-bet+hero_bet
        if hero_won:
            count_addition *= (1-rake)
        expected_value_result += count_addition
    free(villain)
    free(option)
    return expected_value_result/iterations

def py_ev_range_vs_multi_range(py_pot, py_bet_size, py_hero, py_hero_bet, py_villain_old, py_villain_new, py_players_bets, py_board, py_rake, py_iterations):
    assert len(py_villain_old)==len(py_villain_new) and len(py_villain_new) == len(py_players_bets)
    cdef cython.int num_hero = len(py_hero)
    cdef cython.ulonglong *hero = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*num_hero)
    for 0 <=i <num_hero:
        hero[i] = cards_to_mask(py_hero[i][0])    
    cdef cython.int num_villain_old = len(py_villain_old)
    cdef cython.int num_villain_new = len(py_villain_new)
    cdef cython.int max_length_villain_old = max([len(each) for each in py_villain_old])
    cdef cython.int max_length_villain_new = max([len(each) for each in py_villain_new])
    cdef cython.int *iter_villain_old = <cython.int*>malloc(sizeof(cython.int)*num_villain_old)
    cdef cython.int *iter_villain_new = <cython.int*>malloc(sizeof(cython.int)*num_villain_new)
    cdef cython.ulonglong **villain_old = <cython.ulonglong**>malloc(sizeof(cython.ulonglong*)*num_villain_old)
    for 0<=i<num_villain_old:
        villain_old[i] = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*max_length_villain_old)
        iter_villain_old[i] = len(py_villain_old[i])
        for j in range(0, len(py_villain_old[i])):
            villain_old[i][j] = cards_to_mask(py_villain_old[i][j][0])
    cdef cython.ulonglong **villain_new = <cython.ulonglong**>malloc(sizeof(cython.ulonglong*)*num_villain_new)
    for 0<=i<num_villain_new:
        villain_new[i] = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*max_length_villain_new)
        iter_villain_new[i] = len(py_villain_new[i])
        for j in range(0, len(py_villain_new[i])):
            villain_new[i][j] = cards_to_mask(py_villain_new[i][j][0])
    cdef cython.ulonglong board = cards_to_mask(py_board)
    cdef cython.int iterations = py_iterations
    cdef cython.int num_board = len(py_board)
    cdef cython.float pot = py_pot
    cdef cython.float bet = py_bet_size
    cdef cython.float hero_bet = py_hero_bet
    cdef cython.float *players_bets = <cython.float*>malloc(sizeof(cython.float)*len(py_players_bets))
    cdef cython.float rake = py_rake
    for 0 <= i < len(py_players_bets):
        players_bets[i] = py_players_bets[i]
    #print("Pot size:", pot)
    result_ev = ev_range_vs_multirange(
		num_hero,
        hero, 
        hero_bet,
        num_villain_old,
        num_villain_new,
        iter_villain_old,
        iter_villain_new,
        villain_old,
        villain_new,
        players_bets,
        board,
        num_board,
        iterations,
        pot,
        bet,
        rake
    )
    free(players_bets)
    free(hero)
    free(iter_villain_old)
    free(iter_villain_new)
    free(villain_old)
    free(villain_new)
    return result_ev

###################################################################
## -- Optimal range calculator 

cdef cython.float minimum_range_calculator(
		cython.int num_hero,
        cython.ulonglong *hero,
        cython.float hero_bet,
        cython.int num_villain_old,
        cython.int num_villain_new,
        cython.int *iter_villain_old,
        cython.int *iter_villain_new,
        cython.ulonglong **villain_old,
        cython.ulonglong **villain_new,
        cython.float *players_bets,
        cython.ulonglong start_board,
        cython.int num_board,
        cython.int iterations,
        cython.float pot,
        cython.float bet,
        cython.float rake
        ):
    cdef cython.float count_addition = 0
    cdef cython.ulonglong *option = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*num_villain_old)
    cdef cython.ulonglong *villain = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*num_villain_old)
    cdef cython.ulonglong dealt
    cdef cython.ulonglong board
    cdef cython.int ran_gen
    cdef cython.uint hero_score
    cdef cython.uint villain_score
    cdef cython.float current_pot
    cdef cython.int participants_counter
    cdef cython.int total_participants
    cdef cython.ulonglong hero_hand
    cdef cython.int hero_won
    cdef cython.int evaluation_point 
    cdef cython.float *hands_evs = <cython.float*>malloc(sizeof(cython.float)*num_hero)
    cdef cython.float *integrated_hands_evs = <cython.float*>malloc(sizeof(cython.float)*num_hero)
    cdef cython.float integrated_sum
    cdef cython.int top_one_percent = c_round( num_hero/100 + 1 )
    for 0 <= i < num_hero:
        hands_evs[i] = 0
    
    for 0 <= it < iterations:
        for 0 <= i < num_hero:
            evaluation_point = i%num_hero
            current_pot = pot + bet
            hero_hand = hero[evaluation_point]
            dealt = hero_hand
            total_participants = 0
            hero_won = 1
            for 0 <= j < num_villain_old:
                current_pot += players_bets[j]
                ran_gen = wh_randint(iter_villain_old[j])
                if ran_gen < iter_villain_new[j]:
                    total_participants += 1
                    villain[j] = villain_new[j][ran_gen]
                    dealt |= villain[j]
                    current_pot += bet-players_bets[j]
                else:
                    villain[j] = 0
            board = start_board
            for j in range(5-num_board):
                board |= deal_card(board | dealt)
            hero_score = cy_evaluate(board | hero_hand, 7)
            count_addition = current_pot- bet+hero_bet
            participants_counter = 1
            for 0 <= j < num_villain_old:
                if villain[j] == 0:
                    continue
                else:
                    participants_counter += 1
                    villain_score = cy_evaluate(board | villain[j], 7)
                    if hero_score < villain_score:
                        count_addition = -bet+hero_bet
                        hero_won = 0
                        break   
                    elif hero_score == villain_score:
                        count_addition = current_pot/participants_counter-bet+hero_bet
                        hero_won = 0
            if hero_won:
                count_addition *= (1-rake)
            hands_evs[evaluation_point] += count_addition
			# ------- FINISH -------
    
    
    # -- Integrating hands_evs
    for 0 <= i < num_hero:
        integrated_sum = 0
        for 0 <= j < i:
            integrated_sum += hands_evs[j]
        integrated_hands_evs[i] = integrated_sum
    
    
    # -- Finding top value
    current_pot = 0
    count_addition = 0
    
    for 0 <= i < num_hero:
        if integrated_hands_evs[i] > current_pot:
            current_pot = integrated_hands_evs[i]
            count_addition = i
            
    free(hands_evs)
    free(integrated_hands_evs)
    free(villain)
    free(option)
    return count_addition/num_hero

def py_minimum_range_calculator(py_pot, py_bet_size, py_hero, py_hero_bet, py_villain_old, py_villain_new, py_players_bets, py_board, py_rake, py_iterations):
    assert len(py_villain_old)==len(py_villain_new) and len(py_villain_new) == len(py_players_bets)
    cdef cython.int num_hero = len(py_hero)
    cdef cython.ulonglong *hero = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*num_hero)
    for 0 <=i <num_hero:
        hero[i] = cards_to_mask(py_hero[i][0])    
    cdef cython.int num_villain_old = len(py_villain_old)
    cdef cython.int num_villain_new = len(py_villain_new)
    cdef cython.int max_length_villain_old = max([len(each) for each in py_villain_old])
    cdef cython.int max_length_villain_new = max([len(each) for each in py_villain_new])
    cdef cython.int *iter_villain_old = <cython.int*>malloc(sizeof(cython.int)*num_villain_old)
    cdef cython.int *iter_villain_new = <cython.int*>malloc(sizeof(cython.int)*num_villain_new)
    cdef cython.ulonglong **villain_old = <cython.ulonglong**>malloc(sizeof(cython.ulonglong*)*num_villain_old)
    for 0<=i<num_villain_old:
        villain_old[i] = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*max_length_villain_old)
        iter_villain_old[i] = len(py_villain_old[i])
        for j in range(0, len(py_villain_old[i])):
            villain_old[i][j] = cards_to_mask(py_villain_old[i][j][0])
    cdef cython.ulonglong **villain_new = <cython.ulonglong**>malloc(sizeof(cython.ulonglong*)*num_villain_new)
    for 0<=i<num_villain_new:
        villain_new[i] = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*max_length_villain_new)
        iter_villain_new[i] = len(py_villain_new[i])
        for j in range(0, len(py_villain_new[i])):
            villain_new[i][j] = cards_to_mask(py_villain_new[i][j][0])
    cdef cython.ulonglong board = cards_to_mask(py_board)
    cdef cython.int iterations = py_iterations
    cdef cython.int num_board = len(py_board)
    cdef cython.float pot = py_pot
    cdef cython.float bet = py_bet_size
    cdef cython.float hero_bet = py_hero_bet
    cdef cython.float *players_bets = <cython.float*>malloc(sizeof(cython.float)*len(py_players_bets))
    cdef cython.float rake = py_rake
    for 0 <= i < len(py_players_bets):
        players_bets[i] = py_players_bets[i]
    result_ev = minimum_range_calculator(
		num_hero,
        hero, 
        hero_bet,
        num_villain_old,
        num_villain_new,
        iter_villain_old,
        iter_villain_new,
        villain_old,
        villain_new,
        players_bets,
        board,
        num_board,
        iterations,
        pot,
        bet,
        rake
    )
    free(players_bets)
    free(hero)
    free(iter_villain_old)
    free(iter_villain_new)
    free(villain_old)
    free(villain_new)
    
    return result_ev



##################################################################
# -- My Own Functions Start Here

cdef cython.float* optimal_ranges_calculator(
		cython.float pot,
	    cython.float current_bet,
	    cython.int num_ranges,
	    cython.int *num_num_ranges,
	    cython.ulonglong **ranges,
	    cython.int *adjust_ranges,
	    cython.float *bets,
	    cython.ulonglong board,
        cython.int num_board,
	    cython.float rake,
	    cython.int iterations,
	    cython.int rounds,
		):
    cdef cython.int *current_ranges = <cython.int*>malloc(sizeof(cython.int)*num_ranges)
    cdef cython.int player_id
    cdef cython.float current_pot = 0
    cdef cython.float winnings = 0
    cdef cython.float integrated_sum = 0
    cdef cython.float **evs = <cython.float**>malloc(sizeof(cython.float*)*num_ranges)
    cdef cython.float **integrated_evs = <cython.float**>malloc(sizeof(cython.float*)*num_ranges)
    cdef cython.ulonglong *options = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*num_ranges)
    cdef cython.ulonglong dealt = 0
    cdef cython.int ran_gen = 0
    cdef cython.int hero_won = 1
    cdef cython.int num_participants = 0
    cdef cython.ulonglong current_board = 0
    cdef cython.uint hero_score = 0
    cdef cython.uint villain_score = 0
    cdef cython.int *min_ranges = <cython.int*>malloc(sizeof(cython.int)*3)
    cdef cython.int second_min_range = num_num_ranges[0]
    cdef cython.int current_min_range = num_num_ranges[0]
    cdef cython.float *array_of_candidates = <cython.float*>malloc(sizeof(cython.float)*rounds)
    cdef cython.int candidates_counter = 0
    cdef cython.float sum_of_candidates = 0
    
    min_ranges[0] = num_num_ranges[0]
    min_ranges[1] = num_num_ranges[0]
    min_ranges[2] = num_num_ranges[0]
    for 0 <= i < num_ranges:
        evs[i] = <cython.float*>malloc(sizeof(cython.float)*num_num_ranges[i])
        integrated_evs[i] = <cython.float*>malloc(sizeof(cython.float)*num_num_ranges[i])
        current_ranges[i] = num_num_ranges[i]
    
    for 0 <= i < rounds:
        array_of_candidates[i] = 0
    
    for 0 <= i < rounds:
        for 0 <= j < num_ranges:
            player_id = (j+1)%num_ranges
            if not adjust_ranges[player_id]:
                continue
            for 0 <= k < num_num_ranges[player_id]:
                evs[player_id][k] = 0
                
            for 0 <= k < iterations:
                for 0 <= card < num_num_ranges[player_id]:
                    current_pot = pot
                    hero_won = 1
                    dealt = 0
                    # -- Dealing cards function
                    for 0 <= b < num_ranges:
                        if b == player_id:
                            options[b] = ranges[b][card]
                            current_pot += current_bet - bets[b]
                            dealt |= options[b]
                            continue
                        current_pot += bets[b]
                        ran_gen = wh_randint(num_num_ranges[b])
                        if ran_gen < current_ranges[b]:
                            options[b] = ranges[b][ran_gen]
                            dealt |= options[b]
                            current_pot += current_bet - bets[b]
                        else:
                            options[b] = 0
                            
                    # -- Dealing the board
                    current_board = board
                    for l in range(5-num_board):
                        current_board |= deal_card(board | dealt)
                    
                    # -- Setting current winnings
                    hero_score = cy_evaluate(options[player_id] | current_board, 7)
                    winnings = current_pot - current_bet + bets[player_id]
                    num_participants = 1
                    for 0 <= b < num_ranges:
                        if options[b] == 0 or b == player_id:
                            continue
                        else:
                            num_participants += 1
                            villain_score = cy_evaluate(options[b] | current_board, 7)
                            if hero_score < villain_score:
                                hero_won = 0
                                winnings = bets[player_id] - current_bet
                                break
                            elif hero_score == villain_score:
                                winnings = current_pot/num_participants - current_bet + bets[player_id]
                    if hero_won == 1:
                        winnings *= (1-rake)
                        
                    evs[player_id][card] += winnings
                    #print("Winnings:", winnings, card)
            
            
            
            # -- Integrating evs
            for 0 <= k < num_num_ranges[player_id]:
                integrated_sum = 0
                for 0 <= l < k:
                    integrated_sum += evs[player_id][l]
                integrated_evs[player_id][k] = integrated_sum  
                
            
            if player_id == 0:
                min_ranges[0] = min_ranges[1]
                min_ranges[1] = min_ranges[2]
                min_ranges[2] = current_ranges[player_id]
                if min_ranges[2] > min_ranges[1] and min_ranges[1] < min_ranges[0]:
                    # -- Candidate
                    array_of_candidates[candidates_counter] = min_ranges[1]
                    sum_of_candidates += min_ranges[0]
                    candidates_counter += 1
                    current_min_range = min_ranges[0]  
                #print("Current min_range:", current_min_range)
            
            # -- Finding the maximum
            
            current_pot = 0
            current_ranges[player_id] = 0
            for 0 <= k < num_num_ranges[player_id]:
                if integrated_evs[player_id][k] > current_pot:
                    current_pot = integrated_evs[player_id][k]
                    current_ranges[player_id] = k
            #print("Player number:", player_id, " New range:", current_ranges[player_id], "/", num_num_ranges[player_id])
    #print("Average good range:", sum_of_candidates/candidates_counter)
    free(current_ranges)
    free(options)
    free(evs)
    free(integrated_evs)
    return array_of_candidates

def py_optimal_ranges_calculator(py_pot, py_bet_size, py_ranges, py_bets, py_board, py_rake, py_iterations, py_rounds):
    # -- #1 is the hero on the table
    cdef cython.int num_ranges = len(py_ranges)
    cdef cython.int iterations = py_iterations
    cdef cython.int rounds = py_rounds
    cdef cython.int num_board = len(py_board)
    cdef cython.int *num_num_ranges = <cython.int*>malloc(sizeof(cython.int)*num_ranges)
    cdef cython.int *adjust_ranges = <cython.int*>malloc(sizeof(cython.int)*num_ranges)
    cdef cython.ulonglong **ranges = <cython.ulonglong**>malloc(sizeof(cython.ulonglong*)*num_ranges)
    cdef cython.float pot = py_pot
    cdef cython.float current_bet = py_bet_size
    cdef cython.float rake = py_rake
    cdef cython.float *bets = <cython.float*>malloc(sizeof(cython.float)*num_ranges)
    cdef cython.ulonglong board = cards_to_mask(py_board)
    for 0 <= i < num_ranges:
        num_num_ranges[i] = len(py_ranges[i])
        ranges[i] = <cython.ulonglong*>malloc(sizeof(cython.ulonglong)*num_num_ranges[i])
        bets[i] = py_bets[i]
        for 0 <=j < num_num_ranges[i]:
            ranges[i][j] = cards_to_mask(py_ranges[i][j][0])
        if bets[i] == current_bet:
            adjust_ranges[i] = 0
        else:
            adjust_ranges[i] = 1
    
    result = optimal_ranges_calculator(
            pot, current_bet, num_ranges, num_num_ranges, ranges, adjust_ranges, bets, board, num_board, rake, iterations, rounds
        )
    
    free(bets)
    free(num_num_ranges)
    free(ranges)
    free(adjust_ranges)
    res = []
    for i in range(0, py_rounds):
        if result[i] == 0:
            break
        res.append(result[i])
    
    return res

def py_cards_to_mask(py_cards):
    return cards_to_mask(py_cards)
