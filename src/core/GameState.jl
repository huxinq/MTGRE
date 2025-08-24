mutable struct GameState
    t_current :: VTime

    # scheduler: map virtual time -> FIFO of batches
    sched     :: Dict{VTime, Vector{Batch}}

    # runtime queues (keep types simple for now)
    stack     :: Vector{Any}     # will be Vector{StackObj} later
    triggers  :: Vector{Any}     # will be Vector{PendingTrigger}
    prompts   :: Vector{Any}     # will be Vector{Prompt}
    sba_dirty :: Bool
    seed      :: UInt64
end

GameState(;seed = UInt64(0xC0FFEE)) = GameState(VTime(0), Dict{VTime, Vector{Batch}}(), Any[], Any[], Any[], false, seed)