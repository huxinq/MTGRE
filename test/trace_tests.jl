using Test
using MTGRE
using MTGRE.Tracing

@testset "Trace" begin

@testset "Trace construction & defaults" begin
    tr = MTGRE.Trace()
    @test isa(tr.entries, Vector{MTGRE.TraceEntry})
    @test tr.enabled === true
    @test tr.nextseq == MTGRE.Seq(1)
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

@testset "Trace predicate builders" begin
    # Build a small trace with varied fields
    tr = MTGRE.Trace()
    push!(tr, MTGRE.TraceEntry(tr.nextseq, 0,  0, 0, 1, 10, MTGRE.microcycle, MTGRE.cohort,     MTGRE.SE_batch))    # seq=1
    push!(tr, MTGRE.TraceEntry(tr.nextseq, 1,  0, 0, 1, 10, MTGRE.microcycle, MTGRE.commit,     MTGRE.SE_commit))   # seq=2
    push!(tr, MTGRE.TraceEntry(tr.nextseq, 2,  0, 0, 0,  0, MTGRE.microcycle, MTGRE.checkpoint, MTGRE.done))        # seq=3
    push!(tr, MTGRE.TraceEntry(tr.nextseq, 3,  1, 2, 2, 11, MTGRE.microcycle, MTGRE.cohort,     MTGRE.SE_batch))    # seq=4
    push!(tr, MTGRE.TraceEntry(tr.nextseq, 4,  2, 2, 2, 11, MTGRE.microcycle, MTGRE.commit,     MTGRE.SE_commit))   # seq=5

    ents = tr.entries

    @testset "by_kind / by_tag" begin
        ks = filter(MTGRE.by_kind(MTGRE.commit), ents)
        @test all(e -> e.kind === MTGRE.commit, ks)
        @test getfield.(ks, :seq) == MTGRE.Seq[2, 5]

        ts = filter(MTGRE.by_tag(MTGRE.SE_batch), ents)
        @test all(e -> e.tag === MTGRE.SE_batch, ts)
        @test getfield.(ts, :seq) == MTGRE.Seq[1, 4]
    end

    @testset "by_t single and range" begin
        eq1 = filter(MTGRE.by_t(1), ents)
        @test length(eq1) == 1
        @test eq1[1].t == MTGRE.VTime(1)
        @test eq1[1].seq == MTGRE.Seq(4)

        r = filter(MTGRE.by_t(1:2), ents)
        @test all(e -> e.t in (MTGRE.VTime(1):MTGRE.VTime(2)), r)
        @test getfield.(r, :seq) == MTGRE.Seq[4, 5]
    end

    @testset "by_seq range" begin
        win = filter(MTGRE.by_seq(MTGRE.Seq(2):MTGRE.Seq(4)), ents)
        @test getfield.(win, :seq) == MTGRE.Seq[2, 3, 4]
    end

    @testset "by_actor and by_frame" begin
        a1 = filter(MTGRE.by_actor(1), ents)
        @test all(e -> e.actor_id == MTGRE.ActorId(1), a1)
        @test getfield.(a1, :seq) == MTGRE.Seq[1, 2]

        f11 = filter(MTGRE.by_frame(11), ents)
        @test all(e -> e.frame_id == MTGRE.FrameId(11), f11)
        @test getfield.(f11, :seq) == MTGRE.Seq[4, 5]
    end

    @testset "Composing predicates" begin
        # actor == 2 AND kind == commit
        pred = e -> MTGRE.by_actor(2)(e) && MTGRE.by_kind(MTGRE.commit)(e)
        hits = filter(pred, ents)
        @test length(hits) == 1
        @test hits[1].seq == MTGRE.Seq(5)
    end

    @testset "Builders are callable" begin
        @test MTGRE.by_t(1)(ents[4]) === true
        @test MTGRE.by_t(1:2)(ents[5]) === true
        @test MTGRE.by_kind(MTGRE.cohort)(ents[1]) === true
        @test MTGRE.by_tag(MTGRE.done)(ents[3]) === true
        @test MTGRE.by_actor(2)(ents[4]) === true
        @test MTGRE.by_frame(10)(ents[1]) === true
    end
end

end