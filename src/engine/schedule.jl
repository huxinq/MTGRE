export schedule!

function schedule!(sched::Dict{VTime, Vector{Batch}}, ops::AbstractVector{<:Op}; t::VTime, cohort::Cohort)
    q = get!(sched, t) do; Vector{Batch}(); end
    push!(q, Batch(cohort, ops))
    return nothing
end
schedule!(sched::Dict{VTime, Vector{Batch}}, ops::Vararg{<:Op}; kwargs...) = schedule!(sched, collect(ops); kwargs...)
schedule!(S::GameState, ops...; t=getvtime(S), cohort=Cohort(0)) = 
    schedule!(S.sched, ops...; t=t, cohort=cohort)
