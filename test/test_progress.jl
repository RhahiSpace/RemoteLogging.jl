function progress_test(logger)
    with_logger(logger) do
        # progresslogger does not respond to regular messages.
        @info "test0"
        sleep(0.1)
        @test !isready(progressdata.messages)

        # check that four progress messages are created
        @progress for i=1:4 end
        @test take!(progressdata.messages).fraction isa Nothing
        @test take!(progressdata.messages).fraction ≈ 0.25 #1
        @test take!(progressdata.messages).fraction ≈ 0.5 #2
        @test take!(progressdata.messages).fraction ≈ 0.75 #3
        @test take!(progressdata.messages).fraction ≈ 1 #4
        @test take!(progressdata.messages).done == true
        @test !isready(progressdata.messages)
    end
end

@testset "ProgressRemoteLogger" begin
    logger = ProgressRemoteLogger(; host=HOST, port=PPORT)
    try
        progress_test(logger)
    finally
        close(logger)
    end
end
