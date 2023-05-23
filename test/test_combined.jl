@testset "Combined test" begin
    logger = RemoteLogger(; host=HOST, port=MPORT, exclude_group=(:ProgressLogging, :exclude))
    try
        console_test(logger, false)
        progress_test(logger)
    finally
        close(logger)
    end
end
