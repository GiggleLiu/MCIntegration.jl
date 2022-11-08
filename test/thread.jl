@testset "Threads" begin
    if Threads.nthreads() == 1
        @warn "There is only one thread currently. You may want run julia with -t auto to enable multithreading."
    end

    Threads.@threads for i in 1:3
        println("test thread: ", i)
        X = Continuous(0.0, 1.0)
        result = integrate((X, c) -> (X[1])^i; var=(Continuous(0.0, 1.0),), dof=[[1,],], print=-1, solver=:vegas, parallel = :nothread)
        println(i, " -> ", result.mean, "+-", result.stdev)
        check(result, 1 / (1 + i))
        result = integrate((X, c) -> (X[1])^i; var=(Continuous(0.0, 1.0),), dof=[[1,],], print=-1, solver=:vegasmc, parallel = :nothread)
        check(result, 1 / (1 + i))
        result = integrate((idx, X, c) -> (X[1])^i; var=(Continuous(0.0, 1.0),), dof=[[1,],], print=-1, solver=:mcmc, parallel = :nothread)
        check(result, 1 / (1 + i))
    end

end

@testset "inner thread test" begin
    if Threads.nthreads() == 1
        @warn "There is only one thread currently. You may want run julia with -t auto to enable multithreading."
    end
    X = Continuous(0.0, 1.0)
    i = 2
    result = integrate((x, c) -> (x[1])^i; var=(Continuous(0.0, 1.0),), dof=[[1,],], print=-1, solver=:vegas, parallel = :thread)
    println(i, " -> ", result.mean, "+-", result.stdev)
    check(result, 1 / (1 + i))
end