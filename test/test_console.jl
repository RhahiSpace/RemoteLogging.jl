@testset "ConsoleRemoteLogger" begin
    logger = ConsoleRemoteLogger(; host=HOST, port=MPORT, exclude_group=(:ProgressLogging, :exclude))
    try
        with_logger(logger) do
            # first, check that the color formats are preserved
            @info "test0"
            @test "\e[36m\e[1m[ \e[22m\e[39m\e[36m\e[1mInfo: \e[22m\e[39mtest0" == take!(messagedata.messages)

            # from now on simplify the test and only check the substrings.
            @info "test1"
            @test occursin("test1", take!(messagedata.messages))

            # test keyword arguments
            @info "test2" x=1 y="arg"
            @test occursin("test2", take!(messagedata.messages))
            @test occursin("x = 1", take!(messagedata.messages))
            @test occursin("y = \"arg\"", take!(messagedata.messages))

            # test different levels
            @warn "test3"
            @test occursin("Warning", take!(messagedata.messages))
            @test occursin("@ Main", take!(messagedata.messages))
            @debug "test4"
            sleep(0.1)
            @test !isready(messagedata.messages)
            @logmsg LogLevel(1500) "test5"
            @test occursin("test5", take!(messagedata.messages))
            @test occursin("@ Main", take!(messagedata.messages))

            # ignored groups should be ignored.
            @progress for i=1:10 end
            sleep(0.1)
            @test !isready(messagedata.messages)
            @info "test6" _group=:exclude
            sleep(0.1)
            @test !isready(messagedata.messages)
            @info "test7" _group=:include
            @test occursin("test7", take!(messagedata.messages))
        end
    finally
        close(logger)
    end
end