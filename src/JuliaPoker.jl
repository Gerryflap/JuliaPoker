#=
main:
- Julia version: 1.3.1
- Author: gerben
- Date: 2020-02-08
=#
module JuliaPoker
    include("Cards.jl")
    include("Poker.jl")

    function main()
        card1 = Cards.Card(Cards.spades, Cards.ace)
        println(card1)

        gamestate1 = Poker.start_game(4, 10000)
        println(gamestate1)
    end
    export main
end