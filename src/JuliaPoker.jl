#=
main:
- Julia version: 1.3.1
- Author: gerben
- Date: 2020-02-08
=#
module JuliaPoker
    include("Cards.jl")
    import .Cards

    function main()
        card1 = Cards.Card(Cards.spades, Cards.ace)
        print(card1)
    end
    export main
end