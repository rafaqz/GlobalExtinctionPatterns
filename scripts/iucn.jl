using Revise
using Colors
using ColorSchemes
using KernelDensity
using DataFrames
using JSON3
using CairoMakie
using GBIF2
using StatsBase

using GlobalExtinctionPatterns
const GEP = GlobalExtinctionPatterns

basepath = GlobalExtinctionPatterns.basepath
datapath = joinpath(basepath, "data")
imagepath = joinpath(basepath, "images")
cause_labels = GlobalExtinctionPatterns.cause_labels

classes = ["AVES", "MAMMALIA", "REPTILIA"]
mass_df = load_mass_table(; classes=nothing)
mass_df.threat_groups = get_threat_groups(mass_df, datapath)
mass_df.threat_codes = get_threat_codes(mass_df, datapath)
subsets = get_subsets(mass_df)

# Order threats for a nice color progression
# We omit "Climate & weather", "Geological events" 
# and "Other options" for simplicity
# b = findfirst(==("Biological resource use"), cause_labels) 
# i = findfirst(==("Invasive & diseases"), cause_labels) 
# a = findfirst(==("Agriculture & aquaculture"), cause_labels) 
# r = findfirst(==("Residential & commercial"), cause_labels) 
# n = findfirst(==("Natural system modifications"), cause_labels) 
# d = findfirst(==("Human disturbance"), cause_labels) 
# e = findfirst(==("Energy production & mining"), cause_labels) 
# t = findfirst(==("Transport corridors"), cause_labels) 
# p = findfirst(==("Pollution"), cause_labels) 
# selected_threats = ["Huntin" => i, "Invasives" => b, [a, r, t, n, d, e], p]

sub = :mascarenes
sub = :birds
sub = :all
normalise = false
cause_colors = map(i -> get(ColorSchemes.Bay, i/4), 1:4)
fig = let
    fig = Figure(; size=(800, 400));
    ax = Axis(fig[1, 1];
        xlabel="Year last seen",
        ylabel="Fraction of causes",
        xticks=1500:100:2000, 
        yticks=0.0:0.2:1.0,
    )
    df = subsets[sub].df
    plot_threat_density!(ax, subsets[sub].df; normalise=true, classes, colors=cause_colors)
    axislegend(ax; 
        position=(0.0, 0.25), 
        framevisible=false,
        # patchstrokewidth=1,
        patchstrokecolor=:black,
    )
    fig
end

save(joinpath(imagepath, "historical_extinction_causes.png"), fig)

group_queries = (
    :threat_codes => ByRow(x -> any(c -> c in x, GEP.OTHER_CAUSED)),
    :threat_codes => ByRow(x -> any(c -> c in x, GEP.HUMAN_CAUSED)),
    :threat_codes => ByRow(x -> any(c -> c in x, GEP.INVASIVE_CAUSED)),
    :threat_codes => ByRow(x -> any(c -> c in x, GEP.LCC_CAUSED)),
)
groups = map(group_queries) do q
    subset(subsets[:all].df, q)
end
groups[1].threat_codes
filter(r -> !("8.1.2" in r.threat_codes), groups[1]).threat_codes
