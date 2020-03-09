#=
Client:
- Julia version: 
- Author: gerben
- Date: 2020-03-09
=#

using Sockets
import JSON

function run_client(port::Int)
    sock = connect("localhost", port)
    while true
        line = readline(sock)
        if line != ""
            msg = JSON.parse(line)
            if msg["msg_type"] == "EVENT"
                if msg["msg"] == "HELLO"
                    println("What's your name?")
                    name = readline(keep=false)
                    resp::Dict{String, Any} = Dict(
                        "msg_type" => "CMD",
                        "msg" => "CONNECT",
                        "payload" => Dict(
                            "name" => "name"
                        )
                    )
                    resp_str::String = JSON.json(resp) * "\n"
                    write(sock, resp_str)
                end
            end
        end
    end
end