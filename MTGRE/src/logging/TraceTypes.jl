    @enum TracePhase::Int8 begin
        microcycle = 1
        priority = 2
    end

    @enum TraceKind::Int8 begin
        cohort = 1
        commit = 2
        ep = 3
        stack = 4
        frame = 5
        asba = 6
        checkpoint = 7
        event = 8
    end

    @enum TraceTag::Int8 begin
        SE_batch = 1
        SE_commit = 2
        done = 3
    end


    struct TraceEntry
        seq      ::UInt64            # total order
        phase    ::TracePhase        
        kind     ::TraceKind
        t        ::Int32
        cohort   ::Int32
        actor    ::UInt32
        tag      ::TraceTag
        span_id  ::UInt32            # 0 if none; frame id
        cause_seq::UInt64            # 0 if none; seq of the entry that scheduled/caused this one
    end

    mutable struct Trace
        entries  ::Vector{TraceEntry}
        nextseq  ::UInt64
        seed     ::UInt64
        enabled  ::Bool
    end

    Trace(seed = 0xC0FFEE) = Trace(TraceEntry[], 1, seed, true)