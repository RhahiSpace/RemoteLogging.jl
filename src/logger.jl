struct ConsoleRemoteLogger{T<:AbstractLogger} <: AbstractLogger
    tcp::TCPSocket
    logger::T
end

"""
    ConsoleRemoteLogger(; kwargs...)

Send log messages to a remote listener over the network.

See RemoteLogger for documentation of keyword arguments.
"""
function ConsoleRemoteLogger(;
    host::IPAddr = IPv4(0),
    port::Integer = 50003,
    displaywidth::Integer = 80,
    loglevel::LogLevel = LogLevel(-1),
    formatter::Union{Function, Nothing} = nothing,
    exclude_group::Tuple{Vararg{Symbol}} = (:ProgressLogging,),
    exclude_module::Tuple{Vararg{Symbol}} = (),
)
    tcp, ioc = connect_to_listener(host, port, displaywidth)
    base = nothing
    if !isnothing(formatter)
        format = formatter(ioc)
        base = MinLevelLogger(format, loglevel)
    else
        base = ConsoleLogger(ioc, loglevel)
    end
    logger = group_module_filter(
        base,
        exclude_group,
        exclude_module
    )
    return ConsoleRemoteLogger(tcp, logger)
end

function console_example_formatter(ioc::IOContext)
    FormatLogger(ioc) do io, args
        println(io, args.message)
    end
end

function connect_to_listener(host, port, displaywidth)
    tcp = connect(host, port)
    dsize = (displaysize()[1], displaywidth)
    ioc = IOContext(tcp, :color => true, :displaysize => dsize)
    return tcp, ioc
end

"""
    ProgressRemoteLogger(; host, port)

Progress bars produced with this logger will appear in the remote listener.

- `host`: IP address of the listener. Should be running in advance.
- `port`: Port of the listener.
"""
struct ProgressRemoteLogger{T<:AbstractLogger} <: AbstractLogger
    tcp::TCPSocket
    logger::T
end

function ProgressRemoteLogger(;
    host::IPAddr=IPv4(0),
    port::Integer=50004,
)
    tcp = connect(host, port)
    base = TerminalLogger(devnull)
    semaphore = Base.Semaphore(1)
    network = TransformerLogger(base) do log
        try
            if log.message isa ProgressLogging.ProgressString
                Base.acquire(semaphore) do
                    serialize(tcp, log.message.progress)
                end
            elseif log.message isa ProgressLogging.Progress
                Base.acquire(semaphore) do
                    serialize(tcp, log.message)
                end
            end
        catch
            println(stderr, "Failed to serialize `$(log.message)` during progress")
        end
        return log
    end
    logger = EarlyFilteredLogger(network) do log
        log.group == :ProgressLogging
    end
    return ProgressRemoteLogger(tcp, logger)
end

struct RemoteLogger{T<:AbstractLogger} <: AbstractLogger
    message::TCPSocket
    progress::TCPSocket
    logger::T
end

"""
    RemoteLogger(; kwargs...)

Combination of ConsoleRemoteLogger and ProgressRemoteLogger. Log messages
and progress bars produced with this logger will appear in the remote listener.

# Arguments

- `host`: IP address of the listener. Should be running in advance.
- `port`: Port of the listener. `port` and `port+1` will be used.
- `console_displaywidth`: intended width of the log viewer.
- `console_loglevel`: minimum log level to be displayed on remote console
- `console_formatter`: extra formatter for console. It should be a function that
  accepts a logger and combine it with a another compositional logger.
- `console_exclude_group`: log groups to ignore in console. Ignores
  :ProgressLogging by default.
- `console_exclude_module`: source modules to ignore in console.
"""
function RemoteLogger(;
    host::IPAddr = IPv4(0),
    port::Integer = 50003,
    displaywidth::Integer = 80,
    loglevel::LogLevel = LogLevel(-1),
    formatter::Union{Function, Nothing} = nothing,
    exclude_group::Tuple{Vararg{Symbol}} = (:ProgressLogging,),
    exclude_module::Tuple{Vararg{Symbol}} = (),
)
    console = ConsoleRemoteLogger(;
        host = host,
        port = port,
        displaywidth = displaywidth,
        loglevel = loglevel,
        formatter = formatter,
        exclude_group = exclude_group,
        exclude_module = exclude_module
    )
    progress = ProgressRemoteLogger(; host = host, port = port+1)
    combined = TeeLogger(console, progress)
    return RemoteLogger(console.tcp, progress.tcp, combined)
end

"""
    group_module_filter(logger, ex_group, ex_module)

Combined EarlyFilteredLogger that filters based on module and group of the log.
"""
function group_module_filter(logger, ex_group, ex_module)
    EarlyFilteredLogger(logger) do log
        log.group in ex_group && return false
        root_module(log._module) in ex_module && return false
        return true
    end
end

"""
    root_module(m)

Find the root module of the given module.
Useful for filtering out modules in log messages.
"""
function root_module(m::Module)
    gp = m
    while (gp ≠ m)
        m = parentmodule(m)
        gp = m
    end
    nameof(gp)
end
