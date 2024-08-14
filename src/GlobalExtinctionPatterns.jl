module GlobalExtinctionPatterns

using CSV
using DataFrames
using GBIF2
using GLM
using Loess
using Makie
using StaticArrays
using Statistics
using StatsBase

export classify_trend

export set_gbif_species!

export plot_extinctions, plot_subsets

export load_mass_trend

include("rigal.jl")
include("gbif.jl")
include("plots.jl")
include("traits.jl")

end
