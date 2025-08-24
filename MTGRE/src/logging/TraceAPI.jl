import Base: push!
function push!(trace::Trace, entry::TraceEntry)
    @assert entry.seq == trace.nextseq """The seq of the new \
    TraceEntry $(entry.seq) does not match the nextseq \
    of the trace $(trace.nextseq)"""
    @assert entry.cause_seq == 0 || entry.cause_seq < entry.seq """cause_seq \
    $(entry.cause_seq) < entry.seq $(entry.seq)
    Could a cause happen later than its consequence?"""
    push!(trace.entries, entry)
    trace.nextseq += 1
    return trace
end

function trace!(trace::Trace; phase, kind,
                t::Int32=S.t_current, cohort::Int32=Int32(0),
                actor::UInt32 = UInt32(0x00000000), tag,
                span_id::UInt32 = UInt32(0x00000000), cause_seq::UInt32 = UInt32(0x00000000))
    trace.enabled || return
    entry = TraceEntry(trace.nextseq, phase, kind, t, cohort, actor, tag, span_id, cause_seq)
    push!(trace, entry)
end

tracefilter(tr::Trace; phase=nothing, kind=nothing, tag=nothing) = nothing
trace_since_last_checkpoint(tr::Trace) = nothing
dump_last!(io::IO, tr::Trace; N::Int=12) = nothing
assert_microcycle_postconditions!(S::GameState; effects_left_at_tstar::Bool=false)::Nothing = nothing