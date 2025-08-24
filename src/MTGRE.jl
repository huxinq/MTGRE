module MTGRE
__precompile__()
using Reexport
include("core/Core.jl")

const PlayerId = Int
const ObjId    = Int

include("tracing/Tracing.jl")
@reexport using .Tracing

mutable struct StackObj
    kind::Symbol
    controller::PlayerId
    target::Union{ObjId,Nothing}
end




#= ########## Ops ##########
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
apply_sba!(S::GameState)::NamedTuple = nothing  # MVP: lethal damage → graveyard =#

end # module MTGRE
