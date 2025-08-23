struct TraceEntry
    seq      ::Int            # total order
    phase    ::Symbol         # :microcycle | :priority
    kind     ::Symbol         # :cohort | :commit | :ep | :stack | :frame | :asba | :checkpoint | :event
    t        ::Int
    cohort   ::Int
    actor    ::Union{Int,Nothing}
    tag      ::Symbol
    span_id  ::Int            # 0 if none; same id for frame enter/exit, same microcycle, etc.
    cause_seq::Int            # 0 if none; seq of the entry that scheduled/caused this one
    data     ::NamedTuple
end

mutable struct Trace
    entries::Vector{TraceEntry}
    nextseq::Int
    seed   ::UInt64
end

Trace(seed = 0xC0FFEE) = Trace(TraceEntry[], 1, seed)