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