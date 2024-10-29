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

mass_df = load_mass_table(; classes)
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

subset_layout = [
    :islands             :islands_early     :islands_late #nothing
    :inhabited_islands   :inhabited_early   :inhabited_late #:west_indies
    :uninhabited_islands :uninhabited_early :uninhabited_late #nothing
]
fig = plot_subsets(subset_layout, subsets, trends; legend=(axisnum=1, position=:lt))
save(joinpath(basepath, "images/mass_and_extinction_subsets.png"), fig)

small_layout = [
    :inhabited_early   :inhabited_late #:west_indies
    :uninhabited_early :uninhabited_late #nothing
]
fig = plot_subsets(small_layout, subsets, trends;
    size=(700, 600),
    legend=(axisnum=3, position=:lt),
    titlejoin="\n",
)
save(joinpath(basepath, "images/mass_and_extinction_splits.png"), fig)

cause_layout = [
    :invasive_caused :human_caused :lcc_caused
]
fig = plot_subsets(cause_layout, subsets, trends;
    size=(1000, 350),
    legend=(axisnum=3, position=:lt),
)
save(joinpath(basepath, "images/mass_and_extinction_causes.png"), fig)

individual = [
    :inhabited_early
    :inhabited_late 
    :uninhabited_early
    :uninhabited_late
    :mascarenes
    :australia
    :hawaiian_islands
    :continents
    :all               
]
foreach(individual) do name
    fig = plot_subsets([name;;], subsets, trends;
        size=(720, 600),
        legend=(axisnum=1, position=:lt),
    )
    save(joinpath(basepath, "images/$(name)_mass_and_extinction.png"), fig)
end

foreach(small_layout) do name
    fig = plot_subsets([name;;], subsets, trends;
        size=(720, 600),
        legend=(axisnum=1, position=:lt),
    )
    save(joinpath(basepath, "images/$(name)_mass_and_extinction.png"), fig)
end

class_layout = [
    :birds :mammals :reptiles
]
fig = plot_subsets(class_layout, subsets, trends; 
    size=(1000, 350),
    legend=(axisnum=1, position=:lt),
)
save(joinpath(basepath, "images/class_mass_and_extinction.png"), fig)

fig, _ = plot_extinctions(subsets.all.df;
    size=(800, 800),
    trend=trends.all,
)
fig
save(joinpath(basepath, "images/global_mass_and_extinction.png"), fig)

# Australia

# subset_australia = [:australia :australian_continent :australian_uninhabited_islands]
# fig = plot_subsets(subset_australia, subsets, trends; colorrange=(1, 4))
# save("images/mass_and_extinction_australia.png", fig)


# Individual subset plots

fig = plot_extinctions(subsets.australia;
    colordata=:classNum,
    trend=trends.australia,
    size=
    # legend=titlecase.(classes) .=> 1:3,
)
save(joinpath(basepath, "images/australia_mass_and_extinction.png"), fig)
# plot_extinctions(subsets.australian_continent.df)
# plot_extinctions(subsets.australian_islands.df)


# Mass density plots #######################################################

density_layout = (
    # :islands,
    :birds,
    :mammals,
    :reptiles,
    # :inhabited_islands,
    # :uninhabited_islands,
    # :islands_early,
    # :islands_late,
    # :inhabited_early,
    # :uninhabited_early,
    # :inhabited_late,
    # :uninhabited_late,
)
selected_logmasses = map(subsets[density_layout]) do (; df)
    log.(df.EstimatedMass)
end
colors = collect(ColorSchemes.Bay)

# If we have all the animal trait data put it in the plot too
if isdefined(Main, :mean_mass_df)
    colors[1] = RGB(0.0, 0.0, 0.0)
    all_vertebrates = log.(skipmissing(mean_mass_df.Mass_mean))
    all_logmasses = merge((; all_vertebrates), selected_logmasses)
else
    # Otherwise just plot the extinct species
    all_logmasses = selected_logmasses
end

fig = Figure()
ax = Axis(fig[1, 1];
    xlabel="Mass (g)",
    xticks = (log.(10 .^ (0:6)), ["1g", "10g", "100g", "1Kg", "10Kg", "100Kg", "1Mg"])
)
xlims!(ax, (0, log(1e6)))
map(all_logmasses, enumerate(keys(all_logmasses))) do lm, (i, label)
    density!(ax, lm;
        boundary=(0, 30),
        color=(:white, 0.0),
        label=titlecase(replace(string(label), "_" => " ")),
        strokecolor=colors[i],
        strokewidth=2,
    )
end
axislegend(ax; position=:rt)

save(joinpath(basepath, "images/mass_density.png"), fig)
