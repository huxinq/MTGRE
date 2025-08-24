export Batch

struct Batch
    cohort :: Cohort
    ops    :: Vector{Op}
end