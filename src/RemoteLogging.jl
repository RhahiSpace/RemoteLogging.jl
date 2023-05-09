module RemoteLogging

using Logging
using LoggingExtras
using ProgressLogging
using Serialization
using Sockets
using TerminalLoggers
using UUIDs
import Base.CoreLogging:
    AbstractLogger, SimpleLogger,
    handle_message, shouldlog, min_enabled_level, catch_exceptions

export RemoteLogger

include("logger.jl")
include("listener.jl")

end
