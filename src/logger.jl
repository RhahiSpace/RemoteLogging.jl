struct ConsoleRemoteLogger{T<:AbstractLogger} <: AbstractLogger
    tcp::TCPSocket
    logger::T
end

"""
    ConsoleRemoteLogger(; [kwargs...])

Create a logger that sends log messages over TCP as text.

For full help of keyword arguments, see [`RemoteLogger`](@ref)

To change formatting of the logger, pass a function that accepts IO and returns
a FormatLogger using that IO. This formatter will be used as tthe final sink
in ConsoleRemoteLogger. Otherwise, Logging.ConsoleLogger is used.

# Example
```julia
# assuming that a listener has already been set up
logger = ConsoleRemoteLogger(; port=50010)
with_logger(logger) do
    @debug "debug"
    @info "info"
end
close(logger)

In this case, only the info message should be transported over the network.
```
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

"An exmaple for implementing formatter for ConsoleRemoteLogger."
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

struct ProgressRemoteLogger{T<:AbstractLogger} <: AbstractLogger
    tcp::TCPSocket
    logger::T
end

"""
    ProgressRemoteLogger(; [host,] [port])

Create a logger that sends ProgressLogging.Progress information over TCP.

# Example
```julia
# assuming that a listener has already been set up
logger = ProgressRemoteLogger(; port=50011)
with_logger(logger) do
    @progress for i=1:10
        sleep(0.1)
    end
end
close(logger)
```

The progress message should appear on the remote listener.
"""
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
    RemoteLogger(; [kwargs...])

A combined ConsoleRemoteLogger and ProgressRemoteLogger. Log messages
and progress bars produced with this logger will appear in the remote listener.

# Arguments

- `host`: IP address of the listener. The listener should be running in advance.
- `port`: Port of the listener. `port` and `port+1` will be used.
- `console_displaywidth`: intended width of the log viewer. It can be used by
  the printer. RemoteLogging's default listener does not use this value.
- `console_loglevel`: minimum log level to be sent to the remote console
- `console_formatter`: extra formatter for console. It should be a function that
  accepts a logger and combine it with a another compositional logger.
- `console_exclude_group`: log groups to ignore. Log messages with this group
  will not be sent to ConsoleRemoteLogger. Ignores :ProgressLogging by default.
- `console_exclude_module`: source modules to ignore in console. Log messages
  that used to be hidden because it originates from another library will not
  be filtered here. Specify them here so that they will not be sent.
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
    while m != parentmodule(m)
        m = parentmodule(m)
    end
    nameof(m)
end
