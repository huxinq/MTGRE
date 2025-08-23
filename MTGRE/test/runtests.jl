# test/runtests.jl
using Test
import MTGRE
import MTGRE: GameState, StackObj, Trace, TraceEntry,
              AdvanceClock, PriorityCheckpoint,  # if you call/schedule these directly
              PlayLand, ResolveTop, DealDamage,
              schedule!, new_cohort!, microcycle!,
              open_priority_window!, run_game!,
              casting_frame!, play_land!,
              tracefilter, trace_since_last_checkpoint,
              assert_microcycle_postconditions!

# ----------------------------
# Helpers (tiny, self-contained)
# ----------------------------

"Create a bare GameState with two players and an empty board."
function fresh_state(; seed=0xCAFE, p1=1, p2=2)
    GameState(
        0,                         # t_current
        nothing,                   # scheduler (your impl will replace)
        MTGRE.StackObj[],          # stack
        false,                     # sba_dirty
        MTGRE.Trace(seed),         # trace
        [p1, p2],                  # players
        Dict(p1=>20, p2=>20),      # life total
        Dict(p1=>Int[], p2=>Int[]),# hand
        Int[],                     # battlefield (ObjIds)
        Int[],                     # graveyard (ObjIds)
        Dict{Int,Symbol}(),        # kind
        Dict{Int,Int}(),           # controller
        Dict{Int,Int}(),           # power
        Dict{Int,Int}(),           # toughness
        Dict{Int,Int}(),           # damage
        Dict{Int,Bool}(),          # tapped
    )
end

"Allocate a new object id (simple monotone counter on max key)."
function new_objid!(S::GameState)::Int
    maxid = isempty(S.kind) ? 100 : maximum(keys(S.kind))
    return maxid + 1
end

"Give player a basic land card in hand (ObjId returned)."
function give_land_in_hand!(S::GameState, player)::Int
    id = new_objid!(S)
    S.kind[id] = :Land
    S.controller[id] = player
    push!(S.hand[player], id)
    return id
end

"Spawn a simple creature permanent on battlefield (ObjId returned)."
function spawn_creature!(S::GameState, player; power=2, toughness=2)::Int
    id = new_objid!(S)
    S.kind[id] = :Creature
    S.controller[id] = player
    S.power[id] = power
    S.toughness[id] = toughness
    S.damage[id] = 0
    S.tapped[id] = false
    push!(S.battlefield, id)
    return id
end

"Convenience: count entries by (kind,tag) in trace."
function trace_count(S::GameState, kind::Symbol, tag::Symbol)
    length(MTGRE.tracefilter(S.trace; kind=kind, tag=tag))
end

# ----------------------------
# 1) Microcycle shape + checkpoint runs last
# ----------------------------

@testset "microcycle runs state/system ops then checkpoint" begin
    S = fresh_state()

    # Prepare a land SE so the pipeline will have a real commit
    land = give_land_in_hand!(S, 1)

    # Schedule: one AdvanceClock system op, one PlayLand state op at t=0
    schedule!(S, AdvanceClock(); t=0)
    schedule!(S, PlayLand(1, land); t=0)

    microcycle!(S)

    # Trace shape expectations
    @test trace_count(S, :checkpoint, :done) >= 1        # PriorityCheckpoint ran
    @test trace_count(S, :commit, :SE_commit) >= 1       # PlayLand produced a commit

    # Postconditions (must not throw)
    MTGRE.assert_microcycle_postconditions!(S)
end

# ----------------------------
# 2) Play land goes through State pipeline and changes zones
# ----------------------------

@testset "PlayLand uses pipeline and moves zone" begin
    S = fresh_state()
    land = give_land_in_hand!(S, 1)

    ok = play_land!(S, 1, land)                  # authors a PlayLand op
    @test ok

    microcycle!(S)

    @test !(land in S.hand[1])
    @test  (land in S.battlefield)
    @test trace_count(S, :commit, :SE_commit) >= 1
end

# ----------------------------
# 3) Casting frame pushes stack object; no priority during frame
# ----------------------------

@testset "casting_frame! pushes stack object (no priority mid-frame)" begin
    S = fresh_state()
    # Put two lands onto battlefield so the casting frame can 'tap' them
    l1 = give_land_in_hand!(S, 1)
    l2 = give_land_in_hand!(S, 1)
    schedule!(S, PlayLand(1, l1); t=0)
    schedule!(S, PlayLand(1, l2); t=0)
    microcycle!(S)  # commit both

    ok = casting_frame!(S, 1; kind=:creature, target=nothing)
    @test ok

    # Should have recorded a stack push inside the frame
    pushes = MTGRE.tracefilter(S.trace; kind=:stack, tag=:push)
    @test !isempty(pushes)

    # Only after a microcycle will a checkpoint appear
    @test trace_count(S, :checkpoint, :done) == 0
    microcycle!(S)
    @test trace_count(S, :checkpoint, :done) >= 1
end

# ----------------------------
# 4) Pass–pass with non-empty stack resolves top
# ----------------------------

@testset "pass–pass resolves top of stack" begin
    S = fresh_state()

    # Ensure there's a creature to target and an instant on the stack
    victim = spawn_creature!(S, 1; power=2, toughness=2)
    ok = casting_frame!(S, 2; kind=:instant, target=victim)
    @test ok
    microcycle!(S)  # process casting → stack push + checkpoint

    # Driver that makes players pass in APNAP order forever
    acts = [(:P1, :Pass), (:P2, :Pass)]
    idx_pass = Ref(1)
    driver_passpass = (state::GameState, player)::Symbol -> begin
        act = acts[idx_pass[]][2]
        idx_pass[] = (idx_pass[] % length(acts)) + 1
        return act
    end

    # Open window; engine should detect pass–pass + nonempty stack ⇒ ResolveTop scheduled
    open_priority_window!(S, driver_passpass)

    # We expect a stack pop to have occurred during resolution
    pops = MTGRE.tracefilter(S.trace; kind=:stack, tag=:pop)
    @test !isempty(pops)

    # A checkpoint should have followed
    @test trace_count(S, :checkpoint, :done) >= 1
end

# ----------------------------
# 5) DealDamage + ASBA kills lethal creatures
# ----------------------------

@testset "DealDamage marks damage; ASBA kills lethal" begin
    S = fresh_state()
    a = spawn_creature!(S, 1; power=2, toughness=2)
    b = spawn_creature!(S, 2; power=3, toughness=3)

    # Schedule one damage op: b deals 3 to a
    schedule!(S, DealDamage(b, a, 3, false); t=0)
    microcycle!(S)

    # Expect ASBA to have removed 'a' from battlefield
    @test !(a in S.battlefield)
    @test (a in S.graveyard)
    # ASBA trace should record at least one pass (you can encode :deaths count in data)
    asbas = MTGRE.tracefilter(S.trace; kind=:asba)
    @test !isempty(asbas)
end

# ----------------------------
# 6) Golden turn acceptance (scripted)
# ----------------------------

@testset "golden turn: land → creature → instant → resolve → (combat)" begin
    S = fresh_state()
    land1 = give_land_in_hand!(S, 1)
    land2 = give_land_in_hand!(S, 1)

    # Driver runs a fixed action sequence (engine interprets symbols)
    script_queue = [
        (:P1, :PlayLand),
        (:P1, :PlayLand),
        (:P1, :CastCreature),
        (:P2, :CastInstant),
        (:P1, :Pass),
        (:P2, :Pass),
        (:P1, :Pass),
        (:P2, :Pass),
        (:P1, :Pass),
        (:P2, :Pass),
    ]
    idx_script = Ref(1)
    driver_golden = (state::GameState, player)::Symbol -> begin
        act = script_queue[idx_script[]][2]
        idx_script[] = min(idx_script[] + 1, length(script_queue))
        return act
    end

    # Optional: the engine can pick which land to play; we supplied two in hand already.
    run_game!(S, driver_golden)

    # Trace shape sanity
    @test trace_count(S, :checkpoint, :done) >= 1
    @test length(MTGRE.tracefilter(S.trace; kind=:stack, tag=:push)) >= 2  # creature + instant
    @test length(MTGRE.tracefilter(S.trace; kind=:stack, tag=:pop))  >= 2  # both resolved

    # If the instant killed the creature pre-combat, P1 should control no creatures on battlefield
    @test !any(oid-> S.kind[oid]==:Creature && S.controller[oid]==1, S.battlefield)
end
