struct RemoteLogger{T<:AbstractLogger} <: AbstractLogger
    tcp1::TCPSocket
    tcp2::TCPSocket
    logger::T
end

function Base.close(logger::RemoteLogger)
    close(logger.tcp1)
    close(logger.tcp2)
end

function RemoteLogger(;
    host::IPAddr=IPv4(0),
    port::Integer=50003,
    displaywidth::Integer=80,
    console_loglevel::LogLevel=LogLevel(-1),
    disk_loglevel::LogLevel=LogLevel(-1000),
    directory::String = "",
    console_formatter::Union{Function, Nothing} = nothing,
    disk_formatter::Function = format_disk_output,
    console_exclude_group::Tuple{Vararg{Symbol}} = (:ProgressLogging,),
    console_exclude_module::Tuple{Vararg{Symbol}} = (),
    disk_exclude_group::Tuple{Vararg{Symbol}} = (:nosave,),
    disk_exclude_module::Tuple{Vararg{Symbol}} = console_exclude_module,
)
    tcp1, ioc = connect_to_listener(host, port, displaywidth)
    console = get_console_logger(
        ioc,
        console_loglevel,
        console_exclude_group,
        console_exclude_module,
    )
    if !isnothing(console_formatter)
        console = console_formatter(console)
    end
    # setup progress logger
    tcp2 = connect(host, port+1)
    progress = get_progress_logger(tcp2)
    if directory == ""
        combined = TeeLogger(console, progress)
        return RemoteLogger(tcp1, tcp2, combined)
    end
    # setup file logger
    disk = get_disk_loggers(
        disk_loglevel,
        directory,
        disk_formatter,
        file_groups,
        disk_exclude_group,
        disk_exclude_module
    )
    combined = TeeLogger(console, progress, disk)
    return RemoteLogger(tcp1, tcp2, combined)
end

shouldlog(_::RemoteLogger, args...) = true
min_enabled_level(_::RemoteLogger) = BelowMinLevel
catch_exceptions(logger::RemoteLogger) = catch_exceptions(logger.logger)
handle_message(logger::RemoteLogger, args...; kwargs...) = handle_message(logger.logger, args...; kwargs...)

function get_console_logger(io, loglevel, ex_group, ex_module)
    logger = TerminalLogger(io, loglevel)
    logger = group_module_filter(logger, ex_group, ex_module)
    return logger
end

function get_progress_logger(tcp)
    logger = TerminalLogger(devnull)
    logger = TransformerLogger(logger) do log
        serialize(tcp, log.message.progress)
        return log
    end
    logger = EarlyFilteredLogger(logger) do log
        log.group == :ProgressLogging
    end
    return logger
end

function get_disk_loggers(
    disk_loglevel::LogLevel,
    directory::String,
    disk_formatter::Function,
    file_groups::Dict{String, Vector{Symbol}},
    ex_group,
    ex_module,
)
    loggers = Vector{EarlyFilteredLogger}()
    everything = disk_formatter("$directory/all")
    remaining = disk_formatter("$directory/default")
    push!(loggers, everything, remaining)
    for (name, groups) in file_groups
        if name in ("default", "all")
            continue
        end
        sink = disk_formatter("$directory/$name")
        filter = EarlyFilteredLogger(sink) do
            log.group ∈ groups ? true : false
        end
        remaining = EarlyFilteredLogger(remaining) do
            log.group ∉ groups ? true : false
        end
        push!(loggers, filter)
    end
    logger = TeeLogger(loggers...)
    logger = MinLevelLogger(logger, disk_loglevel)
    group_module_filter(logger, ex_group, ex_module)
end

function format_disk_output(path::String)
    return FormatLogger(path) do io, args
        println(io, "[", args.group, "/", args.level, "] - ", args.message)
    end
end

function root_module(m::Module)
    gp = m
    while (gp ≠ m)
        m = parentmodule(m)
        gp = m
    end
    nameof(gp)
end

function group_module_filter(logger, ex_group, ex_module)
    EarlyFilteredLogger(logger) do log
        log.group in ex_group && return false
        root_module(log._module) in ex_module && return false
        return true
    end
end

function connect_to_listener(host, port, displaywidth)
    tcp = connect(host, port)
    dsize = (displaysize()[1], displaywidth)
    ioc = IOContext(tcp, :color => true, :displaysize => dsize)
    return tcp, ioc
end
