using Test
using MTGRE

@testset "Trace construction & defaults" begin
    tr = MTGRE.Trace()
    @test isa(tr.entries, Vector{MTGRE.TraceEntry})
    @test tr.enabled === true
    @test tr.nextseq == MTGRE.Seq(1)
    @test tr.seed == UInt64(0xC0FFEE)
end

@testset "TraceEntry outer constructor coerces widths" begin
    # Pass natural Ints; outer ctor must coerce to fixed widths
    e = MTGRE.TraceEntry(1, 0, 7, 9, 2, 3, MTGRE.microcycle, MTGRE.cohort, MTGRE.SE_batch)
    @test e.seq       isa MTGRE.Seq          # UInt64
    @test e.cause_seq isa MTGRE.Seq          # UInt64
    @test e.t         isa MTGRE.VTime        # Int32
    @test e.cohort    isa MTGRE.Cohort       # Int32
    @test e.actor_id  isa MTGRE.ActorId      # UInt32
    @test e.frame_id  isa MTGRE.FrameId      # UInt32
    @test e.phase === MTGRE.microcycle
    @test e.kind  === MTGRE.cohort
    @test e.tag   === MTGRE.SE_batch
end

@testset "push! sequencing & bump" begin
    tr = MTGRE.Trace()
    e1 = MTGRE.TraceEntry(tr.nextseq, 0, 0, 0, 0, 0, MTGRE.microcycle, MTGRE.cohort, MTGRE.SE_batch)
    push!(tr, e1)
    @test length(tr.entries) == 1
    @test tr.entries[end].seq == MTGRE.Seq(1)
    @test tr.nextseq == MTGRE.Seq(2)

    e2 = MTGRE.TraceEntry(tr.nextseq, 1, 0, 0, 0, 0, MTGRE.microcycle, MTGRE.commit, MTGRE.SE_commit)
    push!(tr, e2)
    @test length(tr.entries) == 2
    @test tr.entries[end].seq == MTGRE.Seq(2)
    @test tr.nextseq == MTGRE.Seq(3)
end

@testset "push! rejects mismatched seq stamp" begin
    tr = MTGRE.Trace()
    bad = MTGRE.TraceEntry(tr.nextseq + 1, 0, 0, 0, 0, 0, MTGRE.microcycle, MTGRE.cohort, MTGRE.SE_batch)
    @test_throws AssertionError push!(tr, bad)
end

@testset "push! enforces causal ordering" begin
    tr = MTGRE.Trace()
    ok = MTGRE.TraceEntry(tr.nextseq, 0, 0, 0, 0, 0, MTGRE.microcycle, MTGRE.cohort, MTGRE.SE_batch)
    push!(tr, ok)
    bad_cause = MTGRE.TraceEntry(tr.nextseq, tr.nextseq + 1, 0, 0, 0, 0, MTGRE.microcycle, MTGRE.commit, MTGRE.SE_commit)
    @test_throws AssertionError push!(tr, bad_cause)
end

@testset "trace!(::Trace) honors enabled gate and stamps seq" begin
    tr = MTGRE.Trace()
    tr.enabled = false
    n0 = length(tr.entries)
    MTGRE.trace!(tr; phase=MTGRE.microcycle, kind=MTGRE.cohort, tag=MTGRE.SE_batch)
    @test length(tr.entries) == n0   # no-op when disabled

    tr.enabled = true
    seq0 = tr.nextseq
    MTGRE.trace!(tr; phase=MTGRE.microcycle, kind=MTGRE.cohort, tag=MTGRE.SE_batch,
                    t=0, cohort=1, actor_id=2, frame_id=3, cause_seq=0)
    @test length(tr.entries) == n0 + 1
    e = tr.entries[end]
    @test e.seq == seq0
    @test e.t == MTGRE.VTime(0)
    @test e.cohort == MTGRE.Cohort(1)
    @test e.actor_id == MTGRE.ActorId(2)
    @test e.frame_id == MTGRE.FrameId(3)
    @test e.phase === MTGRE.microcycle
    @test e.kind  === MTGRE.cohort
    @test e.tag   === MTGRE.SE_batch
end

@testset "Checkpoint sentinel shape (manual append)" begin
    tr = MTGRE.Trace()
    push!(tr, MTGRE.TraceEntry(tr.nextseq, 0, 0, 0, 0, 0, MTGRE.microcycle, MTGRE.cohort,      MTGRE.SE_batch))
    push!(tr, MTGRE.TraceEntry(tr.nextseq, 1, 0, 0, 0, 0, MTGRE.microcycle, MTGRE.commit,      MTGRE.SE_commit))
    push!(tr, MTGRE.TraceEntry(tr.nextseq, 2, 0, 0, 0, 0, MTGRE.microcycle, MTGRE.checkpoint,  MTGRE.done))
    @test tr.entries[end].kind === MTGRE.checkpoint
    @test tr.entries[end].tag  === MTGRE.done
    @test count(e -> e.kind === MTGRE.checkpoint && e.tag === MTGRE.done, tr.entries) == 1
end

@testset "Type coercion is consistent via trace!(::Trace)" begin
    tr = MTGRE.Trace()
    MTGRE.trace!(tr; phase=MTGRE.microcycle, kind=MTGRE.cohort, tag=MTGRE.SE_batch,
                    t=7, cohort=9, actor_id=2, frame_id=3, cause_seq=0)
    e = tr.entries[end]
    @test e.t        isa MTGRE.VTime
    @test e.cohort   isa MTGRE.Cohort
    @test e.actor_id isa MTGRE.ActorId
    @test e.frame_id isa MTGRE.FrameId
    @test e.seq      isa MTGRE.Seq
    @test e.cause_seq isa MTGRE.Seq
end