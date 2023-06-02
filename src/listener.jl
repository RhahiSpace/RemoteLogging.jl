"A shortcut function to start progress and message display"
function activate_listener(host::IPAddr=IPv4(0), port::Integer=50003;
    autoclose=true
)
    tcp1 = RemoteLogging.listen_message(host, port)
    tcp2 = RemoteLogging.listen_progress(host, port+1)
    if autoclose
        try
            readline(stdin)
        finally
            close(tcp1)
            close(tcp2)
        end
    end
    return tcp1, tcp2
end

"""
    listen_progress(host, port)

Listen to progress messages and show it.
"""
function listen_progress(host, port)
    server = listen(host, port)
    client_id = 0
    @async begin
        @info "Starting progress listener at $host:$port"
        while true
            conn = accept(server)
            client_id += 1
            @info "Accepted client P$client_id"
            @async begin
                id = client_id
                active_progress = Vector{UUID}()
                logger = TerminalLogger()
                try
                    with_logger(logger) do
                        while true
                            msg = deserialize(conn)
                            if msg.id ∉ active_progress
                                push!(active_progress, msg.id)
                            end
                            @info ProgressLogging.ProgressString(msg)
                            if msg.done || isnothing(msg.fraction)
                                idx = findfirst(x->x==msg.id, active_progress)
                                deleteat!(active_progress, idx)
                            end
                            eof(conn) && break
                        end
                    end
                    @info "Received EOF from client P$id"
                catch err
                    @warn err
                finally
                    with_logger(logger) do
                        for id in active_progress
                            @info ProgressLogging.Progress(; id=id, fraction=nothing, done=true)
                        end
                    end
                    @info "Closed connection with client P$id"
                    close(conn)
                end
            end
        end
    end
    server
end

"""
    listen_message(host, port, [io])

Listen to incoming messages and print them.
The formatting of the messages should be set in the RemoteLogger.
"""
function listen_message(host, port, io=stderr)
    server = listen(host, port)
    client_id = 0
    @async begin
        @info "Starting message listener at $host:$port"
        while true
            conn = accept(server)
            client_id += 1
            @info "Accepted client C$client_id"
            @async begin
                id = client_id
                try
                    while true
                        data = String(readline(conn))
                        println(io, data)
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
    server
end
