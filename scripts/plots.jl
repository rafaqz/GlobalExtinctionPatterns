deleteat!(Base.LOAD_PATH, 2:3)

using Revise
using CSV
using DataFrames
using ColorSchemes
using Colors
using StatsBase
using CairoMakie
# using GLMakie

using GlobalExtinctionPatterns
const GEP = GlobalExtinctionPatterns

basepath = GlobalExtinctionPatterns.basepath
datapath = joinpath(basepath, "data")
classes = ["AVES", "MAMMALIA", "REPTILIA"]
cause_colors = map(i -> get(ColorSchemes.Bay, i/4), 1:4)

mass_df = load_mass_table(; classes, traitspath="")
mass_df.threat_groups = get_threat_groups(mass_df, datapath)
mass_df.threat_codes = get_threat_codes(mass_df, datapath)
mass_df = GEP.add_threat_categories!(mass_df)

# Add numerical classes for plot colors
mass_df.classNum = collect(map(x -> findfirst(==(x), intersect(classes, mass_df.className)) , mass_df.className))
subsets = get_subsets(mass_df)

trends = map(subsets) do (; df)
    xs, ys = df.yearLastSeen_cleaned, log.(df.EstimatedMass)
    classify_trend(xs, ys)
end

# Mass vs Extinction time plots ####################################################################3

# Figure 1: all
fig = plot_subsets([:all;;], subsets, trends;
    size=(720, 600),
    legend=(axisnum=1, position=:lt),
    showtitle=false,
    showmean=false,
)
save(joinpath(basepath, "images/all_mass_and_extinction.png"), fig)

# Model
trends.all.model

# Figure 2: causes
cause_layout = [
    :invasive_caused :human_caused :lcc_caused
]
fig = plot_subsets(cause_layout, subsets, trends;
    size=(1000, 350),
    legend=(axisnum=3, position=:lt),
)
save(joinpath(basepath, "images/mass_and_extinction_causes.png"), fig)

# Models
trends.invasive_caused.model
trends.human_caused.model
trends.lcc_caused.model

# Figure 2: phases
phases_layout = [
    :inhabited_early   :inhabited_late
    :uninhabited_early :uninhabited_late
]
fig = plot_subsets(phases_layout, subsets, trends;
    size=(700, 600),
    legend=(axisnum=3, position=:lt),
    titlejoin="\n",
)
save(joinpath(basepath, "images/mass_and_extinction_splits.png"), fig)

# Models
trends.inhabited_early.model
trends.inhabited_late.model
trends.uninhabited_early.model
trends.uninhabited_late.model

# Appendix 1: classes
class_layout = [
    :birds :mammals :reptiles
]
fig = plot_subsets(class_layout, subsets, trends; 
    size=(1000, 350),
    legend=(axisnum=1, position=:lt),
)
save(joinpath(basepath, "images/class_mass_and_extinction.png"), fig)

# Models
trends.birds.model
trends.mammals.model
trends.reptiles.model
