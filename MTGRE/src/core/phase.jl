abstract type Phase end

struct BeginningPhase <: Phase end
struct MainPhase <: Phase end
struct CombatPhase <: Phase end
struct EndingPhase <: Phase end

abstract type Step end

struct UntapStep <: Step end
struct UpkeepStep <: Step end
struct DrawStep <: Step end
struct MainStep <: Step end
struct BeginCombatStep <: Step end
struct DeclareBlockersStep <: Step end
struct FirstStrikeStep <: Step end
struct CombatDamageStep <: Step end
struct EndCombatStep <: Step end
struct EndStep <: Step end
struct CleanupStep <: Step end

# ==================== helpers ========================
@inline advance(::Type) = Nothing

# Phase transitions (return type objects, not instances)
@inline advance(::Type{BeginningPhase}) = MainPhase
@inline advance(::Type{MainPhase})      = CombatPhase
@inline advance(::Type{CombatPhase})    = EndingPhase

# Step transition within Combat (fill the full table as needed)
@inline advance(::Type{UntapStep})            = UpkeepStep
@inline advance(::Type{UpkeepStep})           = DrawStep
@inline advance(::Type{BeginCombatStep})      = DeclareBlockersStep
@inline advance(::Type{DeclareBlockersStep})  = FirstStrikeStep
@inline advance(::Type{FirstStrikeStep})      = CombatDamageStep
@inline advance(::Type{CombatDamageStep})     = EndCombatStep
@inline advance(::Type{EndStep})              = CleanupStep

#############################################################

################        phaseof        ######################

#############################################################

@inline phaseof(::Type{UntapStep})           = BeginningPhase
@inline phaseof(::Type{UpkeepStep})          = BeginningPhase
@inline phaseof(::Type{DrawStep})            = BeginningPhase
@inline phaseof(::Type{MainStep})            = MainPhase
@inline phaseof(::Type{BeginCombatStep})     = CombatPhase
@inline phaseof(::Type{DeclareBlockersStep}) = CombatPhase
@inline phaseof(::Type{FirstStrikeStep})     = CombatPhase
@inline phaseof(::Type{CombatDamageStep})    = CombatPhase
@inline phaseof(::Type{EndCombatStep})       = CombatPhase
@inline phaseof(::Type{EndStep})             = EndingPhase
@inline phaseof(::Type{CleanupStep})         = EndingPhase

#############################################################

################        islast               ################

#############################################################

@inline islast_trait(S)                        = _islast_trait(advance(S))
@inline _islast_trait(::Type{Nothing})         = Val(true)
@inline _islast_trait(::Type)                   = Val(false)

@inline islast(S::Type) = islast_trait(S) isa Val{true}