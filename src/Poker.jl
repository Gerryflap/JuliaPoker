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

    function get_relative_player(player::Int, relative_pos::Int, n_players::Int) :: Int
        return 1 + (player - 1 + relative_pos + n_players)%n_players


    function gen_hands_and_river(n_players::Int)
        # Returns a tuple of cards and river variables for the gamestate struct
        total_cards_sampled = n_players * 2 + 5
        cards = StatsBase.sample(all_cards, total_cards_sampled; replace=false)
        river = cards[1:5]
        hand_cards = reshape(cards[6:end], (n_players, 2))
        return hand_cards, river
    end

    function hide_river(river::Array{Card})
        for i in 1:length(river)
            riv_i = river[i]
            river[i] = @set riv_i.hidden = true
    end

    function reveal_river_card(state::GameState, index::Int)
        riv_card = state.river[index]
        riv_card = @set riv_card.hidden = false
        return @set state.river[index] = riv_card
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
        # TODO: what to do when no money?! Go all-in?
        big_blind = state.big_blind
        small_blind = 1 + (state.big_blind - 2 + state.n_players)%state.n_players
        println(small_blind)
        state = pay_to_pot(state, big_blind, state.big_blind_amount)
        state = pay_to_pot(state, small_blind, div(state.big_blind_amount, 2))
        return state
    end

    function payout_and_reset_pot(state::GameState, winner::Int) :: GameState
        # If the winner went all-in, only give as much from each player as the winner put in
        won_pot = clamp.(state.money_in_pot, 0, state.money_in_pot[winner])

        # Compute what remains in the pot after that operation
        remaining_pot = state.money_in_pot - won_pot

        # Add the winner's money to his pot money
        remaining_pot[winner] += sum(won_pot)

        # Move pot money back to players and reset pot
        state = @set state.money += remaining_pot
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


    function transition(state::GameState, action::Action)::Tuple3{GameState, Action, Bool}
        # Performs the action and returns a new gamestate, the actually performed action and the "done" boolean
        current_player = state.current_player
        current_max_bet = max(state.money_in_pot)

        if action isa RaiseAction || action == check
            # Compute what amount we're raising/checking to
            if action == check
                raise_to = current_max_bet
            else
                raise_to = current_max_bet + action.amount
            end

            # Compute how much more money we have to bet
            money_to_bet = raise_to - state.money_in_pot[current_player]

            # Check whether we have the money. If not, go all-in
            if state.money[current_player] < money_to_bet
                action = all_in
            else
                state = pay_to_pot(state, current_player, money_to_bet)
            end
        end

        if action == all_in
            # Put all we have in the pot
            state = pay_to_pot(state, current_player, state.money[current_player])
        end

        if action == fold
            state = @set state.playing_round[current_player] = false
        end

        # Next player selection/next round checks
        no_player_found = false
        passed_last_raise = false
        next_player = get_relative_player(current_player, 1, state.n_players)
        starting_nest_player = next_player
        passed_last_raise |= next_player == state.last_raise
        while !state.playing_round[next_player] || state.money[next_player] == 0
            next_player = get_relative_player(next_player, 1, state.n_players)
            passed_last_raise |= next_player == state.last_raise
            if next_player == starting_next_player
                no_player_found = true
                break
            end
        end


        # Check if everyone but one person has folded
        if sum(state.playing_round) == 1
            # Round done
            winner = argmax(state.playing_round)
            state = payout_and_reset_pot(state, winner)
        end

        if no_player_found
            # TODO: end round
        end

        # Check if it is time to reveal cards in the river or count points and finish the round
        if passed_last_raise
            # Check whether this is the end
            if !state.river[5].hidden
                # TODO: end round
            else
                # Start at big blind again, reset last_raise and reveal the next card

                # Find next suitable player
                next_player = state.big_blind
                while !state.playing_round[next_player] || state.money[next_player] == 0
                    next_player = get_relative_player(next_player, 1, state.n_players)
                    end
                end

                state = @set state.last_raise = 0
                if state.river[3].hidden
                    state = reveal_river_card(state, 1)
                    state = reveal_river_card(state, 2)
                    state = reveal_river_card(state, 3)
                elseif state.river[4].hidden
                    state = reveal_river_card(state, 4)
                else
                    state = reveal_river_card(state, 5)





    end



    export GameState, start_game, new_round
end
