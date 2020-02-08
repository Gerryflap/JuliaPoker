"""
# module Poker

- Julia version: 1.3.1
- Author: gerben
- Date: 2020-02-08

# Examples

This module defines GameState for Poker. The GameState is immutable.
Every mutation of the GameState returns a new, edited, GameState.

```jldoctest
julia>
```
"""
module Poker
    include("Cards.jl")
    import StatsBase
    using Setfield

    # ================================= State Model ========================================

    struct GameState
        n_players::Int                  # Amount of total players
        playing_round::Array{Bool}      # Array with a boolean for each player that indicates whether they haven't folded yet (and thus can still bet)
        money_in_pot::Array{Int}        # Array with the amount of money in the pot
        money::Array{Int}               # Array with the amount of money the players still have
        cards::Array{Cards.Card}        # Array containing the cards in each players hand, dimensions: N_players x 2
        river::Array{Cards.Card}        # Array containing the cards in the river
        current_player::Int             # Int pointing to the current player (1..N)
        last_raise::Int                 # Points at the last player who raised, or 0 for no raise yet...
        big_blind::Int                  # Position of the big blind
        big_blind_amount::Int           # Amount of money the big blind has to pay
    end

    # Actions
    @enum SimpleAction fold check all_in

    struct RaiseAction
        amount:: Int
    end

    Action = Union{SimpleAction, RaiseAction}

    # ========================== State transitions and helper functions ==========================
    function gen_hands_and_river(n_players::Int)
        # Returns a tuple of cards and river variables for the gamestate struct
        total_cards_sampled = n_players * 2 + 5
        cards = StatsBase.sample(Cards.all_cards, total_cards_sampled; replace=false)
        river = cards[1:5]
        hand_cards = reshape(cards[6:end], (n_players, 2))
        return cards, river
    end

    function hide_river(river::Array{Cards.Card})
        riv4 = river[4]
        riv5 = river[5]
        river[4] = @set riv4.hidden = true
        river[5] = @set riv5.hidden = true
    end

    function start_game(n_players::Int, starting_money::Int=1000) :: GameState
            # Returns an initial gamestate with drawn cards for N players
            cards, river = gen_hands_and_river(n_players)
            hide_river(river)
            blind_pos = StatsBase.sample(1:n_players)
            state = GameState(
                n_players,
                [true for _ in 1:n_players],
                [0 for _ in 1:n_players],
                [starting_money for _ in 1:n_players],
                cards,
                river,
                1 + (blind_pos + 1)%n_players,
                0,
                blind_pos,
                10
            )
            state = play_blinds(state)
            return state
    end

    function pay_to_pot(state::GameState, player_index::Int, amount::Int) :: GameState
        state = @set state.money[player_index] -= amount
        state = @set state.money_in_pot[player_index] += amount
        return state
    end


    function play_blinds(state::GameState) :: GameState
        big_blind = state.big_blind
        small_blind = 1 + (state.big_blind - 1)%state.n_players
        state = pay_to_pot(state, big_blind, state.big_blind_amount)
        state = pay_to_pot(state, small_blind, div(state.big_blind_amount, 2))
        return state
    end


#     function new_round(state::GameState) :: GameState
#         # TODO: fix
#         cards, river = gen_hands_and_river(n_players)
#         hide_river(river)
#         state = @set state.big_blind = 1 + (state.big_blind + 1)%n_players
#         state = @set state.current_player = 1 + (state.big_blind + 1)%n_players
#         state = @set state.river = river
#         state = @set state.cards = cards
#         state = @set state.playing_round = [true for _ in 1:n_players],
#                 [0 for _ in 1:n_players],
#         state = play_blinds(state)
#         return state
#     end
#
#
#
#
#     function transition(from_state::GameState)



    export GameState, start_game
end