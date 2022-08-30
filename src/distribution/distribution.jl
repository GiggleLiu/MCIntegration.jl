module Dist
using StaticArrays

abstract type AdaptiveMap end
abstract type Variable end
const MaxOrder = 16

include("common.jl")
include("variable.jl")
include("sampler.jl")
export Variable
export FermiK
export Continuous
export Discrete
export create!, shift!, swap!
export createRollback!, shiftRollback!, swapRollback!
end