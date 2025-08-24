using Test
using MTGRE

@testset "Trace push! sequencing and bump" begin
    tr = MTGRE.Trace()                      # starts with nextseq == 1
    e1 = MTGRE.TraceEntry(
        tr.nextseq,                         # seq stamp
        MTGRE.microcycle,                   # phase
        MTGRE.cohort,                       # kind
        Int32(0),                           # t
        Int32(0),                           # cohort
        UInt32(0),                          # actor
        MTGRE.SE_batch,                     # tag
        UInt32(0),                          # span_id
        UInt32(0),                          # cause_seq
    )
    push!(tr, e1)
    @test length(tr.entries) == 1
    @test tr.entries[end].seq == 1
    @test tr.nextseq == 2

    e2 = MTGRE.TraceEntry(
        tr.nextseq,
        MTGRE.microcycle, MTGRE.commit,
        Int32(0), Int32(1),
        UInt32(0),
        MTGRE.SE_commit,
        UInt32(0), UInt32(1)                # caused by e1
    )
    push!(tr, e2)
    @test length(tr.entries) == 2
    @test tr.entries[end].seq == 2
    @test tr.nextseq == 3
end

@testset "Trace push! rejects mismatched seq stamp" begin
    tr = MTGRE.Trace()
    bad = MTGRE.TraceEntry(
        tr.nextseq + 1,                     # wrong stamp on purpose
        MTGRE.microcycle, MTGRE.cohort,
        Int32(0), Int32(0),
        UInt32(0),
        MTGRE.SE_batch,
        UInt32(0), UInt32(0)
    )
    @test_throws AssertionError push!(tr, bad)
end

@testset "Trace push! enforces causal ordering" begin
    tr = MTGRE.Trace()
    ok = MTGRE.TraceEntry(tr.nextseq, MTGRE.microcycle, MTGRE.cohort,
                          Int32(0), Int32(0), UInt32(0), MTGRE.SE_batch,
                          UInt32(0), UInt32(0))
    push!(tr, ok)

    bad_cause = MTGRE.TraceEntry(
        tr.nextseq,                         # seq == 2
        MTGRE.microcycle, MTGRE.commit,
        Int32(0), Int32(0),
        UInt32(0),
        MTGRE.SE_commit,
        UInt32(0),
        UInt32(3)                           # cause_seq > entry.seq → invalid
    )
    @test_throws AssertionError push!(tr, bad_cause)
end

@testset "trace! honors enabled gate and stamps seq" begin
    tr = MTGRE.Trace()
    tr.enabled = false

    n0 = length(tr.entries)
    MTGRE.trace!(tr; phase=MTGRE.microcycle, kind=MTGRE.cohort,
                    t=Int32(0), cohort=Int32(0), tag=MTGRE.SE_batch)
    @test length(tr.entries) == n0     # no-op when disabled

    tr.enabled = true
    seq0 = tr.nextseq
    MTGRE.trace!(tr; phase=MTGRE.microcycle, kind=MTGRE.cohort,
                    t=Int32(0), cohort=Int32(1), tag=MTGRE.SE_batch)
    @test length(tr.entries) == n0 + 1
    e = tr.entries[end]
    @test e.seq == seq0
    @test e.phase === MTGRE.microcycle
    @test e.kind  === MTGRE.cohort
    @test e.tag   === MTGRE.SE_batch
    @test e.t      isa Int32
    @test e.cohort isa Int32
    @test e.actor  isa UInt32
end

@testset "Checkpoint sentinel shape (manual)" begin
    tr = MTGRE.Trace()
    push!(tr, MTGRE.TraceEntry(tr.nextseq, MTGRE.microcycle, MTGRE.cohort,  Int32(0), Int32(0), UInt32(0), MTGRE.SE_batch,  UInt32(0), UInt32(0)))
    push!(tr, MTGRE.TraceEntry(tr.nextseq, MTGRE.microcycle, MTGRE.commit,  Int32(0), Int32(0), UInt32(0), MTGRE.SE_commit, UInt32(0), UInt32(1)))
    push!(tr, MTGRE.TraceEntry(tr.nextseq, MTGRE.microcycle, MTGRE.checkpoint, Int32(0), Int32(0), UInt32(0), MTGRE.done,   UInt32(0), UInt32(2)))

    @test tr.entries[end].kind === MTGRE.checkpoint
    @test tr.entries[end].tag  === MTGRE.done
    # ensure strictly one sentinel in this tiny sequence
    @test count(e -> e.kind === MTGRE.checkpoint && e.tag === MTGRE.done, tr.entries) == 1
end

@testset "Field widths are fixed as declared" begin
    tr = MTGRE.Trace()
    e = MTGRE.TraceEntry(tr.nextseq, MTGRE.microcycle, MTGRE.cohort,
                         Int32(7), Int32(9), UInt32(2), MTGRE.SE_batch, UInt32(0), UInt32(0))
    push!(tr, e)
    e′ = tr.entries[end]
    @test e′.seq      isa UInt64
    @test e′.t        isa Int32
    @test e′.cohort   isa Int32
    @test e′.actor    isa UInt32
    @test e′.span_id  isa UInt32
    @test e′.cause_seq isa UInt64
end
