export trace!, by_kind, by_tag, by_t, by_seq, by_actor, by_frame

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

function trace!(trace::Trace; cause_seq=0,
                t=0, cohort=0, actor_id=0,
                frame_id=0, phase, kind, tag)
    trace.enabled || return
    entry = TraceEntry(trace.nextseq, cause_seq, t, cohort, actor_id,
                       frame_id, phase, kind, tag)
    push!(trace, entry)
end

# ====================== trace filter helpers ==============================
by_kind(k) = e -> e.kind === k
by_tag(tg) = e -> e.tag === tg 
by_t(x)    = e -> e.t == VTime(x)
by_t(r::UnitRange) = e -> e.t in VTime(first(r)):VTime(last(r))
by_seq(rng) = e -> e.seq in rng
by_actor(id) = e -> e.actor_id == ActorId(id)
by_frame(id) = e -> e.frame_id == FrameId(id)

trace_since_last_checkpoint(tr::Trace) = nothing
dump_last!(io::IO, tr::Trace; N::Int=12) = nothing
assert_microcycle_postconditions!(S; effects_left_at_tstar::Bool=false)::Nothing = nothing