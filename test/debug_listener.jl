mutable struct ProgressData
    server::Sockets.TCPServer
    clients::Int64
    messages::Channel{ProgressLogging.ProgressString}
    active_progress::Vector{UUID}
    function ProgressData(host, port)
        server = listen(host, port)
        messages = Channel{ProgressLogging.ProgressString}(100)
        active_progress = Vector{UUID}()
        new(server, 0, messages, active_progress)
    end
end

function listen_progress(host, port)
    debug = ProgressData(host, port)
    @async begin
        @info "Starting progress listener at $host:$port"
        while true
            conn = accept(debug.server)
            debug.client_id += 1
            @info "Accepted client P$(debug.clients)"
            @async begin
                id = debug.client_id
                logger = TerminalLogger(devnull)
                try
                    with_logger(logger) do
                        while true
                            msg = deserialize(conn)
                            if msg.id ∉ active_progress
                                push!(debug.active_progress, msg.id)
                            end
                            push!(debug.messages, ProgressLogging.ProgressString(msg))
                            if msg.done || isnothing(msg.fraction)
                                idx = findfirst(x->x==msg.id, debug.active_progress)
                                deleteat!(debug.active_progress, idx)
                            end
                            eof(conn) && break
                        end
                    end
                    @info "Received EOF from client P$id"
                catch err
                    @warn err
                finally
                    with_logger(logger) do
                        for id in debug.active_progress
                            @info ProgressLogging.Progress(; id=id, fraction=nothing, done=true)
                        end
                    end
                    @info "Closed connection with client P$id"
                    close(conn)
                end
            end
        end
    end
    debug
end

mutable struct MessageData
    server::Sockets.TCPServer
    clients::Int64
    messages::Channel{String}
    function MessageData(host, port)
        server = listen(host, port)
        clients = 0
        messages = Channel{String}(100)
        new(server, clients, messages)
    end
end

function listen_message(host, port)
    debug = MessageData(host, port)
    @async begin
        @info "Starting message listener at $host:$port"
        while true
            conn = accept(debug.server)
            debug.clients += 1
            @info "Accepted client C$(debug.clients)"
            @async begin
                id = debug.clients
                try
                    while true
                        data = String(readline(conn))
                        push!(debug.messages, data)
                        eof(conn) && break
                    end
                    @info "Received EOF from client C$id"
                catch err
                    bt = catch_backtrace()
                    @error "Error with client C$id"
                    showerror(stderr, err, bt)
                finally
                    @info "Closed connection with client C$id"
                    close(conn)
                end
            end
        end
    end
    debug
end
