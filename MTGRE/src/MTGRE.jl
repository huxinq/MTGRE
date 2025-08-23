module MTGRE

abstract type Op end
abstract type StateOp <: Op end
abstract type SystemOp <: Op end

const PlayerId = Int
const ObjId    = Int

struct TraceEntry
    seq   ::Int
    phase ::Symbol
    kind  ::Symbol
    t     ::Int
    cohort::Int
    actor ::Union{Int,Nothing}
    tag   ::Symbol
    data  ::NamedTuple
end

mutable struct Trace
    entries::Vector{TraceEntry}
    nextseq::Int
    seed   ::UInt64
end

Trace(seed = 0xC0FFEE) = Trace(TraceEntry[], 1, seed)

mutable struct StackObj
    kind::Symbol
    controller::PlayerId
    target::Union{ObjId,Nothing}
end

mutable struct GameState
    t_current::Int
    scheduler::Any
    stack::Vector{StackObj}
    sba_dirty::Bool
    trace::Trace
    players::Vector{PlayerId}
    life::Dict{PlayerId,Int}
    hand::Dict{PlayerId,Vector{ObjId}}
    battlefield::Vector{ObjId}
    graveyard::Vector{ObjId}
    kind::Dict{ObjId,Symbol}
    controller::Dict{ObjId,PlayerId}
    power::Dict{ObjId,Int}
    toughness::Dict{ObjId,Int}
    damage::Dict{ObjId,Int}
    tapped::Dict{ObjId,Bool}
end

########## Trace ##########
function trace!(S::GameState; phase::Symbol, kind::Symbol, tag::Symbol,
                t::Int=S.t_current, cohort::Int=0, actor::Union{Int,Nothing}=nothing,
                data::NamedTuple=NamedTuple())::Nothing; end

tracefilter(tr::Trace; phase=nothing, kind=nothing, tag=nothing) = nothing
trace_since_last_checkpoint(tr::Trace) = nothing
dump_last!(io::IO, tr::Trace; N::Int=12) = nothing
assert_microcycle_postconditions!(S::GameState; effects_left_at_tstar::Bool=false)::Nothing = nothing

########## Ops ##########
# System ops (bypass pipeline)
struct AdvanceClock      <: SystemOp end
struct PriorityCheckpoint <: SystemOp end
# State ops (use pipeline)
struct PlayLand   <: StateOp;  player::PlayerId; card::ObjId; end
struct ResolveTop <: StateOp end
struct DealDamage <: StateOp;  src::ObjId; tgt::ObjId; amount::Int; combat::Bool; end

########## Scheduler ##########
new_cohort!(S::GameState)::Int = nothing
schedule!(S::GameState, op::Op; t::Int=S.t_current, cohort::Int=new_cohort!(S), priority::Int=0)::Nothing = nothing
has_work_at_time(S::GameState, t::Int)::Bool = nothing
minimal_time_with_work(S::GameState)::Int = nothing
pop_next_cohort!(S::GameState, t::Int)::Tuple{Int,Symbol,Vector{Op}} =
    (0, :state, Vector{Op}())   # or Op[]

########## Pipeline (StateOp only) ##########
apply_replacements!(S::GameState, op::StateOp)::StateOp = nothing     # stub CR 616
apply_layers!(S::GameState, op::StateOp)::StateOp = nothing            # stub CR 613
validate!(S::GameState, op::StateOp)::Bool = nothing
commit_state_batch!(S::GameState, batch::Vector{StateOp})::Vector{NamedTuple} = nothing # events

########## Frames ##########
casting_frame!(S::GameState, player::PlayerId; kind::Symbol, target::Union{ObjId,Nothing}=nothing)::Bool = true
play_land!(S::GameState, player::PlayerId, card::ObjId)::Bool = true  # helper authors a PlayLand op

########## Loops ##########
microcycle!(S::GameState)::Nothing = nothing
open_priority_window!(S::GameState, scripted_actions)::Nothing = nothing
run_game!(S::GameState, scripted_actions)::Nothing = nothing

########## SBA ##########
apply_sba!(S::GameState)::NamedTuple = nothing  # MVP: lethal damage → graveyard

end # module MTGRE
