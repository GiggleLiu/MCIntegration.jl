@testset "Variable" begin
    @test Dist.is_variable(Int) == false
    @test Dist.is_variable(Continuous) == true
    @test Dist.is_variable(Discrete) == true
    @test Dist.is_variable(CompositeVar) == true
    N = 7
    x = Continuous(0.0, 1.0, N; grid=[0.0, 0.1, 0.4, 1.0])
    @test Dist.is_variable(x) == true
    y = Discrete(1, 6; distribution=rand(6))
    @test Dist.is_variable(y) == true
    cxy = CompositeVar(x, y)
    @test Dist.is_variable(cxy) == true

    @test length(x) == N + 1
    @test size(x) == (N + 1,)

    # test iteration
    v = [d for d in x]
    @test v ≈ x

    @test eltype(typeof(x)) == typeof(x[1])
end