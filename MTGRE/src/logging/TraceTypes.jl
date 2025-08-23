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