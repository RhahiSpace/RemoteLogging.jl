Base.close(logger::ConsoleRemoteLogger) = close(logger.tcp)
shouldlog(logger::ConsoleRemoteLogger, args...) = shouldlog(logger.logger, args...)
min_enabled_level(logger::ConsoleRemoteLogger) = min_enabled_level(logger.logger)
catch_exceptions(logger::ConsoleRemoteLogger) = catch_exceptions(logger.logger)
handle_message(logger::ConsoleRemoteLogger, args...; kwargs...) = handle_message(logger.logger, args...; kwargs...)

Base.close(logger::ProgressRemoteLogger) = close(logger.tcp)
shouldlog(logger::ProgressRemoteLogger, args...) = shouldlog(logger.logger, args...)
min_enabled_level(logger::ProgressRemoteLogger) = min_enabled_level(logger.logger)
catch_exceptions(logger::ProgressRemoteLogger) = catch_exceptions(logger.logger)
handle_message(logger::ProgressRemoteLogger, args...; kwargs...) = handle_message(logger.logger, args...; kwargs...)

function Base.close(logger::RemoteLogger)
    close(logger.message)
    close(logger.progress)
end

shouldlog(_::RemoteLogger, args...) = true
min_enabled_level(_::RemoteLogger) = BelowMinLevel
catch_exceptions(logger::RemoteLogger) = catch_exceptions(logger.logger)
handle_message(logger::RemoteLogger, args...; kwargs...) = handle_message(logger.logger, args...; kwargs...)
