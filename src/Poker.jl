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
    using .Cards
    import StatsBase
    using Setfield

    # ================================= State Model ========================================

    struct GameState
        n_players::Int                  # Amount of total players
        playing_round::Array{Bool}      # Array with a boolean for each player that indicates whether they haven't folded yet (and thus can still bet)
        money_in_pot::Array{Int}        # Array with the amount of money in the pot
        money::Array{Int}               # Array with the amount of money the players still have
        cards::Array{Card}        # Array containing the cards in each players hand, dimensions: N_players x 2
        river::Array{Card}        # Array containing the cards in the river
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
        cards = StatsBase.sample(all_cards, total_cards_sampled; replace=false)
        river = cards[1:5]
        hand_cards = reshape(cards[6:end], (n_players, 2))
        return hand_cards, river
    end

    function hide_river(river::Array{Card})
        riv4 = river[4]
        riv5 = river[5]
        river[4] = @set riv4.hidden = true
        river[5] = @set riv5.hidden = true
    end

    function reveal_river_card(river::Array{Card}, index::Int)
        riv_card = river[index]
        river[index] = @set riv_card.hidden = false
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
        small_blind = 1 + (state.big_blind - 2 + state.n_players)%state.n_players
        println(small_blind)
        state = pay_to_pot(state, big_blind, state.big_blind_amount)
        state = pay_to_pot(state, small_blind, div(state.big_blind_amount, 2))
        return state
    end

    function payout_and_reset_pot(state::GameState, winner::Int) :: GameState
        state = @set state.money[winner] += sum(state.money_in_pot)
        state = @set state.money_in_pot = [0 for _ in 1:state.n_players]
        return state
    end

    function new_round(state::GameState, winner::Int) :: GameState
        cards, river = gen_hands_and_river(state.n_players)

        # Hide the last 2 cards of the river
        hide_river(river)

        # Move blinds and starting player
        state = @set state.big_blind = 1 + (state.big_blind)%state.n_players
        state = @set state.current_player = 1 + (state.big_blind)%state.n_players

        # Fill hands and river with new cards
        state = @set state.river = river
        state = @set state.cards = cards

        # Reset pot and folded players (though keep all people without money folded)
        state = @set state.playing_round = [state.money[i] != 0 for i in 1:state.n_players]
        state = payout_and_reset_pot(state, winner)

        # Reset last_raise
        state = @set state.last_raise = 0

        # Play blinds
        state = play_blinds(state)
        return state
    end

    # function transition(from_state::GameState)



    export GameState, start_game, new_round
end
