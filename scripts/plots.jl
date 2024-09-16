using Revise
using CSV
using DataFrames
using ColorSchemes
using Colors
using StatsBase
using CairoMakie
# using GLMakie

using GlobalExtinctionPatterns

basepath = GlobalExtinctionPatterns.basepath
classes = ["AVES", "MAMMALIA", "REPTILIA"]

mass_df = load_mass_table(; classes)

# using TerminalPager
# mass_df |> pager

# Add numerical classes for plot colors
mass_df.classNum = collect(map(x -> findfirst(==(x), intersect(classes, mass_df.className)) , mass_df.className))

# Inspect the data
sort(mass_df.Location |> countmap |> pairs |> collect; by=last)
sort(mass_df.Archipelago |> countmap |> pairs |> collect; by=last)
sort(mass_df.SuperArchipelago |> countmap |> pairs |> collect; by=last)
sort(collect(mass_df.Archipelago |> countmap); by=last)


# Subsetting #################################################################3

not_mauris = :GBIFSpecies => ByRow(!in(("Chenonetta finschi", "Tribonyx hodgenorum")))
subset_queries = (;
    all=(title="All colonised", query=()),
    birds=(title="All colonised", query=(:className => ByRow(==("AVES")),)),
    mammals=(title="All colonised", query=(:className => ByRow(==("MAMMALIA")),)),
    reptiles=(title="All colonised", query=(:className => ByRow(==("REPTILIA")),)),
    islands=(title="All Islands", query=(:isisland,)),
    continents=(title="Continents", query=(:isisland => .!,)),
    inhabited_islands=(title="Inhabited", query=(:isisland, :wasuninhabited => .!,)),
    uninhabited_islands=(title="Uninhabited", query=(:isisland, :wasuninhabited,)),
    indian_ocean=(title="Indian ocean", query=(:SuperArchipelago=>ByRow(==("Indian Ocean")),)),
    mascarenes=(title="Mascarenes", query=(:Archipelago=>ByRow(==("Mascarenes")),)),
    not_mascarenes=(title="Not Mascarenes", query=(:Archipelago=>ByRow(!=("Mascarenes")),)),
    non_mascarene_uninhabited=(title="Non-Mascarene Uninhabited", query=(:isisland, :wasuninhabited, :Archipelago=>ByRow(!=("Mascarenes")),)),
    islands_early=(title="All Early Colonisation", query=(:isisland, :colonised=>ByRow(<(1750)),)),
    islands_late=(title="All Late Colonisation", query=(not_mauris, :isisland, :colonised=>ByRow(>=(1750)),)),
    inhabited_early=(title="Inhabited Early Colonisation", query=(:isisland, :wasuninhabited => .!, :colonised=>ByRow(<(1750)),)),
    inhabited_late=(title="Inhabited Late Colonisation", query=(not_mauris, :isisland, :wasuninhabited => .!, :colonised=>ByRow(>=(1750)),)),
    uninhabited_early=(title="Uninhabited Early Colonisation", query=(:isisland, :wasuninhabited, :colonised=>ByRow(<(1750)),)),
    uninhabited_late=(title="Uninhabited Late Colonisation", query=(not_mauris, :isisland, :wasuninhabited, :colonised=>ByRow(>=(1750)),)),

    australian_continent=(title="Australian Continent", query=(:isisland => .!, :SuperArchipelago=>ByRow(==("Australia")),)),
    australian_islands=(title="Australian Islands", query=(:isisland, :SuperArchipelago=>ByRow(==("Australia")),)),
    australian_inhabited_islands=(title="Australian Inhabited Islands", query=(:isisland, :wasuninhabited => .!, :SuperArchipelago=>ByRow(==("Australia")),)),
    australian_uninhabited_islands=(title="Australian Uninhabited Islands", query=(:isisland, :wasuninhabited, :SuperArchipelago=>ByRow(==("Australia")),)),

    mauritius=(title="Mauritius", query=(:Location=>ByRow(==("Mauritius")),)),
    reunion=(title="Reunion", query=(:Location=>ByRow(==("Reunion")),)),
    rodrigues=(title="Rodrigues", query=(:Location=>ByRow(==("Rodrigues")),)),
    australia=(title="Australia", query=(:SuperArchipelago=>ByRow(==("Australia")),)),
    new_zealand=(title="New Zealand", query=(:SuperArchipelago=>ByRow(==("New Zealand")),)),
    st_helena=(title="St Helena", query=(:SuperArchipelago=>ByRow(==("St Helena")),)),
    west_indies=(title="West Indies", query=(:SuperArchipelago=>ByRow(==("West Indies")),)),
    hawaiian_islands=(title="Hawaiian Islands", query=(:Archipelago=>ByRow(==("Hawaiian Islands")),)),
    polynesia=(title="Polynesia", query=(:SuperArchipelago=>ByRow(==("Polynesia")),)),
    micronesia=(title="Micronesia", query=(:SuperArchipelago=>ByRow(==("Micronesia")),)),
    galapagos=(title="Galapagos", query=(:Archipelago=>ByRow(==("Galapagos")),)),
)

subsets = map(subset_queries) do qs
    df = subset(mass_df, qs.query...; skipmissing=true)
    merge(qs, (; df))
end

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
    size=(900, 900),
    legend=(axisnum=3, position=:lt),
)
save(joinpath(basepath, "images/mass_and_extinction_splits.png"), fig)

individual = [
    :inhabited_early   :inhabited_late 
    :uninhabited_early :uninhabited_late
    :mascarenes        :australia
    :all               :hawaiian_islands
]
foreach(individual) do name
    fig, ax = plot_extinctions(subsets[name].df;
        size=(540, 600),
        trend=trends[name],
        title=subsets[name].title
    )
    axislegend(ax; position=:lt)
    save(joinpath(basepath, "images/$(name)_mass_and_extinction.png"), fig)
end

foreach(small_layout) do name
    fig, ax = plot_extinctions(subsets[name];
        colordata=:classNum,
        trend=trends[name],
        title=subsets[name].title
    )
    axislegend(ax; position=:lt)
    save(joinpath(basepath, "images/$(name)_mass_and_extinction.png"), fig)
end

class_layout = [
    :birds :mammals :reptiles
]
fig = plot_subsets(class_layout, subsets, trends; 
    size=(1000, 700),
    legend=(axisnum=1, position=:lt),
)
save(joinpath(basepath, "images/class_mass_and_extinction.png"), fig)

fig, _ = plot_extinctions(subsets.all.df;
    size=(800, 800),
    colordata=:classNum,
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
    xlabel="Mass",
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
