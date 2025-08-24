export schedule!

function schedule!(S::GameState, ops::AbstractVector{<:Op}; t::VTime=getvtime(S), cohort::Cohort=Cohort(0))
    q = get!(S.sched, t) do; Vector{Batch}(); end
    push!(q, Batch(cohort, ops))
    return nothing
end
schedule!(S::GameState, ops::Op...; kwargs...) = schedule!(S, collect(ops); kwargs...)