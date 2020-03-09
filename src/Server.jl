#=
Server:
- Julia version: 
- Author: gerben
- Date: 2020-03-09
=#
using Sockets
import JSON

struct Client
    socket::TCPSocket
    name::String
end

mutable struct Lobby
    clients::Array{Client}
    name::String
end

function run_server(port:: Int)
    new_sock::Channel{TCPSocket} = Channel{TCPSocket}()
    msg_channel::Channel{Tuple{TCPSocket, String}}= Channel{Tuple{TCPSocket, String}}()
    active_sockets::Array{TCPSocket} = []
    no_hello::Array{TCPSocket} = []
    no_name::Array{TCPSocket} = []
    waiting_for_lobby::Array{Client} = []
    server = listen(IPv4(0), port)


    function handle_client(sock)
        while true
            put!(msg_channel, Tuple{TCPSocket, String}(sock, readline(sock)))
            sleep(0.1)
        end
    end

    function handle_msg(sock, msg)
        msg = JSON.parse(msg)
        if msg["msg_type"] == "CMD"
            if msg["msg"] == "CONNECT"
                println("Received CONNECT")
                if sock in no_name
                    client = Client(sock, msg["payload"]["name"])
                    remove!(no_name, sock)
                    push!(waiting_for_lobby, client)
                    println("Added waiting client", waiting_for_lobby)
                end
            end
        end
    end

    @async begin
        println("Listening...")
        while true
            sock = accept(server)
            println("Adding n_hello")
            put!(new_sock, sock)
            println("Added n_hello")
        end
        println("Stopped")
        close(server)
    end
    try
        while true
            if isready(new_sock)
                println("New socket appeared")
                sock = take!(new_sock)
                println(sock)
                @async handle_client(sock)
                henlo = Dict(
                    "msg_type" => "EVENT",
                    "msg" => "HELLO",
                    "payload" => Dict()
                )
                resp::String = JSON.json(henlo) *  "\n"
                write(sock, resp)
                println("Sent")
                push!(no_hello, sock)
                push!(active_sockets, sock)
                println(no_hello)
            end

            if isready(msg_channel)
                println("Reading message")
                sock, msg = take!(msg_channel)
                handle_msg(sock, msg)
            end
            sleep(0.01)
        end
    catch ex
        println(ex)
        if isa(ex, InterruptException)
            println("Closing server")
            close(server)
        end
    end
end
