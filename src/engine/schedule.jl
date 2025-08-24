using ..MTGRE.Core: GameState, Op, VTime, getvtime, Cohort
export schedule!

function schedule!(S::GameState, ops::Vector{Op}; t::VTime=getvtime(S), cohort::Cohort=0)
    q = get!(S.sched, t) do; Vector{Batch}(); end
    push!(q, Batch(cohort, ops))
end
schedule!(S::GameState, ops::Op...; kwargs...) = schedule!(S, collect(ops); kwargs...)