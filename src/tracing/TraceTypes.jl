export TracePhase, TraceKind, TraceTag, TraceEntry, Trace
export VTime, Cohort, ActorId, FrameId, Seq
export microcycle, priority
export cohort, commit, ep, stack, frame, asba, checkpoint, Event
export SE_batch, SE_commit, done

using ..MTGRE.Core: VTime

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

const Cohort  = Int32
const ActorId = UInt32
const FrameId  = UInt32
const Seq     = UInt64

struct TraceEntry
    seq      :: Seq            # total order
    cause_seq:: Seq            # 0 if none; seq of the entry that scheduled/caused this one
    t        :: VTime
    cohort   :: Cohort
    actor_id :: ActorId
    frame_id :: FrameId            # 0 if none; frame id
    phase    :: TracePhase        
    kind     :: TraceKind
    tag      :: TraceTag
end

mutable struct Trace
    entries  :: Vector{TraceEntry}
    nextseq  :: Seq
    enabled  :: Bool
end

TraceEntry(seq, cause_seq, t, cohort, actor_id, frame_id, phase, kind, tag) =  
    TraceEntry(Seq(seq), Seq(cause_seq), VTime(t), Cohort(cohort),
        ActorId(actor_id), FrameId(frame_id), phase, kind, tag)

Trace() = Trace(TraceEntry[], 1, true)