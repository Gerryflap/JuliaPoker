"""
# module Cards

- Julia version: 1.3.1
- Author: gerben
- Date: 2020-02-08

# Examples

```jldoctest
julia>
```
"""
module Cards
    # ======================= Cards and their values ======================================
    # Card ranks
    import Base.show
    @enum NamedRank jack=11 queen=12 king=13 ace=14
    struct NumberedRank
        value::Int
    end
    Rank = Union{NamedRank, NumberedRank}

    # Rank ordering
    Base.isless(a::NumberedRank, b::NumberedRank) = a.value < b.value
    Base.isless(a::NumberedRank, b::NamedRank) = a.value < Integer(b)
    Base.isless(a, b::NumberedRank) = Integer(a) < b.value

    # List all possible ranks
    possible_ranks = [[NumberedRank(i) for i in 2:10]; [jack, queen, king, ace]]

    # Card suits
    @enum Suit hearts=1 diamonds=2 clubs=3 spades=4
    possible_suits = [hearts; diamonds; clubs; spades]

    # Cards
    struct Card
        suit::Suit
        rank::Rank
        hidden::Bool
        Card(s, r) = new(s, r, false)
        Card(s, r, h) = new(s, r, h)
    end

    # Card ordering
    Base.isless(a::Card, b::Card) = a.rank < b.rank

    # List all possible cards
    all_cards = [Card(suit, rank) for suit in possible_suits for rank in possible_ranks]

    # ======================= Printing and encoding ======================================
    function pretty_suit(a::Suit)
        if a == hearts
            return "♥"
        elseif a == diamonds
            return "♦"
        elseif a == spades
            return "♠"
        else
            return "♣"
        end
    end

    function pretty_rank(a::NumberedRank)
        return string(a.value)
    end

    function pretty_rank(a::NamedRank)
        if a == jack
            return "J"
        elseif a == queen
            return "Q"
        elseif a == king
            return "K"
        else
            return "A"
        end
    end

    function pretty_card(card::Card)
        s = "\e[0;47"


        if card.hidden
            s *= ";30m??"
        else
            if card.suit == diamonds || card.suit == hearts
                s *= ";31m"
            else
                s *= ";30m"
            end

            s *= pretty_suit(card.suit) * " " * pretty_rank(card.rank)
        end
        s *= "\e[0m"
        return s
    end

    Base.show(io::IO, x::Card) = write(io, pretty_card(x))
    export Suit, NamedRank, NumberedRank, Rank, Card, possible_ranks, possible_suits, all_cards

end