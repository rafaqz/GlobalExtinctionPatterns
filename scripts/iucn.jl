using Revise
using ColorSchemes
using KernelDensity
using DataFrames
using JSON3
using CairoMakie
using GBIF2
using StatsBase

using GlobalExtinctionPatterns

cause_labels = [
    "Residential & commercial development",
    "Agriculture & aquaculture",
    "Energy production & mining",
    "Transportation & service corridors",
    "Biological resource use",
    "Human intrusions & disturbance",
    "Natural system modifications",
    "Invasive & other problematic species, genes & diseases",
    "Pollution",
     "Geological events",
     "Climate change & severe weather",
     "Other options",
]

basepath = GlobalExtinctionPatterns.basepath
datapath = joinpath(basepath, "data")
imagepath = joinpath(basepath, "images")
cause_labels = GlobalExtinctionPatterns.cause_labels

classes = ["AVES", "MAMMALIA", "REPTILIA"]
mass_df = load_mass_table(; classes=nothing)

iucn_threats_json_path = joinpath(datapath, "iucn_threats.json")
iucn_threats_dict = JSON3.read(iucn_threats_json_path, Dict{String,Any})

flat_threats = get_flat_threats(iucn_threats_dict)
# Attach ICUN data to threats records with a left join
# TODO some rows added here with leftjoin
flat_threats_with_assesment = leftjoin(flat_threats, mass_df; 
    on=:name => :scientificName
)
grouped_codes = Dict{String,Any}()

allcodes = union(flat_threats_with_assesment.name .=> parse.(Int, first.(split.(flat_threats_with_assesment.code, '.'))))
for (k, v) in allcodes
    if haskey(grouped_codes, k)
        push!(grouped_codes[k], v)
    else
        grouped_codes[k] = [v]
    end
end
species_threat_codes = map(mass_df.scientificName) do name
    get(grouped_codes, name, Int[])
end
mass_df.threat_codes = species_threat_codes

subsets = get_subsets(mass_df)
# Order threats for a nice color progression
# We omit "Climate & weather", "Geological events" 
# and "Other options" for simplicity
b = findfirst(==("Biological resource use"), cause_labels) 
i = findfirst(==("Invasive & diseases"), cause_labels) 
a = findfirst(==("Agriculture & aquaculture"), cause_labels) 
r = findfirst(==("Residential & commercial"), cause_labels) 
n = findfirst(==("Natural system modifications"), cause_labels) 
d = findfirst(==("Human disturbance"), cause_labels) 
e = findfirst(==("Energy production & mining"), cause_labels) 
t = findfirst(==("Transport corridors"), cause_labels) 
p = findfirst(==("Pollution"), cause_labels) 
selected_threats = [i, b, a, r, t, n, d, e, p]

sub = :mascarenes
sub = :all
sub = :birds
normalise = false
fig, ax = let
    df = subsets[sub].df
    threat_groups = map(1:12) do threat_code
        subset(df, 
            :className => ByRow(in(classes)), 
            :threat_codes => ByRow(tcs -> threat_code in tcs),
        )
    end
    colors = ColorSchemes.Bay
    labels = cause_labels[selected_threats]
    groups = threat_groups[selected_threats]
    fig = Figure(; size=(600, 600))
    ax = Axis(fig[1, 1];
        title="IUCN extinction causes: $sub", 
        xlabel="Year last seen",
        ylabel="Cause density (multiple per individual possible)",
    )
    # selected_threats = eachindex(cause_labels)
    upper = nothing
    # k = cause_labels[a]
    # group = threat_groups[a]
    all_years = collect(skipmissing(df.yearLastSeen_cleaned))
    kde_kw = (; boundary=(1400, 2200), npoints=2200-1400+1, bandwidth=25)
    u_all = kde(all_years; kde_kw...)
    group_stats = map(groups) do group
        years = collect(skipmissing(group.yearLastSeen_cleaned))
        u = kde(years; kde_kw...)
        adjusted_density = u.density .* length(years)
        if isnothing(upper)
            upper = adjusted_density 
            lower = adjusted_density .* 0
        else
            lower = upper 
            upper = upper .+ adjusted_density 
        end
        (; lower, upper, kde=u)
    end
    group_stats = map(group_stats) do (; lower, upper, kde)
        if normalise
            (; 
                lower=lower ./ last(group_stats).upper,
                upper=upper ./ last(group_stats).upper,
                kde,
            )
        else
            (; 
                lower=lower,
                upper=upper,
                kde,
            )
        end
    end
    length(group_stats)
    i = 2
    for i in reverse(eachindex(groups))
        s = group_stats[i]
        Makie.band!(ax, s.kde.x, s.lower, s.upper;
            label=string(labels[i]), 
            # color=(:white, 0.0),
            color=(get(colors, i/length(groups)), 0.95),
            # strokecolor=get(colors, i/length(selected_threats)), p2_kw...
        )
    end
    axislegend(ax; position=(0.1, normalise ? 0.1 : 0.9), framevisible=false)
    hidedecorations!(ax; label=false, ticks=false, ticklabels=false)
    hidespines!(ax)
    fig, ax
end
fig
save(joinpath(imagepath, "historical_extinction_causes.png" * (normalise ? "_normalised" : "")), fig)
