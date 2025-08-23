function trace!(S::GameState; phase::Symbol, kind::Symbol, tag::Symbol,
                t::Int=S.t_current, cohort::Int=0, actor::Union{Int,Nothing}=nothing,
                data::NamedTuple=NamedTuple())::Nothing; end

tracefilter(tr::Trace; phase=nothing, kind=nothing, tag=nothing) = nothing
trace_since_last_checkpoint(tr::Trace) = nothing
dump_last!(io::IO, tr::Trace; N::Int=12) = nothing
assert_microcycle_postconditions!(S::GameState; effects_left_at_tstar::Bool=false)::Nothing = nothing