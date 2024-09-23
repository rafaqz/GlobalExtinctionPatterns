module GlobalExtinctionPatterns

using CSV
using DataFrames
using GBIF2
using GLM
using Loess
using Makie
using JSON3
using StaticArrays
using Statistics
using StatsBase

export classify_trend

export load_mass_table

export set_gbif_species!

export plot_extinctions, plot_subsets

export load_mass_trend

export get_subsets

export get_flat_threats, get_threat_codes, get_threat_groups

const basepath = realpath(joinpath(@__DIR__, ".."))

include("rigal.jl")
include("tables.jl")
include("gbif.jl")
include("plots.jl")
include("traits.jl")
include("subsets.jl")
include("iucn.jl")

end
