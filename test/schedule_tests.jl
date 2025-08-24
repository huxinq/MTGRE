# test/schedule_tests.jl
using Test
using MTGRE

const MCore = MTGRE.Core          # SAFE alias; don't use `Core`
const Eng   = MTGRE.Engine        # where schedule! lives

# Dummy ops to schedule
struct TOpA <: MCore.Op; id::Int; end
struct TOpB <: MCore.Op; id::Int; end

@testset "schedule!" begin

@testset "schedule!: basic enqueue at default t_current" begin
    S = MCore.GameState()                 # t_current == VTime(0)
    @test MCore.getvtime(S) == MCore.VTime(0)

    r = Eng.schedule!(S, MCore.Op[TOpA(1)])
    @test r === nothing

    @test haskey(S.sched, MCore.VTime(0))
    bucket = S.sched[MCore.VTime(0)]
    @test length(bucket) == 1

    b = bucket[1]
    @test getfield(b, :cohort) == MCore.Cohort(0)
    ops = getfield(b, :ops)
    @test ops isa Vector{MCore.Op}
    @test length(ops) == 1
    @test ops[1] isa TOpA
end

@testset "schedule!: explicit t and cohort are respected" begin
    S = MCore.GameState()
    tX = MCore.VTime(5); cX = MCore.Cohort(42)

    Eng.schedule!(S, MCore.Op[TOpA(10)]; t=tX, cohort=cX)

    @test haskey(S.sched, tX)
    bucket = S.sched[tX]
    @test length(bucket) == 1
    b = bucket[1]
    @test getfield(b, :cohort) == cX
    @test getfield(b, :ops)[1] isa TOpA

    # scheduling must not change t_current
    @test MCore.getvtime(S) == MCore.VTime(0)
end

@testset "schedule!: varargs form collects ops and preserves order" begin
    S = MCore.GameState()
    t  = MCore.VTime(3); c = MCore.Cohort(7)
    a, b, c3 = TOpA(1), TOpB(2), TOpA(3)

    Eng.schedule!(S, a, b, c3; t=t, cohort=c)

    bucket = S.sched[t]
    @test length(bucket) == 1
    ops = getfield(bucket[1], :ops)
    @test length(ops) == 3
    @test ops[1] === a
    @test ops[2] === b
    @test ops[3] === c3
end

@testset "schedule!: FIFO across multiple batches at same t" begin
    S = MCore.GameState()
    t = MCore.VTime(1)
    Eng.schedule!(S, MCore.Op[TOpA(1)]; t=t, cohort=MCore.Cohort(1))
    Eng.schedule!(S, MCore.Op[TOpB(2)]; t=t, cohort=MCore.Cohort(2))
    Eng.schedule!(S, MCore.Op[TOpA(3)]; t=t, cohort=MCore.Cohort(3))

    bucket = S.sched[t]
    @test length(bucket) == 3
    @test getfield(bucket[1], :cohort) == MCore.Cohort(1)
    @test getfield(bucket[2], :cohort) == MCore.Cohort(2)
    @test getfield(bucket[3], :cohort) == MCore.Cohort(3)
end

@testset "schedule!: lazily creates bucket for new t" begin
    S = MCore.GameState()
    t = MCore.VTime(9)
    @test !haskey(S.sched, t)

    Eng.schedule!(S, MCore.Op[TOpA(99)]; t=t, cohort=MCore.Cohort(0))

    @test haskey(S.sched, t)
    @test length(S.sched[t]) == 1
end

end